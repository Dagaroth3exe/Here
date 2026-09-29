/**
 * NCRB's metropolitan-city table (Crime in India, table 1B.1: "IPC/BNS Crimes
 * in Metropolitan Cities"): each big city's reported crimes for three years
 * and the latest crime rate. The newest report only goes down to these
 * cities — district tables stop at 2022.
 */

export interface CityRow {
  city: string;
  /** Null for "Delhi City", which is its own state. */
  state: string | null;
  totals: Record<number, number>;
  /** Crimes per lakh (100,000) people, for [rateYear]. */
  rate: number | null;
  rateYear: number | null;
}

const num = (s: string | undefined) => {
  const n = Number((s ?? '').replace(/,/g, '').trim());
  return (s ?? '').trim() !== '' && Number.isFinite(n) ? n : null;
};

/** Columns are found by their headers ("2022", "2024 Total (IPC+BNS)", "Rate of Cognizable Crimes (2024)"). */
export function parseCityTable(rows: string[][]): CityRow[] {
  const headerAt = rows.findIndex((r) => r.some((c) => /^\s*city\s*$/i.test(c)));
  if (headerAt < 0) throw new Error("Not a city crime table (no 'City' column)");
  const header = rows[headerAt];
  const cityCol = header.findIndex((c) => /^\s*city\s*$/i.test(c));

  const yearCols: [number, number][] = [];
  let rateCol = -1;
  let rateYear: number | null = null;
  header.forEach((h, i) => {
    const plain = /^\s*(\d{4})\s*$/.exec(h);
    const total = /(\d{4})\s*total/i.exec(h);
    const rate = /rate of cognizable crimes\s*\((\d{4})\)/i.exec(h);
    if (plain) yearCols.push([Number(plain[1]), i]);
    else if (total) yearCols.push([Number(total[1]), i]);
    if (rate) {
      rateCol = i;
      rateYear = Number(rate[1]);
    }
  });
  if (!yearCols.length) throw new Error('No year columns in city table');

  return rows
    .slice(headerAt + 1)
    .filter((r) => r[cityCol]?.trim() && !/^total/i.test(r[cityCol].trim()))
    .map((r) => {
      const label = r[cityCol].trim();
      const inState = /^(.*?)\s*\((.+)\)\s*$/.exec(label);
      const city = (inState?.[1] ?? label).replace(/\s+city$/i, '').trim();
      const totals: Record<number, number> = {};
      for (const [year, col] of yearCols) {
        const v = num(r[col]);
        if (v !== null) totals[year] = v;
      }
      return {
        city,
        state: inState?.[2] ?? null,
        totals,
        rate: rateCol >= 0 ? num(r[rateCol]) : null,
        rateYear: rateCol >= 0 ? rateYear : null,
      };
    })
    .filter((c) => Object.keys(c.totals).length > 0);
}
