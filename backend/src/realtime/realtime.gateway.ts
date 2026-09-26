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
import { ChatService } from '../chat/chat.service.js';
import { UserEvents } from '../events/user-events.js';
import { SAFETY_CHANGED, SafetyService } from '../safety/safety.service.js';
import { publicName } from '../users/public-name.js';

interface JwtPayload {
  sub: string;
  email?: string | null;
  username?: string | null;
  displayName?: string | null;
}

interface ConnectedUser {
  /** Every open connection for this account (phone, tablet, a reconnect racing the old socket). */
  sockets: Set<WebSocket>;
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
    private readonly userEvents: UserEvents,
    private readonly safety: SafetyService,
  ) {}

  /**
   * Everything addressed to specific users — new messages (to both parties,
   * so the sender's own thread updates like a second device would), chat
   * request updates, read receipts, Ask HERE answers — goes live to whoever
   * of them is connected. Push-only deliveries have no socket event.
   */
  onModuleInit() {
    this.chatSubscription = this.userEvents.deliveries$.subscribe((delivery) => {
      if (delivery.event === SAFETY_CHANGED) {
        this.broadcastPeople();
        return;
      }
      if (delivery.data === null) return;
      for (const id of new Set(delivery.to)) {
        const user = this.users.get(id);
        if (user) this.sendAll(user, delivery.event, delivery.data);
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
    const existing = this.users.get(id);
    if (existing) {
      existing.sockets.add(socket);
    } else {
      this.users.set(id, { sockets: new Set([socket]), id, name });
    }
    this.logger.log(`${name} connected (${this.users.size} reachable)`);
    this.broadcastPeople();
  }

  handleDisconnect(socket: TrackedSocket) {
    const id = socket.hereUserId;
    const user = id ? this.users.get(id) : undefined;
    // Only when the account's last connection closes do they stop being Reachable.
    if (user && user.sockets.delete(socket) && user.sockets.size === 0) {
      this.users.delete(id!);
      this.broadcastPeople();
    }
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

  /** Everyone gets the Reachable list minus people they've blocked or who blocked them. */
  private broadcastPeople() {
    const everyone = [...this.users.values()];
    const people = everyone.map((u) => ({
      id: u.id,
      name: u.name,
      lat: u.lat ?? null,
      lng: u.lng ?? null,
    }));
    this.safety
      .hiddenFromMany(everyone.map((u) => u.id))
      .then((hidden) => {
        for (const u of everyone) {
          const blocked = hidden.get(u.id);
          this.sendAll(u, 'people', blocked?.size ? people.filter((p) => !blocked.has(p.id)) : people);
        }
      })
      .catch((error: Error) => this.logger.warn(`Couldn't broadcast people: ${error.message}`));
  }

  private sendAll(user: ConnectedUser, event: string, data: unknown) {
    for (const socket of user.sockets) this.send(socket, event, data);
  }

  private send(socket: WebSocket, event: string, data: unknown) {
    if (socket.readyState === socket.OPEN) {
      socket.send(JSON.stringify({ event, data }));
    }
  }
}
