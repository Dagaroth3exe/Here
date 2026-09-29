/**
 * Matching NCRB's police units ("Gautambudh Nagar", "Lucknow Commissionarate",
 * "Mumbai Commr.") to map districts ("Gautam Buddha Nagar", "Lucknow",
 * "Mumbai"). Names are spelt differently, big cities are split into city and
 * rural police, and some units aren't places at all (railway police, crime
 * branch). Anything not matched confidently is left out rather than guessed.
 */

/** Lowercase letters only, diacritics and punctuation gone: "Mahārāshtra" → "maharashtra". */
export function normalize(name: string): string {
  return name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/&/g, 'and')
    .replace(/[^a-z]/g, '');
}

/** Words that say what kind of police unit it is, not where. */
const UNIT_WORDS =
  /\b(commissionerate|commissionarate|commisionerate|commissioner|commr|pc|police|district|dist|city|urban|rural|grameen|gramin|dehat|outer)\b\.?/gi;

/** Rural/district police — they belong to an "X Rural" district when the state has one. */
const RURAL_UNIT = /\b(rural|district|grameen|gramin|dehat)\b/i;

/** "Lucknow Commissionarate" / "Lucknow Grameen" → "lucknow". */
export function core(name: string): string {
  return normalize(name.replace(UNIT_WORDS, ' '));
}

/** States as both sources spell them ("NCT of Delhi", "Jammu & Kashmīr"). */
export function normalizeState(name: string): string {
  return normalize(name.replace(/\b(nct|the|of)\b/gi, ' '));
}

/** Units that aren't areas of the map: railway police, crime branch, cells, etc. */
const NON_GEOGRAPHIC =
  /\b(grp|rly|crime|eow|cid|stf|spl cell|special cell|cell|vigilance|metro|airport|spuwac|cyber|economic offences|ats|total|other units|irrigation)\b|railway/i;

/**
 * Official renames the map data predates (it has "Gurgaon", NCRB "Gurugram").
 * Keyed by state, since some old names live on elsewhere — Chhattisgarh
 * still has a Bijapur; Karnataka's is now Vijayapura. Normalised names.
 */
const RENAMED: Record<string, Record<string, string>> = {
  haryana: { gurgaon: 'gurugram', mewat: 'nuh' },
  gujarat: { ahmadabad: 'ahmedabad' },
  karnataka: {
    bangalore: 'bengaluru',
    bangalorerural: 'bengalururural',
    belgaum: 'belagavi',
    bellary: 'ballari',
    bijapur: 'vijayapura',
    gulbarga: 'kalaburagi',
    mysore: 'mysuru',
  },
  uttarpradesh: {
    allahabad: 'prayagraj',
    faizabad: 'ayodhya',
    budaun: 'badaun',
    kheri: 'khiri',
    raebareli: 'raibareilly',
    farrukhabad: 'fatehgarh',
    mahamayanagar: 'hathras',
    kanshiramnagar: 'kasganj',
    jyotibaphulenagar: 'amroha',
    santravidasnagarbhadohi: 'bhadohi',
  },
  maharashtra: { ahmadnagar: 'ahmednagar', bid: 'beed' },
  westbengal: { haora: 'howrah', hugli: 'hooghly', kochbihar: 'coochbehar', barddhaman: 'purbabardhaman' },
  tamilnadu: { tiruchirappalli: 'trichy' },
  telangana: { bhadradri: 'bhadradrikothagudem', komarambheem: 'kumarambheemasifabad' },
};

/** A map district's name as NCRB would write it today. */
function districtKey(district: string, state: string): string {
  const name = normalize(district);
  return RENAMED[normalizeState(state)]?.[name] ?? name;
}

export function isGeographicUnit(name: string): boolean {
  return !NON_GEOGRAPHIC.test(name);
}

