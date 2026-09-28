import { ForbiddenException, HttpException, HttpStatus, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, MoreThan, Repository } from 'typeorm';
import { UserEvents } from '../events/user-events.js';
import { RealtimeGateway } from '../realtime/realtime.gateway.js';
import { SafetyService } from '../safety/safety.service.js';
import { publicName } from '../users/public-name.js';
import { UsersService } from '../users/users.service.js';
import type { EmergencyReason, RaiseEmergencyDto } from './dto/raise-emergency.dto.js';
import { Emergency } from './emergency.entity.js';

/** Who gets alerted: Reachable people within this distance of the person in trouble. */
export const EMERGENCY_RADIUS_METERS = 2000;

/** An alarm nobody closed stops counting as active after this long. */
const ACTIVE_FOR_MS = 60 * 60 * 1000;

/** Raising the alarm is serious; a handful an hour is plenty for anyone genuine. */
const MAX_PER_HOUR = 3;

/** False alarms (within [STRIKE_WINDOW_MS]) that pause someone's SOS… */
export const FALSE_ALARM_LIMIT = 2;
/** …for this long, counted from the latest one. */
const SOS_PAUSE_MS = 30 * 24 * 60 * 60 * 1000;
/** Older false alarms stop counting. */
const STRIKE_WINDOW_MS = 90 * 24 * 60 * 60 * 1000;
/** How many different people alerted must flag it before it counts — so no one person nearby (possibly whoever the alarm is about) can get a real victim's SOS paused. */
export const FLAGS_FOR_FALSE_ALARM = 2;
/** Flags are taken while it's on and for a day after. */
const FLAG_WINDOW_MS = 24 * 60 * 60 * 1000;

/** Where someone stands with false alarms — shown on the SOS screen. */
export interface SosStanding {
  /** False alarms in the last 90 days. */
  falseAlarms: number;
  limit: number;
  /** SOS is paused until then (ISO), or null. */
  pausedUntil: string | null;
}

const REASON_TEXT: Record<EmergencyReason, string> = {
  harassment: 'is being harassed',
  assault: 'is being assaulted',
  followed: 'is being followed',
  medical: 'has a medical emergency',
  other: 'needs immediate help',
};

/** What recipients (and the sender) get for an alarm. */
export interface EmergencyPayload {
  id: string;
  fromId: string;
  fromName: string;
  lat: number;
  lng: number;
  reason: EmergencyReason | null;
  message: string | null;
  createdAt: string;
  resolvedAt: string | null;
  /** How many people were alerted. */
  alerted: number;
  /** It turned out not to be real (said by the sender, or flagged by enough helpers). */
  falseAlarm: boolean;
}

@Injectable()
export class EmergencyService {
  constructor(
    @InjectRepository(Emergency) private readonly emergencies: Repository<Emergency>,
    private readonly realtime: RealtimeGateway,
    private readonly safety: SafetyService,
    private readonly users: UsersService,
    private readonly events: UserEvents,
  ) {}

