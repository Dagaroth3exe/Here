import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
} from '@nestjs/websockets';
import type { IncomingMessage } from 'node:http';
import type { WebSocket } from 'ws';
import { ChatService } from '../chat/chat.service.js';
import { UsersService } from '../users/users.service.js';

interface JwtPayload {
  sub: string;
  email?: string | null;
  username?: string | null;
  displayName?: string | null;
}

interface ConnectedUser {
  socket: WebSocket;
  id: string;
  name: string;
}

/** Attached to each socket so handleDisconnect can find who it was. */
type TrackedSocket = WebSocket & { hereUserId?: string };

/**
 * Tracks who's currently "Reachable" (connected) and relays pings between
 * them. Plain RFC 6455 WebSockets (via `ws`/`@nestjs/platform-ws`) rather
 * than Socket.IO — no extra protocol layer, just a JSON `{event, data}`
 * envelope per message, which is all `@nestjs/platform-ws` needs.
 */
@WebSocketGateway()
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly users = new Map<string, ConnectedUser>();

  constructor(
    private readonly jwtService: JwtService,
    private readonly chatService: ChatService,
    private readonly usersService: UsersService,
  ) {}

  handleConnection(socket: TrackedSocket, request: IncomingMessage) {
    const token = new URL(request.url ?? '', 'http://localhost').searchParams.get('token');
    if (!token) {
      socket.close(4001, 'Missing token');
      return;
    }

    let payload: JwtPayload;
    try {
      payload = this.jwtService.verify<JwtPayload>(token);
    } catch {
      socket.close(4001, 'Invalid token');
      return;
    }

    const id = payload.sub;
    const name = payload.username ?? payload.displayName ?? payload.email ?? 'Someone';
    socket.hereUserId = id;
    this.users.set(id, { socket, id, name });
    this.logger.log(`${name} connected (${this.users.size} reachable)`);
    this.broadcastPeople();
  }

  handleDisconnect(socket: TrackedSocket) {
    const id = socket.hereUserId;
    if (id && this.users.get(id)?.socket === socket) {
      this.users.delete(id);
      this.broadcastPeople();
    }
  }

  @SubscribeMessage('ping')
  handlePing(@ConnectedSocket() socket: TrackedSocket, @MessageBody() data: { targetId?: string }) {
    const fromId = socket.hereUserId;
    if (!fromId || !data?.targetId) return;

    const from = this.users.get(fromId);
    const target = this.users.get(data.targetId);
    if (!from || !target) return;

    this.send(target.socket, 'ping', { fromId: from.id, fromName: from.name });
  }

  @SubscribeMessage('chat:send')
  async handleChatSend(
    @ConnectedSocket() socket: TrackedSocket,
    @MessageBody() data: { targetId?: string; body?: string },
  ) {
    const fromId = socket.hereUserId;
    const body = data?.body?.trim();
    if (!fromId || !data?.targetId || !body) return;

    const from = this.users.get(fromId);
    if (!from) return;

    const saved = await this.chatService.saveMessage(fromId, data.targetId, body);

    // Resolve the recipient's name too (not just the sender's) — whichever
    // side reads this payload needs both names, e.g. the sender's own Chats
    // list has no other way to learn who a brand-new conversation is with.
    const targetOnline = this.users.get(data.targetId);
    const targetName =
      targetOnline?.name ??
      (await this.usersService.findById(data.targetId))?.username ??
      'Someone';

    const payload = {
      id: saved.id,
      fromId,
      fromName: from.name,
      targetId: data.targetId,
      targetName,
      body: saved.body,
      createdAt: saved.createdAt.toISOString(),
    };

    // Echo to the sender too (so their own thread updates the same way a
    // future second device would) and forward to the recipient if online.
    this.send(socket, 'chat:message', payload);
    if (targetOnline) this.send(targetOnline.socket, 'chat:message', payload);
  }

  private broadcastPeople() {
    const people = [...this.users.values()].map((u) => ({ id: u.id, name: u.name }));
    for (const u of this.users.values()) {
      this.send(u.socket, 'people', people);
    }
  }

  private send(socket: WebSocket, event: string, data: unknown) {
    if (socket.readyState === socket.OPEN) {
      socket.send(JSON.stringify({ event, data }));
    }
  }
}
