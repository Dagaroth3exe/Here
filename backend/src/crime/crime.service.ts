import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

/** One set of official figures, with the year before for comparison. */
interface Figures {
  year: number;
  /** All reported cognizable crimes (IPC/BNS) that year. */
  total: number;
  previous: { year: number; total: number } | null;
  changePercent: number | null;
  source: { name: string; title: string; url: string };
}

/**
 * Official reported-crime figures around a point: the district's (NCRB's
 * district tables, newest 2022) and, where the district is part of one of
 * NCRB's metropolitan cities, the city's (newest edition — 2024 so far).
 */
export interface AreaCrime {
  district: string;
  state: string;
  districtFigures:
    | (Figures & {
        /** The largest of the crime heads shown in the app, biggest first. */
        top: { head: string; count: number }[];
        /** The NCRB police units the figures add up (e.g. city + rural police). */
        units: string[];
      })
    | null;
  cityFigures:
    | (Figures & {
        city: string;
        /** Crimes per lakh (100,000) people, as NCRB published it (on 2011 population). */
        ratePerLakh: number | null;
      })
    | null;
  boundaries: string;
}

const change = (latest: number, previous: number | undefined) =>
  previous && previous > 0 ? Math.round(((latest - previous) / previous) * 1000) / 10 : null;

@Injectable()
export class CrimeService {
  constructor(@InjectDataSource() private readonly db: DataSource) {}

  async forPoint(lat: number, lng: number): Promise<AreaCrime | null> {
    let district: { id: number; name: string; state: string } | undefined;
    try {
      [district] = (await this.db.query(
        `SELECT id, name, state FROM admin_districts
         WHERE ST_Covers(geom, ST_SetSRID(ST_MakePoint($1, $2), 4326)) LIMIT 1`,
        [lng, lat],
      )) as (typeof district)[];
    } catch {
      return null; // not imported yet
    }
    if (!district) return null;
    const [districtFigures, cityFigures] = await Promise.all([this.districtFigures(district.id), this.cityFigures(district.id)]);
    if (!districtFigures && !cityFigures) return null;
    return {
      district: district.name,
      state: district.state,
      districtFigures,
      cityFigures,
      boundaries: 'geoBoundaries (ODbL 1.0)',
    };
  }

  private async districtFigures(districtId: number): Promise<AreaCrime['districtFigures']> {
    const years = (await this.db.query(
      `SELECT ds.year, ds.title, ds.url, sum(s.total)::int AS total,
              json_agg(s.heads) AS heads, array_agg(s.unit ORDER BY s.unit) AS units
       FROM crime_unit_stats s JOIN crime_datasets ds ON ds.id = s.dataset_id
       WHERE s.district_id = $1
       GROUP BY ds.id ORDER BY ds.year DESC LIMIT 2`,
      [districtId],
    )) as { year: number; title: string; url: string; total: number; heads: Record<string, number>[]; units: string[] }[];
    const [latest, before] = years;
    if (!latest) return null;

    const heads = new Map<string, number>();
    for (const unitHeads of latest.heads) {
      for (const [head, count] of Object.entries(unitHeads)) heads.set(head, (heads.get(head) ?? 0) + count);
    }
    const previous = before && before.year === latest.year - 1 ? { year: before.year, total: before.total } : null;
    return {
      year: latest.year,
      total: latest.total,
      previous,
      changePercent: change(latest.total, previous?.total),
      top: [...heads.entries()]
        .filter(([, count]) => count > 0)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([head, count]) => ({ head, count })),
      units: latest.units,
      source: { name: 'NCRB, Crime in India', title: latest.title, url: latest.url },
    };
  }

  /** The newest edition's figures for a metropolitan city this district is part of. */
  private async cityFigures(districtId: number): Promise<AreaCrime['cityFigures']> {
    let rows: { city: string; year: number; total: number; rate: number | null; title: string; url: string }[];
    try {
      rows = (await this.db.query(
        `SELECT s.city, s.year, s.total, s.rate, e.title, e.url
         FROM crime_city_stats s JOIN crime_city_editions e ON e.edition = s.edition
         WHERE $1 = ANY(s.district_ids) AND s.edition = (SELECT max(edition) FROM crime_city_editions)
         ORDER BY s.year DESC`,
        [districtId],
      )) as typeof rows;
    } catch {
      return null;
    }
    const [latest] = rows;
    if (!latest) return null;
    const before = rows.find((r) => r.city === latest.city && r.year === latest.year - 1);
    return {
      city: latest.city,
      year: latest.year,
      total: latest.total,
      previous: before ? { year: before.year, total: before.total } : null,
      changePercent: change(latest.total, before?.total),
      ratePerLakh: latest.rate,
      source: { name: 'NCRB, Crime in India', title: latest.title, url: latest.url },
    };
  }
}
