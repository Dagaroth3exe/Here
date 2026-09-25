/**
 * The outside world Ask HERE reads from: the self-hosted SearXNG metasearch,
 * the pages it finds, and OpenStreetMap (Nominatim for area names, Overpass
 * for places). Everything here is untrusted input — callers must treat it as
 * data, never instructions.
 */

const USER_AGENT = 'HERE-app/0.1 (Ask HERE; self-hosted)';

export interface WebResult {
  title: string;
  url: string;
  snippet: string;
}

export interface Place {
  name: string;
  kind: string;
  distanceM: number;
  lat: number;
  lng: number;
}

async function fetchWithTimeout(url: string, ms: number, init: RequestInit = {}): Promise<Response> {
  return fetch(url, {
    ...init,
    headers: { 'User-Agent': USER_AGENT, ...init.headers },
    signal: AbortSignal.timeout(ms),
  });
}

export async function searchWeb(searxngUrl: string, query: string, limit: number): Promise<WebResult[]> {
  const url = `${searxngUrl}/search?${new URLSearchParams({ q: query, format: 'json' })}`;
  const response = await fetchWithTimeout(url, 12_000);
  if (!response.ok) throw new Error(`SearXNG responded ${response.status}`);
  const data = (await response.json()) as { results?: { title?: string; url?: string; content?: string }[] };
  return (data.results ?? [])
    .filter((r) => r.url && r.title)
    .slice(0, limit)
    .map((r) => ({ title: r.title!, url: r.url!, snippet: r.content ?? '' }));
}

/** Readable text of a page, or '' if it can't be fetched quickly. */
export async function fetchPageText(url: string, maxChars: number): Promise<string> {
  try {
    const response = await fetchWithTimeout(url, 5_000, { headers: { Accept: 'text/html' } });
    const type = response.headers.get('content-type') ?? '';
    if (!response.ok || !type.includes('text/html')) return '';
    return htmlToText(await response.text()).slice(0, maxChars);
  } catch {
    return '';
  }
}

