import { Inject, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
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
import type { Redis } from 'ioredis';
import type { Subscription } from 'rxjs';
import type { WebSocket } from 'ws';
import { AreaService } from '../area/area.service.js';
import { isAccountDeleted } from '../auth/deleted-accounts.js';
import { ChatService } from '../chat/chat.service.js';
import { UserEvents } from '../events/user-events.js';
import { SAFETY_CHANGED, SafetyService } from '../safety/safety.service.js';
import { REDIS_CLIENT } from '../redis/redis.module.js';
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

/** Great-circle distance in meters between two coordinates. */
function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(h));
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
export class RealtimeGateway implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RealtimeGateway.name);
  private readonly users = new Map<string, ConnectedUser>();
  private chatSubscription?: Subscription;
  private deletedSubscription?: Subscription;

  constructor(
    private readonly jwtService: JwtService,
    private readonly chatService: ChatService,
    private readonly userEvents: UserEvents,
    private readonly safety: SafetyService,
    private readonly area: AreaService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
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
    // A deleted account drops off the map at once, on every device.
    this.deletedSubscription = this.userEvents.accountDeleted$.subscribe((id) => {
      const user = this.users.get(id);
      if (!user) return;
      for (const socket of user.sockets) socket.close(4003, 'Account deleted');
      this.users.delete(id);
      this.broadcastPeople();
    });
  }

  onModuleDestroy() {
    this.chatSubscription?.unsubscribe();
    this.deletedSubscription?.unsubscribe();
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
    // Checked before the socket counts as Reachable; the check is async, so a
    // closed-in-the-meantime socket is simply never added.
    void isAccountDeleted(this.redis, id).then((deleted) => {
      if (deleted) socket.close(4003, 'Account deleted');
      else this.register(socket, id, payload);
    });
  }

  private register(socket: TrackedSocket, id: string, payload: JwtPayload) {
    if (socket.readyState !== socket.OPEN) return;
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
    // Recent alerts around here? (At most one notice per area per day.)
    void this.area.onLocation(user.id, user.lat, user.lng);
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

  /**
   * Reachable people whose last shared position is within [radiusMeters] —
   * who an emergency alert goes to. Positions are coarsened (~110 m), which
   * is plenty at this scale.
   */
  nearbyUserIds(lat: number, lng: number, radiusMeters: number): string[] {
    return [...this.users.values()]
      .filter((u) => u.lat != null && u.lng != null && distanceMeters(lat, lng, u.lat, u.lng) <= radiusMeters)
      .map((u) => u.id);
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
