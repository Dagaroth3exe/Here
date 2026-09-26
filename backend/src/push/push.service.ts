import { BadRequestException, Injectable, Logger, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import type { Subscription } from 'rxjs';
import { UserEvents, type PushNotice } from '../events/user-events.js';
import { PushEndpoint } from './push-endpoint.entity.js';
import { encryptWebPush } from './webpush.js';

/**
 * Phone notifications over UnifiedPush, through the self-hosted ntfy server.
 * Phones register an endpoint URL; anything on the event bus with a
 * [PushNotice] is POSTed there. Endpoints must live on our own ntfy server —
 * the backend POSTs to them, so accepting any URL would let a client make it
 * call internal services (SSRF).
 */
@Injectable()
export class PushService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PushService.name);
  private readonly publicUrl: string;
  private readonly internalUrl: string;
  private subscription?: Subscription;

  constructor(
    @InjectRepository(PushEndpoint) private readonly endpoints: Repository<PushEndpoint>,
    private readonly events: UserEvents,
    config: ConfigService,
  ) {
    this.publicUrl = (config.get<string>('NTFY_PUBLIC_URL') ?? 'http://10.0.2.2:8090').replace(/\/$/, '');
    this.internalUrl = (config.get<string>('NTFY_INTERNAL_URL') ?? 'http://localhost:8090').replace(/\/$/, '');
  }

  onModuleInit() {
    this.subscription = this.events.deliveries$.subscribe((delivery) => {
      if (delivery.push) void this.notify(delivery.to, delivery.push);
    });
  }

  onModuleDestroy() {
    this.subscription?.unsubscribe();
  }

  async register(userId: string, endpoint: string, keys: { p256dh: string; auth: string } | null): Promise<void> {
    if (!this.internalAddress(endpoint)) {
      throw new BadRequestException(`Push endpoints must be on ${this.publicUrl}`);
    }
    // One endpoint belongs to one phone; if someone else signs in on it, it moves to them.
    await this.endpoints.upsert({ endpoint, userId, p256dh: keys?.p256dh ?? null, auth: keys?.auth ?? null }, [
      'endpoint',
    ]);
  }

  async unregister(userId: string, endpoint: string): Promise<void> {
    await this.endpoints.delete({ endpoint, userId });
  }

  /** Where the backend should POST for a phone's endpoint, or null if it isn't on our ntfy server. */
  internalAddress(endpoint: string): string | null {
    let url: URL;
    try {
      url = new URL(endpoint);
    } catch {
      return null;
    }
    const base = new URL(this.publicUrl);
    // Topic paths only — no userinfo, no other hosts/ports, no traversal.
    if (url.origin !== base.origin || url.username || url.password || !/^\/[A-Za-z0-9_-]{8,64}$/.test(url.pathname)) {
      return null;
    }
    return `${this.internalUrl}${url.pathname}${url.search}`;
  }

  private async notify(userIds: string[], notice: PushNotice): Promise<void> {
    const targets = await this.endpoints.find({ where: { userId: In(userIds) } });
    await Promise.all(
      targets.map(async ({ endpoint, p256dh, auth }) => {
        const address = this.internalAddress(endpoint);
        if (!address) return;
        const message = Buffer.from(JSON.stringify(notice));
        // Encrypted whenever the phone gave us keys, so the push server only relays ciphertext.
        const encrypted = p256dh && auth ? encryptWebPush(message, p256dh, auth) : null;
        try {
          const response = await fetch(address, {
            method: 'POST',
            headers: encrypted ? { 'Content-Encoding': 'aes128gcm', TTL: '86400' } : { TTL: '86400' },
            body: new Uint8Array(encrypted ?? message),
            signal: AbortSignal.timeout(5_000),
          });
          // The distributor unregistered this endpoint — stop sending to it.
          if (response.status === 404 || response.status === 410) await this.endpoints.delete({ endpoint });
        } catch (error) {
          this.logger.warn(`Push to ${endpoint} failed: ${(error as Error).message}`);
        }
      }),
    );
  }
}