/** Plain text from HTML (pages, Stack Exchange answer bodies). */
export function htmlToText(html: string): string {
  return html
    .replace(/<(script|style|noscript|svg|nav|footer|header)[\s\S]*?<\/\1>/gi, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

const areaCache = new Map<string, string | null>();

/** "Sector 125, Noida"-style name for a position, via OSM Nominatim. */
export async function areaName(lat: number, lng: number): Promise<string | null> {
  // ~1 km cells, so moving around a neighbourhood doesn't re-query
  // (Nominatim's public instance allows one request per second).
  const key = `${lat.toFixed(2)},${lng.toFixed(2)}`;
  if (areaCache.has(key)) return areaCache.get(key)!;
  try {
    const url = `https://nominatim.openstreetmap.org/reverse?${new URLSearchParams({
      format: 'jsonv2',
      lat: String(lat),
      lon: String(lng),
      // Street level: coarser zooms skip locality names like Noida's
      // "Sector 125", which OSM often only has on the road itself.
      zoom: '17',
    })}`;
    const response = await fetchWithTimeout(url, 5_000);
    const data = (await response.json()) as { address?: Record<string, string> };
    const a = data.address ?? {};
    const city = a.city ?? a.town ?? a.county ?? a.state_district;
    const localityRoad = /\b(sector|block|phase)\b/i.test(a.road ?? '') ? a.road!.split(',')[0] : undefined;
    const local = a.suburb ?? a.neighbourhood ?? a.quarter ?? localityRoad ?? a.village ?? a.hamlet;
    const name = [local, city].filter(Boolean).join(', ') || null;
    areaCache.set(key, name);
    return name;
  } catch {
    return null;
  }
}

/**
 * What the planner can ask OpenStreetMap for. Each kind is a description the
 * model picks from (it also maps Hindi/Hinglish like "ghar ka samaan") and
 * the Overpass tag filters behind it — a fixed list, so model output can
 * never reach the query itself.
 */
export const PLACE_KINDS = {
  food: { about: 'restaurants, dhabas, fast food', filters: ['["amenity"~"^(restaurant|fast_food|food_court)$"]'] },
  cafe: { about: 'cafes, coffee, tea', filters: ['["amenity"="cafe"]'] },
  drinks: { about: 'bars, pubs', filters: ['["amenity"~"^(bar|pub|biergarten)$"]'] },
  grocery: {
    about: 'groceries, kirana, supermarket, vegetables',
    filters: ['["shop"~"^(supermarket|convenience|greengrocer|grocery|general|dairy)$"]'],
  },
  household: {
    about: 'household goods (ghar ka samaan), utensils, kitchenware, hardware, general/department stores',
    filters: ['["shop"~"^(houseware|hardware|doityourself|variety_store|department_store|general|kitchen|household_linen)$"]'],
  },
  electronics: {
    about: 'electronics, mobile phones, appliances, computers',
    filters: ['["shop"~"^(electronics|mobile_phone|computer|appliance)$"]'],
  },
  clothes: { about: 'clothes, shoes, tailors', filters: ['["shop"~"^(clothes|fashion|shoes|tailor|boutique)$"]'] },
  furniture: { about: 'furniture', filters: ['["shop"~"^(furniture|bed|interior_decoration)$"]'] },
  stationery: { about: 'stationery, books, photocopy/print shops', filters: ['["shop"~"^(stationery|books|copyshop)$"]'] },
  salon: { about: 'salons, barbers, beauty parlours', filters: ['["shop"~"^(hairdresser|beauty)$"]'] },
  pharmacy: { about: 'pharmacy, chemist, medical store', filters: ['["amenity"="pharmacy"]', '["shop"="chemist"]'] },
  medical: { about: 'hospitals, clinics, doctors', filters: ['["amenity"~"^(hospital|clinic|doctors)$"]'] },
  atm: { about: 'ATMs, banks', filters: ['["amenity"~"^(atm|bank)$"]'] },
  park: { about: 'parks, gardens', filters: ['["leisure"~"^(park|garden)$"]'] },
  gym: { about: 'gyms, sports centres', filters: ['["leisure"~"^(fitness_centre|sports_centre)$"]'] },
  stay: { about: 'hotels, guest houses, hostels, PGs', filters: ['["tourism"~"^(hotel|guest_house|hostel)$"]'] },
  mall: { about: 'malls, shopping centres', filters: ['["shop"="mall"]'] },
  transit: { about: 'metro and railway stations', filters: ['["railway"~"^(station|subway_entrance)$"]'] },
} as const satisfies Record<string, { about: string; filters: readonly string[] }>;

export type PlaceKind = keyof typeof PLACE_KINDS;

/** Readable names for OSM tag values that don't read well as-is. */
const TYPE_LABELS: Record<string, string> = {
  doityourself: 'hardware & home store',
  houseware: 'household goods',
  variety_store: 'variety store',
  general: 'general store',
  convenience: 'convenience store',
  greengrocer: 'fruits & vegetables',
  mobile_phone: 'mobile phones',
  copyshop: 'print & photocopy',
  hairdresser: 'salon',
  beauty: 'beauty parlour',
  fast_food: 'fast food',
  food_court: 'food court',
  fitness_centre: 'gym',
  guest_house: 'guest house',
  subway_entrance: 'metro entrance',
  household_linen: 'home linen',
  interior_decoration: 'home decor',
};

/** How far out to look, in order — the first ring with enough places wins. */
export const SEARCH_RINGS_M = [1000, 1500, 2000, 3000, 5000] as const;
/** A ring is "enough" once it holds this many places. */
const ENOUGH_PLACES = 3;
const MAX_PLACES = 10;

export interface ClosestPlaces {
  /** The ring everything shown falls inside — never a mix of rings. */
  radiusM: number;
  places: Place[];
}

/**
 * The genuinely closest places: within 1 km if there are enough, otherwise
 * widening step by step (1.5, 2, 3, 5 km). Only the smallest sufficient ring
 * is returned, so "nearest" never mixes a 300 m result with a 3 km one.
 * At most two Overpass queries (2 km, then 5 km if needed); the rings are
 * cut locally from those.
 */
export async function closestPlaces(kind: PlaceKind, lat: number, lng: number): Promise<ClosestPlaces | null> {
  let found: Place[] = [];
  for (const queryRadius of [2000, 5000]) {
    found = await placesWithin(kind, lat, lng, queryRadius);
    const ring = pickRing(found, queryRadius);
    if (ring) return ring;
  }
  return found.length > 0 ? pickRing(found, 5000, true) : null;
}

/** The smallest ring (up to maxRadius) holding enough places, or null. */
export function pickRing(places: Place[], maxRadius: number, acceptFewer = false): ClosestPlaces | null {
  const sorted = [...places].sort((a, b) => a.distanceM - b.distanceM);
  for (const radiusM of SEARCH_RINGS_M.filter((r) => r <= maxRadius)) {
    const inside = sorted.filter((p) => p.distanceM <= radiusM);
    const last = radiusM === maxRadius;
    if (inside.length >= ENOUGH_PLACES || (last && acceptFewer && inside.length > 0)) {
      return { radiusM, places: inside.slice(0, MAX_PLACES) };
    }
  }
  return null;
}

async function placesWithin(kind: PlaceKind, lat: number, lng: number, radiusM: number): Promise<Place[]> {
  const around = `(around:${radiusM},${lat},${lng})`;
  const union = PLACE_KINDS[kind].filters.map((f) => `nwr${f}["name"]${around};`).join('');
  const response = await overpass(`[out:json][timeout:7];(${union});out center 300;`);
  const data = (await response.json()) as {
    elements: { lat?: number; lon?: number; center?: { lat: number; lon: number }; tags: Record<string, string> }[];
  };
  return data.elements
    .map((e) => {
      const pLat = e.lat ?? e.center?.lat;
      const pLng = e.lon ?? e.center?.lon;
      if (pLat === undefined || pLng === undefined) return null;
      const t = e.tags;
      const tag = t.shop ?? t.amenity ?? t.leisure ?? t.tourism ?? t.railway ?? '';
      const type = TYPE_LABELS[tag] ?? tag.replace(/_/g, ' ');
      return {
        name: t.name,
        kind: t.cuisine ? `${type} (${t.cuisine.replace(/;/g, ', ')})` : type,
        lat: pLat,
        lng: pLng,
        distanceM: Math.round(distanceM(lat, lng, pLat, pLng)),
      };
    })
    .filter((p): p is Place => p !== null);
}

/**
 * Coordinates for a place named in the question ("in Vaishali"), preferring
 * matches within ~50 km of the asker so the right Vaishali wins.
 */
export async function geocode(name: string, near: { lat: number; lng: number } | null): Promise<{ lat: number; lng: number; label: string } | null> {
  const attempt = async (q: string, bounded: boolean) => {
    const params = new URLSearchParams({ format: 'jsonv2', limit: '1', q, countrycodes: 'in' });
    if (near && bounded) {
      params.set('viewbox', `${near.lng - 0.5},${near.lat + 0.5},${near.lng + 0.5},${near.lat - 0.5}`);
      params.set('bounded', '1');
    }
    const response = await fetchWithTimeout(`https://nominatim.openstreetmap.org/search?${params}`, 6_000);
    const [hit] = (await response.json()) as { lat: string; lon: string; name?: string; display_name: string }[];
    return hit ? { lat: Number(hit.lat), lng: Number(hit.lon), label: hit.name || hit.display_name.split(',')[0] } : null;
  };
  // "Vaishali, Noida" fails when the model guessed the city wrong (it's in
  // Ghaziabad) — the bare name near the person usually finds the right one.
  const bare = name.split(',')[0].trim();
  try {
    return (
      (near ? await attempt(name, true) : null) ??
      (near && bare !== name ? await attempt(bare, true) : null) ??
      (await attempt(name, false))
    );
  } catch {
    return null;
  }
}

/**
 * The public Overpass instance is shared and often answers 504/429 under
 * load, then succeeds moments later — so one quick retry. (Self-hosting
 * Overpass removes this for production.)
 */
async function overpass(query: string): Promise<Response> {
  let lastError: unknown;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const response = await fetchWithTimeout('https://overpass-api.de/api/interpreter', 7_000, {
        method: 'POST',
        body: new URLSearchParams({ data: query }),
      });
      if (response.ok) return response;
      lastError = new Error(`Overpass responded ${response.status}`);
    } catch (error) {
      lastError = error;
    }
  }
  throw lastError;
}

function distanceM(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const rad = Math.PI / 180;
  const dLat = (lat2 - lat1) * rad;
  const dLng = (lng2 - lng1) * rad;
  const h = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6_371_000 * Math.asin(Math.sqrt(h));
}
