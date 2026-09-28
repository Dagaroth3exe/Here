/**
 * Reading NCRB's "District-wise Number of … Crimes" CSV (Crime in India,
 * table 1.1, as published on data.gov.in). Columns are found by what their
 * headers say rather than by position, so a later year with an extra column
 * — or the switch from IPC to BNS sections — doesn't silently shift numbers.
 */

/** Crime heads shown in the app, and how to recognise each one's column. */
export const CRIME_HEADS: Record<string, (header: string) => boolean> = {
  murder: (h) => /\bmurder\b/.test(h) && !/attempt|kidnapping|dacoity|culpable/.test(h),
  hurt: (h) => h.includes('hurt (total)'),
  womenAssault: (h) => h.includes('outrage') && h.includes('(total)'),
  rape: (h) => /- rape \(/.test(h),
  kidnapping: (h) => h.includes('kidnapping and abduction (total)'),
  theft: (h) => /\btheft\b/.test(h) && h.includes('(total)'),
  burglary: (h) => h.includes('burglary') && h.includes('(total)'),
  robbery: (h) => /\brobbery \(/.test(h),
  fraud: (h) => h.includes('cheating') && h.includes('fraud') && h.includes('(total)'),
};

const isTotal = (h: string) => h.includes('total cognizable');

export interface DistrictRow {
  state: string;
  unit: string;
  total: number;
  heads: Record<string, number>;
}

/** RFC 4180-ish: quoted fields, doubled quotes, commas and newlines inside quotes. */
export function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let field = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {
        field += '"';
        i++;
      } else if (c === '"') quoted = false;
      else field += c;
    } else if (c === '"') quoted = true;
    else if (c === ',') {
      row.push(field);
      field = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(field);
      rows.push(row);
      row = [];
      field = '';
    } else field += c;
  }
  if (field || row.length) {
    row.push(field);
    rows.push(row);
  }
  return rows.filter((r) => r.some((f) => f.trim()));
}

const number = (s: string | undefined) => {
  const n = Number((s ?? '').replace(/,/g, '').trim());
  return Number.isFinite(n) ? n : 0;
};

/** Throws if the table doesn't look like a district table (no state/district/total columns). */
export function parseDistrictTable(csv: string): DistrictRow[] {
  const [header, ...body] = parseCsv(csv.replace(/^﻿/, ''));
  const h = header.map((x) => x.toLowerCase());
  const stateCol = h.findIndex((x) => x.startsWith('state'));
  const unitCol = h.findIndex((x) => x.startsWith('district'));
  const totalCol = h.findIndex(isTotal);
  if (stateCol < 0 || unitCol < 0 || totalCol < 0) {
    throw new Error("Not a district crime table (couldn't find state, district and total columns)");
  }
  const headCols = Object.entries(CRIME_HEADS)
    .map(([key, test]) => [key, h.findIndex(test)] as const)
    .filter(([, col]) => col >= 0);

  return body
    .filter((r) => r[stateCol]?.trim() && r[unitCol]?.trim() && !/^total/i.test(r[stateCol].trim()))
    .map((r) => ({
      state: r[stateCol].trim(),
      unit: r[unitCol].trim(),
      total: number(r[totalCol]),
      heads: Object.fromEntries(headCols.map(([key, col]) => [key, number(r[col])])),
    }));
}
