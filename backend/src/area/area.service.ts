import { Inject, Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Redis } from 'ioredis';
import { Repository } from 'typeorm';
import { Emergency } from '../emergency/emergency.entity.js';
import { UserEvents } from '../events/user-events.js';
import { REDIS_CLIENT } from '../redis/redis.module.js';
import { AreaPreference } from './area-preference.entity.js';

/** Grid cell size in degrees (~550 m north–south); an "area" is a cell and its 8 neighbours, ~1.6 km across. */
const CELL_DEG = 0.005;
/** How far back alerts count. */
export const AREA_WINDOW_DAYS = 30;
/** Too-fresh alerts are left out, so an area notice can't point at one that's happening now. */
const PRIVACY_DELAY_MS = 60 * 60 * 1000;
/** Fewer people than this and nothing is said — a single alert must never be identifiable. */
export const AREA_MIN_PEOPLE = 2;
/** From this many people on, it's "several" rather than "some". */
const SEVERAL_FROM = 4;
/** At most one notice per person per area per day. */
const NOTICE_EVERY_S = 24 * 60 * 60;
/** A heat map only makes sense for a neighbourhood-to-city view (~0.3° ≈ 33 km). */
const MAX_HEATMAP_SPAN = 0.3;
/** Summaries are cached briefly — locations stream in far more often than alerts change. */
const CACHE_MS = 5 * 60 * 1000;

export type AreaLevel = 'quiet' | 'some' | 'several';

/**
 * What's known about an area from HERE's own emergency alerts. Deliberately
 * about *reported alerts*, not "danger": it counts distinct people who raised
 * a genuine (not false) alarm nearby recently, never says where, and says
 * nothing below [AREA_MIN_PEOPLE].
 */
export interface AreaSummary {
  level: AreaLevel;
  /** Distinct people who raised an alarm in the area — null when too few to say. */
  people: number | null;
  windowDays: number;
  radiusMeters: number;
  source: 'here-alerts';
}

@Injectable()
export class AreaService {
  private readonly logger = new Logger(AreaService.name);
  private readonly cache = new Map<string, { at: number; summary: AreaSummary }>();

  constructor(
    @InjectRepository(Emergency) private readonly emergencies: Repository<Emergency>,
    @InjectRepository(AreaPreference) private readonly prefs: Repository<AreaPreference>,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    private readonly events: UserEvents,
  ) {}

  private cellOf(lat: number, lng: number): [number, number] {
    return [Math.floor(lat / CELL_DEG), Math.floor(lng / CELL_DEG)];
  }

  async summary(lat: number, lng: number): Promise<AreaSummary> {
    const [row, col] = this.cellOf(lat, lng);
    const key = `${row}:${col}`;
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.at < CACHE_MS) return cached.summary;

    // The 3×3 block of cells around this one, as a lat/lng box.
    const [{ people }] = (await this.emergencies.query(
      `SELECT count(DISTINCT user_id)::int AS people FROM emergencies
       WHERE false_alarm_at IS NULL
         AND created_at > now() - make_interval(days => $5)
         AND created_at < now() - make_interval(secs => $6)
         AND lat >= $1 AND lat < $2 AND lng >= $3 AND lng < $4`,
      [
        (row - 1) * CELL_DEG,
        (row + 2) * CELL_DEG,
        (col - 1) * CELL_DEG,
        (col + 2) * CELL_DEG,
        AREA_WINDOW_DAYS,
        PRIVACY_DELAY_MS / 1000,
      ],
    )) as { people: number }[];

    const enough = people >= AREA_MIN_PEOPLE;
    const summary: AreaSummary = {
      level: !enough ? 'quiet' : people >= SEVERAL_FROM ? 'several' : 'some',
      people: enough ? people : null,
      windowDays: AREA_WINDOW_DAYS,
      radiusMeters: 800,
      source: 'here-alerts',
    };
    this.cache.set(key, { at: Date.now(), summary });
    return summary;
  }

  /**
   * Cells of the grid inside a map box where at least [AREA_MIN_PEOPLE]
   * different people raised a genuine alert in the window — for the SOS
   * tab's heat map. Same privacy rules as [summary]: no individual alert,
   * nothing from the last hour. Empty when the box is too big to be local
   * (zoomed out to a whole region).
   */
  async heatmap(box: { south: number; west: number; north: number; east: number }): Promise<{
    cells: { south: number; west: number; north: number; east: number; level: AreaLevel; people: number }[];
    tooWide: boolean;
  }> {
    if (box.north - box.south > MAX_HEATMAP_SPAN || box.east - box.west > MAX_HEATMAP_SPAN) {
      return { cells: [], tooWide: true };
    }
    const rows = (await this.emergencies.query(
      `SELECT floor(lat / $1)::int AS row, floor(lng / $1)::int AS col, count(DISTINCT user_id)::int AS people
       FROM emergencies
       WHERE false_alarm_at IS NULL
         AND created_at > now() - make_interval(days => $6)
         AND created_at < now() - make_interval(secs => $7)
         AND lat BETWEEN $2 AND $3 AND lng BETWEEN $4 AND $5
       GROUP BY 1, 2
       HAVING count(DISTINCT user_id) >= $8`,
      [CELL_DEG, box.south, box.north, box.west, box.east, AREA_WINDOW_DAYS, PRIVACY_DELAY_MS / 1000, AREA_MIN_PEOPLE],
    )) as { row: number; col: number; people: number }[];
    return {
      tooWide: false,
      cells: rows.map((r) => ({
        south: r.row * CELL_DEG,
        west: r.col * CELL_DEG,
        north: (r.row + 1) * CELL_DEG,
        east: (r.col + 1) * CELL_DEG,
        level: r.people >= SEVERAL_FROM ? 'several' : 'some',
        people: r.people,
      })),
    };
  }

  /**
   * Someone's position updated: if their area has recent alerts and they
   * haven't been told about this area today (and haven't turned notices
   * off), tell them — live and as a push. Never throws; it's a side effect.
   */
  async onLocation(userId: string, lat: number, lng: number): Promise<void> {
    try {
      const summary = await this.summary(lat, lng);
      if (summary.level === 'quiet') return;
      const pref = await this.prefs.findOne({ where: { userId } });
      if (pref && !pref.notices) return;
      const [row, col] = this.cellOf(lat, lng);
      // SET NX: only the first update in this area today gets through.
      const fresh = await this.redis.set(`area:notice:${userId}:${row}:${col}`, '1', 'EX', NOTICE_EVERY_S, 'NX');
      if (fresh !== 'OK') return;
      this.events.deliver({
        to: [userId],
        event: 'area:notice',
        data: summary,
        push: {
          title: 'Heads up about this area',
          body: `${summary.people} people raised emergency alerts within about 1 km in the last ${AREA_WINDOW_DAYS} days. Stay aware of your surroundings.`,
          data: { kind: 'area' },
        },
      });
    } catch (error) {
      this.logger.warn(`Area notice for ${userId} failed: ${(error as Error).message}`);
    }
  }

  async preference(userId: string): Promise<{ notices: boolean }> {
    const pref = await this.prefs.findOne({ where: { userId } });
    return { notices: pref?.notices ?? true };
  }

  async setPreference(userId: string, notices: boolean): Promise<{ notices: boolean }> {
    await this.prefs.upsert({ userId, notices }, ['userId']);
    return { notices };
  }
}
