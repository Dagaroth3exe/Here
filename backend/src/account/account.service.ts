import { Inject, Injectable, Logger } from '@nestjs/common';
import type { Redis } from 'ioredis';
import { DataSource } from 'typeorm';
import { markAccountDeleted } from '../auth/deleted-accounts.js';
import { EmergencyService } from '../emergency/emergency.service.js';
import { UserEvents } from '../events/user-events.js';
import { REDIS_CLIENT } from '../redis/redis.module.js';

/** Stands in for a deleted author on community content that's kept. */
export const DELETED_USER = 'deleted';

@Injectable()
export class AccountService {
  private readonly logger = new Logger(AccountService.name);

  constructor(
    private readonly dataSource: DataSource,
    private readonly emergencies: EmergencyService,
    private readonly events: UserEvents,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  /**
   * Deletes the account and everything personal tied to it, for good:
   * profile and sign-in methods, chats (both sides of every conversation),
   * blocks, reports filed, push registrations, settings, and SOS alerts
   * (they hold precise locations). Ask HERE questions and answers stay for
   * the community — they're already shown anonymously — but lose any link to
   * the account.
   */
  async delete(userId: string): Promise<void> {
    // An alert still running is ended properly first, so sirens stop.
    await this.emergencies.endOpenAlert(userId).catch(() => {});
    // Refuse the account's tokens from now on, and drop it from the map.
    await markAccountDeleted(this.redis, userId);
    this.events.accountDeleted(userId);

    await this.dataSource.transaction(async (db) => {
      await db.query(`DELETE FROM messages WHERE sender_id = $1 OR recipient_id = $1`, [userId]);
      await db.query(`DELETE FROM chat_connections WHERE user_a = $1 OR user_b = $1`, [userId]);
      await db.query(`DELETE FROM chat_reads WHERE user_id = $1 OR other_id = $1`, [userId]);
      await db.query(`DELETE FROM blocks WHERE blocker_id = $1 OR blocked_id = $1`, [userId]);
      await db.query(`DELETE FROM reports WHERE reporter_id = $1`, [userId]);
      await db.query(`DELETE FROM push_endpoints WHERE user_id = $1`, [userId]);
      await db.query(`DELETE FROM area_preferences WHERE user_id = $1::uuid`, [userId]);
      await db.query(`DELETE FROM emergencies WHERE user_id = $1`, [userId]);
      // Other people's alerts: forget that this account was alerted or flagged one.
      await db.query(
        `UPDATE emergencies
            SET recipient_ids = array_remove(recipient_ids, $1::uuid),
                flagged_by = array_remove(flagged_by, $1::uuid)
          WHERE $1::uuid = ANY(recipient_ids) OR $1::uuid = ANY(flagged_by)`,
        [userId],
      );
      await db.query(`UPDATE ask_questions SET asker_id = $2 WHERE asker_id = $1`, [userId, DELETED_USER]);
      await db.query(`UPDATE ask_answers SET author_id = $2 WHERE author_id = $1`, [userId, DELETED_USER]);
      // Passkeys and authenticator codes go with it (ON DELETE CASCADE).
      await db.query(`DELETE FROM users WHERE id = $1`, [userId]);
    });
    this.logger.log(`Account ${userId} deleted`);
  }
}