/** Jaro–Winkler similarity, 0–1. */
export function jaroWinkler(a: string, b: string): number {
  if (a === b) return 1;
  if (!a.length || !b.length) return 0;
  const window = Math.max(0, Math.floor(Math.max(a.length, b.length) / 2) - 1);
  const aHit = Array.from({ length: a.length }, () => false);
  const bHit = Array.from({ length: b.length }, () => false);
  let matches = 0;
  for (let i = 0; i < a.length; i++) {
    for (let j = Math.max(0, i - window); j < Math.min(b.length, i + window + 1); j++) {
      if (bHit[j] || a[i] !== b[j]) continue;
      aHit[i] = bHit[j] = true;
      matches++;
      break;
    }
  }
  if (!matches) return 0;
  let transpositions = 0;
  for (let i = 0, j = 0; i < a.length; i++) {
    if (!aHit[i]) continue;
    while (!bHit[j]) j++;
    if (a[i] !== b[j]) transpositions++;
    j++;
  }
  const jaro = (matches / a.length + matches / b.length + (matches - transpositions / 2) / matches) / 3;
  let prefix = 0;
  while (prefix < 4 && a[prefix] === b[prefix]) prefix++;
  return jaro + prefix * 0.1 * (1 - jaro);
}

/** The best-scoring candidate, only if it's good enough and clearly ahead of the runner-up. */
function best<T>(candidates: T[], score: (c: T) => number, min: number): T | null {
  let top: T | null = null;
  let topScore = -1;
  let second = -1;
  for (const c of candidates) {
    const s = score(c);
    if (s > topScore) {
      second = topScore;
      topScore = s;
      top = c;
    } else if (s > second) {
      second = s;
    }
  }
  return top !== null && topScore >= min && topScore - second >= 0.02 ? top : null;
}

/**
 * For one state: which of its NCRB units belong to each map district. First
 * whole names (so "Kanpur Dehat" finds the Kanpur Dehat district), then —
 * for units still unplaced — names with the unit words stripped (so
 * "Lucknow Commissionarate" and "Lucknow Grameen" both land on Lucknow).
 */
export function matchUnits(districts: string[], units: string[], state = ''): Map<string, string[]> {
  const result = new Map<string, string[]>();
  const place = (district: string, unit: string) => result.set(district, [...(result.get(district) ?? []), unit]);
  const key = new Map(districts.map((d) => [d, districtKey(d, state)]));
  const left: string[] = [];
  for (const unit of units.filter(isGeographicUnit)) {
    const hit = best(districts, (d) => jaroWinkler(normalize(unit), key.get(d)!), 0.93);
    if (hit) place(hit, unit);
    else left.push(unit);
  }
  // Only the unit side is stripped: map districts are real place names, and
  // "Kanpur Dehat" (a district of its own) must stay distinct from Kanpur.
  // A district already matched by its exact name is a slightly worse
  // candidate, which breaks the tie between Kanpur Nagar and Kanpur Dehat.
  const exact = new Set(result.keys());
  for (const unit of left) {
    const rural = RURAL_UNIT.test(unit) ? districts.find((d) => key.get(d) === `${core(unit)}rural`) : undefined;
    const hit = rural ?? best(districts, (d) => jaroWinkler(core(unit), key.get(d)!) - (exact.has(d) ? 0.05 : 0), 0.9);
    if (hit) place(hit, unit);
  }
  return result;
}

/**
 * Which map districts an NCRB metropolitan city lies in: the district that
 * shares its name (renames included), districts starting with it ("Mumbai"
 * and "Mumbai Suburban"), or — for a city that is its own state, like
 * Delhi — every district of that state.
 */
/** Cities whose district is named differently (Kochi lies in Ernakulam). */
const CITY_DISTRICT: Record<string, Record<string, string>> = {
  kerala: { kochi: 'ernakulam' },
};

export function districtsForCity(city: string, state: string, districts: string[]): string[] {
  const name = CITY_DISTRICT[normalizeState(state)]?.[core(city)] ?? core(city);
  if (name === normalizeState(state)) return [...districts];
  return districts.filter((d) => {
    const key = districtKey(d, state);
    // "Bangalore Rural" / "Kanpur Dehat" are districts of their own outside
    // the city police's area; "Mumbai Suburban" is inside it.
    if (/(rural|dehat|grameen|gramin)$/.test(key)) return false;
    return key === name || key.startsWith(name) || jaroWinkler(key, name) >= 0.95;
  });
}
