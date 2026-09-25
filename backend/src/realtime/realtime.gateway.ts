import { Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
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
import type { Subscription } from 'rxjs';
import type { WebSocket } from 'ws';
import { ChatEvents } from '../chat/chat-events.js';
import { ChatService } from '../chat/chat.service.js';
import { publicName } from '../users/public-name.js';

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
  /** Last reported position, already coarsened — see [coarsen]. */
  lat?: number;
  lng?: number;
}

/**
 * Rounds a coordinate to 3 decimals (~110 m) before it's stored or shared,
 * so the map shows roughly where someone is without pinpointing them.
 */
const coarsen = (value: number) => Math.round(value * 1000) / 1000;

/** Attached to each socket so handleDisconnect can find who it was. */
type TrackedSocket = WebSocket & { hereUserId?: string };

/**
 * Tracks who's currently "Reachable" (connected) and relays pings between
 * them. Plain RFC 6455 WebSockets (via `ws`/`@nestjs/platform-ws`) rather
 * than Socket.IO — no extra protocol layer, just a JSON `{event, data}`
 * envelope per message, which is all `@nestjs/platform-ws` needs.
 */
@WebSocketGateway()
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly users = new Map<string, ConnectedUser>();
  private chatSubscription?: Subscription;

  constructor(
    private readonly jwtService: JwtService,
    private readonly chatService: ChatService,
    private readonly chatEvents: ChatEvents,
  ) {}

  /**
   * Every saved message — sent over this socket or via `POST /chat/messages`
   * — goes live to both parties if connected. The sender gets it too, so their
   * own thread and Chats list update the same way a second device would.
   */
  onModuleInit() {
    this.chatSubscription = this.chatEvents.messages$.subscribe((message) => {
      for (const id of new Set([message.fromId, message.targetId])) {
        const user = this.users.get(id);
        if (user) this.send(user.socket, 'chat:message', message);
      }
    });
  }

  onModuleDestroy() {
    this.chatSubscription?.unsubscribe();
  }

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
    // Tokens issued before the phone-number-as-display-name fix still carry
    // it, so this goes through the same filter as everything else.
    const name = publicName(payload);
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

  @SubscribeMessage('location')
  handleLocation(@ConnectedSocket() socket: TrackedSocket, @MessageBody() data: { lat?: unknown; lng?: unknown }) {
    const id = socket.hereUserId;
    const user = id ? this.users.get(id) : undefined;
    const { lat, lng } = data ?? {};
    if (!user || typeof lat !== 'number' || typeof lng !== 'number') return;
    if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) return;

    user.lat = coarsen(lat);
    user.lng = coarsen(lng);
    this.broadcastPeople();
  }

  @SubscribeMessage('chat:send')
  async handleChatSend(
    @ConnectedSocket() socket: TrackedSocket,
    @MessageBody() data: { targetId?: unknown; body?: unknown },
  ) {
    const fromId = socket.hereUserId;
    if (!fromId || typeof data?.targetId !== 'string' || typeof data?.body !== 'string') return;
    try {
      // Delivery to both parties happens in onModuleInit's subscription.
      await this.chatService.send(fromId, data.targetId, data.body);
    } catch (error) {
      this.logger.warn(`chat:send from ${fromId} rejected: ${(error as Error).message}`);
    }
  }

  private broadcastPeople() {
    const people = [...this.users.values()].map((u) => ({
      id: u.id,
      name: u.name,
      lat: u.lat ?? null,
      lng: u.lng ?? null,
    }));
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
