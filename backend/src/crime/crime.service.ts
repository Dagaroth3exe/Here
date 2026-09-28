import { Injectable } from '@nestjs/common';
import { InjectDataSource } from '@nestjs/typeorm';
import { DataSource } from 'typeorm';

/** Official reported-crime figures for the district a point falls in. */
export interface DistrictCrime {
  district: string;
  state: string;
  year: number;
  /** All reported cognizable crimes (IPC/BNS) that year. */
  total: number;
  /** The year before, when both years are in. */
  previous: { year: number; total: number } | null;
  changePercent: number | null;
  /** The largest of the crime heads shown in the app, biggest first. */
  top: { head: string; count: number }[];
  /** The NCRB police units the figures add up (e.g. city + rural police). */
  units: string[];
  source: { name: string; title: string; url: string };
  boundaries: string;
}

@Injectable()
export class CrimeService {
  constructor(@InjectDataSource() private readonly db: DataSource) {}

  async forPoint(lat: number, lng: number): Promise<DistrictCrime | null> {
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

    const years = (await this.db.query(
      `SELECT ds.year, ds.title, ds.url, sum(s.total)::int AS total,
              json_agg(s.heads) AS heads, array_agg(s.unit ORDER BY s.unit) AS units
       FROM crime_unit_stats s JOIN crime_datasets ds ON ds.id = s.dataset_id
       WHERE s.district_id = $1
       GROUP BY ds.id ORDER BY ds.year DESC LIMIT 2`,
      [district.id],
    )) as { year: number; title: string; url: string; total: number; heads: Record<string, number>[]; units: string[] }[];
    const [latest, before] = years;
    if (!latest) return null;

    const heads = new Map<string, number>();
    for (const unitHeads of latest.heads) {
      for (const [head, count] of Object.entries(unitHeads)) heads.set(head, (heads.get(head) ?? 0) + count);
    }
    const previous = before && before.year === latest.year - 1 ? { year: before.year, total: before.total } : null;
    return {
      district: district.name,
      state: district.state,
      year: latest.year,
      total: latest.total,
      previous,
      changePercent:
        previous && previous.total > 0 ? Math.round(((latest.total - previous.total) / previous.total) * 1000) / 10 : null,
      top: [...heads.entries()]
        .filter(([, count]) => count > 0)
        .sort((a, b) => b[1] - a[1])
        .slice(0, 3)
        .map(([head, count]) => ({ head, count })),
      units: latest.units,
      source: { name: 'NCRB, Crime in India', title: latest.title, url: latest.url },
      boundaries: 'geoBoundaries (ODbL 1.0)',
    };
  }
}
