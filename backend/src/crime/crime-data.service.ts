import { Injectable, Logger, type OnApplicationBootstrap, type OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';
import { jaroWinkler, matchUnits, normalizeState } from './name-match.js';
import { parseDistrictTable } from './ncrb-table.js';

/** data.gov.in's public catalogue search (the same one its website uses). */
const CATALOGUE = 'https://www.data.gov.in/backend/dmspublic/v1/resources';
/** NCRB "Crime in India" district tables, e.g. "District-wise Number of Indian Penal Code (IPC) Crimes during 2022". */
const TABLE_TITLE = /^District-wise Number of (?:Indian Penal Code \(IPC\)|IPC|.*BNS.*) Crimes during\s*(\d{4})\s*$/i;
/** geoBoundaries — open district boundaries (ODbL), from India's Local Government Directory. */
const BOUNDARIES_API = 'https://www.geoboundaries.org/api/current/gbOpen/IND';
const CHECK_EVERY_MS = 7 * 24 * 60 * 60 * 1000;
const HEADERS = { 'User-Agent': 'HERE (open data importer)' };

/**
 * Keeps official district crime figures up to date: map districts from
 * geoBoundaries (once), NCRB district tables from data.gov.in (checked
 * weekly — a new year's table is imported as soon as it's published), and
 * which NCRB police units make up each map district.
 */
@Injectable()
export class CrimeDataService implements OnApplicationBootstrap, OnModuleDestroy {
  private readonly logger = new Logger(CrimeDataService.name);
  private timer?: NodeJS.Timeout;
  private first?: NodeJS.Timeout;
  private running = false;

  constructor(
    @InjectDataSource() private readonly db: DataSource,
    private readonly config: ConfigService,
  ) {}

  onApplicationBootstrap() {
    if (this.config.get('CRIME_SYNC') === 'off') return;
    // Soon after start (not during it), then weekly.
    this.first = setTimeout(() => void this.sync(), 15_000);
    this.timer = setInterval(() => void this.sync(), CHECK_EVERY_MS);
  }

  onModuleDestroy() {
    clearTimeout(this.first);
    clearInterval(this.timer);
  }

  /** One full pass. Safe to call any time; overlapping calls are skipped. */
  async sync(): Promise<void> {
    if (this.running) return;
    this.running = true;
    try {
      await this.ensureSchema();
      const [{ n }] = (await this.db.query('SELECT count(*)::int AS n FROM admin_districts')) as { n: number }[];
      if (n === 0) await this.importBoundaries();
      await this.importNewTables();
      // Cheap (a second or two), so every pass — matching improvements apply
      // to data already imported.
      await this.rematch();
    } catch (error) {
      this.logger.warn(`Crime data sync failed: ${(error as Error).message}`);
    } finally {
      this.running = false;
    }
  }

  async ensureSchema(): Promise<void> {
    await this.db.query(`
      CREATE EXTENSION IF NOT EXISTS postgis;
      CREATE TABLE IF NOT EXISTS admin_districts (
        id serial PRIMARY KEY,
        name text NOT NULL,
        state text,
        geom geometry(MultiPolygon, 4326) NOT NULL
      );
      CREATE INDEX IF NOT EXISTS admin_districts_geom ON admin_districts USING gist (geom);
      CREATE TABLE IF NOT EXISTS crime_datasets (
        id serial PRIMARY KEY,
        year int NOT NULL,
        title text NOT NULL,
        url text NOT NULL UNIQUE,
        published_at timestamptz,
        rows int NOT NULL,
        matched_districts int NOT NULL DEFAULT 0,
        imported_at timestamptz NOT NULL DEFAULT now()
      );
      CREATE TABLE IF NOT EXISTS crime_unit_stats (
        dataset_id int NOT NULL REFERENCES crime_datasets(id) ON DELETE CASCADE,
        state text NOT NULL,
        unit text NOT NULL,
        total int NOT NULL,
        heads jsonb NOT NULL,
        district_id int REFERENCES admin_districts(id) ON DELETE SET NULL,
        PRIMARY KEY (dataset_id, state, unit)
      );
      CREATE INDEX IF NOT EXISTS crime_unit_stats_district ON crime_unit_stats (district_id);
    `);
  }

  private async getJson<T>(url: string): Promise<T> {
    const response = await fetch(url, { headers: HEADERS, signal: AbortSignal.timeout(60_000) });
    if (!response.ok) throw new Error(`${url} → HTTP ${response.status}`);
    return (await response.json()) as T;
  }

  /** Districts (ADM2) with their state (the ADM1 region each falls in). */
  private async importBoundaries(): Promise<void> {
    type Api = { simplifiedGeometryGeoJSON: string };
    type Fc = { features: { properties: { shapeName: string }; geometry: unknown }[] };
    const [states, districts] = await Promise.all(
      ['ADM1', 'ADM2'].map(async (level) => {
        const meta = await this.getJson<Api>(`${BOUNDARIES_API}/${level}/`);
        return this.getJson<Fc>(meta.simplifiedGeometryGeoJSON);
      }),
    );
    const geom = `ST_Multi(ST_CollectionExtract(ST_MakeValid(ST_SetSRID(ST_GeomFromGeoJSON($2), 4326)), 3))`;
    await this.db.transaction(async (tx) => {
      await tx.query('CREATE TEMP TABLE states (name text, geom geometry) ON COMMIT DROP');
      for (const f of states.features) {
        await tx.query(`INSERT INTO states VALUES ($1, ${geom})`, [f.properties.shapeName, JSON.stringify(f.geometry)]);
      }
      await tx.query('DELETE FROM admin_districts');
      for (const f of districts.features) {
        await tx.query(`INSERT INTO admin_districts (name, geom) VALUES ($1, ${geom})`, [
          f.properties.shapeName,
          JSON.stringify(f.geometry),
        ]);
      }
      await tx.query(`
        UPDATE admin_districts d SET state = s.name
        FROM states s WHERE ST_Covers(s.geom, ST_PointOnSurface(d.geom))`);
    });
    this.logger.log(`Imported ${districts.features.length} district boundaries (geoBoundaries, ODbL)`);
  }

  /** Every NCRB district table on data.gov.in not imported yet. Returns how many were imported. */
  private async importNewTables(): Promise<number> {
    type Row = { title: string[] | string; datafile?: string[]; published_date?: string[] | string };
    const search = await this.getJson<{ data: { rows: Row[] } }>(
      `${CATALOGUE}?query=${encodeURIComponent('District-wise Number of Crimes during')}&offset=0&limit=100&sort%5B_score%5D=desc`,
    );
    const first = <T>(v: T[] | T | undefined) => (Array.isArray(v) ? v[0] : v);
    const tables = search.data.rows
      .map((r) => ({
        title: String(first(r.title)).replace(/\s+/g, ' ').trim(),
        url: first(r.datafile),
        published: first(r.published_date),
      }))
      .map((r) => ({ ...r, year: Number(TABLE_TITLE.exec(r.title)?.[1]) }))
      .filter((r) => r.year && r.url?.endsWith('.csv'));

    let imported = 0;
    for (const table of tables) {
      const [done] = (await this.db.query('SELECT 1 FROM crime_datasets WHERE url = $1', [table.url])) as unknown[];
      if (done) continue;
      try {
        const response = await fetch(table.url!, { headers: HEADERS, signal: AbortSignal.timeout(120_000) });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const rows = parseDistrictTable(await response.text());
        await this.db.transaction(async (tx) => {
          const [{ id }] = (await tx.query(
            `INSERT INTO crime_datasets (year, title, url, published_at, rows)
             VALUES ($1, $2, $3, to_timestamp($4), $5) RETURNING id`,
            [table.year, table.title, table.url, Number(table.published) || null, rows.length],
          )) as { id: number }[];
          for (const r of rows) {
            await tx.query(
              `INSERT INTO crime_unit_stats (dataset_id, state, unit, total, heads) VALUES ($1, $2, $3, $4, $5)
               ON CONFLICT DO NOTHING`,
              [id, r.state, r.unit, r.total, JSON.stringify(r.heads)],
            );
          }
        });
        imported++;
        this.logger.log(`Imported NCRB ${table.year}: "${table.title}" (${rows.length} police units)`);
      } catch (error) {
        this.logger.warn(`Couldn't import "${table.title}": ${(error as Error).message}`);
      }
    }
    return imported;
  }

  /** Links every dataset's police units to map districts, state by state. */
  private async rematch(): Promise<void> {
    const districts = (await this.db.query('SELECT id, name, state FROM admin_districts WHERE state IS NOT NULL')) as {
      id: number;
      name: string;
      state: string;
    }[];
    const byState = new Map<string, typeof districts>();
    for (const d of districts) {
      const key = normalizeState(d.state);
      byState.set(key, [...(byState.get(key) ?? []), d]);
    }
    const stateKeys = [...byState.keys()];
    const datasets = (await this.db.query('SELECT id, year FROM crime_datasets')) as { id: number; year: number }[];

    for (const { id, year } of datasets) {
      const units = (await this.db.query('SELECT state, unit FROM crime_unit_stats WHERE dataset_id = $1', [id])) as {
        state: string;
        unit: string;
      }[];
      const unitsByState = new Map<string, string[]>();
      for (const u of units) unitsByState.set(u.state, [...(unitsByState.get(u.state) ?? []), u.unit]);

      let matched = 0;
      const unmatched: string[] = [];
      await this.db.transaction(async (tx) => {
        await tx.query('UPDATE crime_unit_stats SET district_id = NULL WHERE dataset_id = $1', [id]);
        for (const [state, stateUnits] of unitsByState) {
          const norm = normalizeState(state);
          const key = byState.has(norm)
            ? norm
            : stateKeys.find((k) => jaroWinkler(k, norm) >= 0.93);
          const stateDistricts = key ? byState.get(key)! : [];
          const matches = matchUnits(
            stateDistricts.map((d) => d.name),
            stateUnits,
            state,
          );
          for (const d of stateDistricts) {
            for (const unit of matches.get(d.name) ?? []) {
              await tx.query(
                'UPDATE crime_unit_stats SET district_id = $1 WHERE dataset_id = $2 AND state = $3 AND unit = $4',
                [d.id, id, state, unit],
              );
            }
            if (matches.has(d.name)) matched++;
          }
          const placed = new Set([...matches.values()].flat());
          unmatched.push(...stateUnits.filter((u) => !placed.has(u)).map((u) => `${u} (${state})`));
        }
        await tx.query('UPDATE crime_datasets SET matched_districts = $1 WHERE id = $2', [matched, id]);
      });
      this.logger.log(
        `NCRB ${year}: ${matched} of ${districts.length} map districts matched; ${unmatched.length} police units not placed`,
      );
    }
  }
}