  /**
   * Alerts every Reachable person nearby — live (siren, full-screen alert)
   * and as a high-priority push. Raising again while an alarm is still open
   * just moves it to the new location rather than alerting everyone twice.
   */
  async raise(userId: string, dto: RaiseEmergencyDto): Promise<EmergencyPayload> {
    const open = await this.activeFor(userId);
    if (open) return this.updateLocation(userId, open.id, dto.lat, dto.lng);

    const standing = await this.standing(userId);
    if (standing.pausedUntil) {
      const until = new Date(standing.pausedUntil).toISOString().slice(0, 10);
      throw new ForbiddenException(
        `SOS is paused until ${until} after repeated false alarms. If you're in danger, call 112.`,
      );
    }

    const recent = await this.emergencies.count({
      where: { userId, createdAt: MoreThan(new Date(Date.now() - 60 * 60 * 1000)) },
    });
    if (recent >= MAX_PER_HOUR) {
      throw new HttpException(
        "You've raised several alarms in the last hour. If you're in danger, call 112.",
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    const user = await this.users.findById(userId);
    if (!user) throw new NotFoundException('User not found');
    const hidden = await this.safety.hiddenFrom(userId);
    const recipientIds = this.realtime
      .nearbyUserIds(dto.lat, dto.lng, EMERGENCY_RADIUS_METERS)
      .filter((id) => id !== userId && !hidden.has(id));

    const saved = await this.emergencies.save(
      this.emergencies.create({
        userId,
        lat: dto.lat,
        lng: dto.lng,
        reason: dto.reason ?? null,
        message: dto.message?.trim() || null,
        recipientIds,
      }),
    );
    const payload = this.toPayload(saved, publicName(user));
    const what = REASON_TEXT[payload.reason ?? 'other'];
    this.events.deliver({
      to: recipientIds,
      event: 'emergency:alert',
      data: payload,
      push: {
        title: `🚨 ${payload.fromName} ${what} nearby`,
        body: payload.message ?? 'They need immediate assistance. Open HERE to see where.',
        data: { kind: 'emergency', emergencyId: saved.id },
      },
    });
    return payload;
  }

  /** The person in trouble is moving — keep everyone who was alerted following them. */
  async updateLocation(userId: string, id: string, lat: number, lng: number): Promise<EmergencyPayload> {
    const emergency = await this.ownOpen(userId, id);
    emergency.lat = lat;
    emergency.lng = lng;
    await this.emergencies.update(id, { lat, lng });
    const payload = this.toPayload(emergency, await this.nameOf(userId));
    this.events.deliver({ to: emergency.recipientIds, event: 'emergency:update', data: payload });
    return payload;
  }

  /**
   * "I'm safe now" — silences every siren it started. With [falseAlarm] the
   * sender owns up that it wasn't real, which counts as a strike.
   */
  async resolve(userId: string, id: string, falseAlarm = false): Promise<void> {
    const emergency = await this.ownOpen(userId, id);
    const now = new Date();
    emergency.resolvedAt = now;
    if (falseAlarm && !emergency.falseAlarmAt) emergency.falseAlarmAt = now;
    await this.emergencies.update(id, { resolvedAt: now, falseAlarmAt: emergency.falseAlarmAt });
    const payload = this.toPayload(emergency, await this.nameOf(userId));
    this.events.deliver({
      to: emergency.recipientIds,
      event: 'emergency:resolved',
      data: payload,
      push: falseAlarm
        ? {
            title: `${payload.fromName}'s alert was a false alarm`,
            body: 'They ended it and said it was a false alarm. No help is needed.',
            data: { kind: 'emergency', emergencyId: id },
          }
        : {
            title: `${payload.fromName} is safe now`,
            body: 'They closed their emergency alert. Thank you for being there.',
            data: { kind: 'emergency', emergencyId: id },
          },
    });
  }

  /**
   * Someone who was alerted says it was a false alarm. One flag per person;
   * once [FLAGS_FOR_FALSE_ALARM] different people have, it's a strike and
   * the sender is told. Both steps are single conditional UPDATEs, so
   * people flagging at the same moment can't double-count or miss it.
   */
  async flag(userId: string, id: string): Promise<{ flags: number; falseAlarm: boolean }> {
    const emergency = await this.emergencies.findOne({ where: { id } });
    if (!emergency || !emergency.recipientIds.includes(userId)) throw new NotFoundException('No such alert');
    const endedAt = emergency.resolvedAt?.getTime() ?? Date.now();
    if (Date.now() - endedAt > FLAG_WINDOW_MS) throw new ForbiddenException('This alert is too old to flag');

    await this.emergencies.query(
      `UPDATE emergencies SET flagged_by = array_append(flagged_by, $2::uuid)
       WHERE id = $1 AND NOT ($2::uuid = ANY(flagged_by))`,
      [id, userId],
    );
    // Enough people say it isn't real: that's a strike, and if it's still
    // running it ends here — everyone's siren stops.
    const [struck] = (await this.emergencies.query(
      `UPDATE emergencies SET false_alarm_at = now(), resolved_at = COALESCE(resolved_at, now())
       WHERE id = $1 AND false_alarm_at IS NULL AND cardinality(flagged_by) >= $2
       RETURNING id`,
      [id, FLAGS_FOR_FALSE_ALARM],
    )) as [{ id: string }[], number];

    const after = await this.emergencies.findOneOrFail({ where: { id } });
    if (struck.length) {
      if (!emergency.resolvedAt) {
        this.events.deliver({
          to: after.recipientIds,
          event: 'emergency:resolved',
          data: this.toPayload(after, await this.nameOf(after.userId)),
        });
      }
      await this.announceStrike(emergency.userId);
    }
    return { flags: after.flaggedBy.length, falseAlarm: after.falseAlarmAt !== null };
  }

  /** False alarms in the window, and whether SOS is paused because of them. */
  async standing(userId: string): Promise<SosStanding> {
    const strikes = await this.emergencies.find({
      where: { userId, falseAlarmAt: MoreThan(new Date(Date.now() - STRIKE_WINDOW_MS)) },
      order: { falseAlarmAt: 'DESC' },
      select: { id: true, falseAlarmAt: true },
    });
    let pausedUntil: string | null = null;
    if (strikes.length >= FALSE_ALARM_LIMIT) {
      const until = strikes[0].falseAlarmAt!.getTime() + SOS_PAUSE_MS;
      if (until > Date.now()) pausedUntil = new Date(until).toISOString();
    }
    return { falseAlarms: strikes.length, limit: FALSE_ALARM_LIMIT, pausedUntil };
  }

  /** People flagged your alarm as false: say so (and whether SOS is now paused). */
  private async announceStrike(userId: string) {
    const standing = await this.standing(userId);
    this.events.deliver({
      to: [userId],
      event: 'emergency:strike',
      data: standing,
      push: {
        title: 'Your emergency alert was flagged as a false alarm',
        body: standing.pausedUntil
          ? 'After repeated false alarms, SOS is paused for 30 days. In danger? Call 112.'
          : `People nearby said it wasn't real. ${FALSE_ALARM_LIMIT} false alarms pause SOS for 30 days.`,
        data: { kind: 'sos' },
      },
    });
  }

  /** One alarm, for its sender or someone it alerted (e.g. opening it from a push). */
  async get(viewerId: string, id: string): Promise<EmergencyPayload> {
    const emergency = await this.emergencies.findOne({ where: { id } });
    if (!emergency || (emergency.userId !== viewerId && !emergency.recipientIds.includes(viewerId))) {
      throw new NotFoundException('No such alert');
    }
    return this.toPayload(emergency, await this.nameOf(emergency.userId));
  }

  /** Your own open alarm, if any — so the app can restore it after a restart. */
  async mine(userId: string): Promise<EmergencyPayload | null> {
    const open = await this.activeFor(userId);
    return open ? this.toPayload(open, await this.nameOf(userId)) : null;
  }

  private activeFor(userId: string): Promise<Emergency | null> {
    return this.emergencies.findOne({
      where: { userId, resolvedAt: IsNull(), createdAt: MoreThan(new Date(Date.now() - ACTIVE_FOR_MS)) },
      order: { createdAt: 'DESC' },
    });
  }

  private async ownOpen(userId: string, id: string): Promise<Emergency> {
    const emergency = await this.emergencies.findOne({ where: { id } });
    if (!emergency) throw new NotFoundException('No such alert');
    if (emergency.userId !== userId) throw new ForbiddenException('Not your alert');
    if (emergency.resolvedAt || emergency.createdAt.getTime() < Date.now() - ACTIVE_FOR_MS) {
      throw new NotFoundException('This alert has already ended');
    }
    return emergency;
  }

  private async nameOf(userId: string): Promise<string> {
    const user = await this.users.findById(userId);
    return user ? publicName(user) : 'Someone';
  }

  private toPayload(e: Emergency, fromName: string): EmergencyPayload {
    return {
      id: e.id,
      fromId: e.userId,
      fromName,
      lat: e.lat,
      lng: e.lng,
      reason: (e.reason as EmergencyReason | null) ?? null,
      message: e.message,
      createdAt: e.createdAt.toISOString(),
      resolvedAt: e.resolvedAt?.toISOString() ?? null,
      alerted: e.recipientIds.length,
      falseAlarm: e.falseAlarmAt !== null,
    };
  }
}
