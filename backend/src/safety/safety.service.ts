import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Repository } from 'typeorm';
import { UserEvents } from '../events/user-events.js';
import { publicName } from '../users/public-name.js';
import { UsersService } from '../users/users.service.js';
import { Block } from './block.entity.js';
import { Report, type ReportReason, type ReportTarget } from './report.entity.js';

/** Delivered (to no socket) when a block changes, so presence lists get recomputed. */
export const SAFETY_CHANGED = 'safety:changed';

/** Blocking and reporting — the safety net for an app about approaching strangers. */
@Injectable()
export class SafetyService {
  constructor(
    @InjectRepository(Block) private readonly blocks: Repository<Block>,
    @InjectRepository(Report) private readonly reports: Repository<Report>,
    private readonly usersService: UsersService,
    private readonly events: UserEvents,
  ) {}

  async block(blockerId: string, blockedId: string): Promise<void> {
    if (blockerId === blockedId) throw new BadRequestException("You can't block yourself");
    await this.blocks.upsert({ blockerId, blockedId }, ['blockerId', 'blockedId']);
    this.announceChange(blockerId, blockedId);
  }

  async unblock(blockerId: string, blockedId: string): Promise<void> {
    await this.blocks.delete({ blockerId, blockedId });
    this.announceChange(blockerId, blockedId);
  }

  /** Lets the realtime gateway refresh both people's Discover lists right away. */
  private announceChange(a: string, b: string) {
    this.events.deliver({ to: [a, b], event: SAFETY_CHANGED, data: null });
  }

  /** Whether either of the two has blocked the other. */
  async isBlockedEitherWay(a: string, b: string): Promise<boolean> {
    return this.blocks.exists({
      where: [
        { blockerId: a, blockedId: b },
        { blockerId: b, blockedId: a },
      ],
    });
  }

  /** Everyone [userId] must not see or hear from: people they blocked and people who blocked them. */
  async hiddenFrom(userId: string): Promise<Set<string>> {
    const rows = await this.blocks.find({ where: [{ blockerId: userId }, { blockedId: userId }] });
    return new Set(rows.map((r) => (r.blockerId === userId ? r.blockedId : r.blockerId)));
  }

  /** For several users at once (the realtime people list): userId → hidden ids. */
  async hiddenFromMany(userIds: string[]): Promise<Map<string, Set<string>>> {
    const hidden = new Map(userIds.map((id) => [id, new Set<string>()]));
    if (userIds.length === 0) return hidden;
    const rows = await this.blocks.find({ where: [{ blockerId: In(userIds) }, { blockedId: In(userIds) }] });
    for (const row of rows) {
      hidden.get(row.blockerId)?.add(row.blockedId);
      hidden.get(row.blockedId)?.add(row.blockerId);
    }
    return hidden;
  }

  /** The people [userId] blocked (not those who blocked them), for managing blocks. */
  async listBlocked(userId: string): Promise<{ userId: string; name: string; blockedAt: string }[]> {
    const rows = await this.blocks.find({ where: { blockerId: userId }, order: { createdAt: 'DESC' } });
    const users = await this.usersService.findByIds(rows.map((r) => r.blockedId));
    return rows.map((r) => {
      const user = users.get(r.blockedId);
      return { userId: r.blockedId, name: user ? publicName(user) : 'Someone', blockedAt: r.createdAt.toISOString() };
    });
  }

  async report(input: {
    reporterId: string;
    targetType: ReportTarget;
    targetId: string;
    reason: ReportReason;
    details?: string;
  }): Promise<{ id: string }> {
    const saved = await this.reports.save(
      this.reports.create({ ...input, details: input.details?.trim() ?? '' }),
    );
    return { id: saved.id };
  }
}
