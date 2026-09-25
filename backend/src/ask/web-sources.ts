/**
 * The outside world Ask HERE reads from: the self-hosted SearXNG metasearch
 * and OpenStreetMap (Nominatim for area names, Overpass for places). Everything here is untrusted input — callers must treat it as
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
 * What the planner can ask OpenStreetMap for — each an Overpass tag filter.
 * Kept to a fixed list so model output can't inject into the query.
 */
export const PLACE_KINDS = {
  food: '["amenity"~"^(restaurant|fast_food|food_court)$"]',
  cafe: '["amenity"="cafe"]',
  drinks: '["amenity"~"^(bar|pub|biergarten)$"]',
  medical: '["amenity"~"^(hospital|clinic|doctors|pharmacy)$"]',
  atm: '["amenity"~"^(atm|bank)$"]',
  park: '["leisure"~"^(park|garden)$"]',
  gym: '["leisure"~"^(fitness_centre|sports_centre)$"]',
  stay: '["tourism"~"^(hotel|guest_house|hostel)$"]',
  shopping: '["shop"~"^(mall|supermarket|department_store)$"]',
  transit: '["railway"~"^(station|subway_entrance)$"]',
} as const;

export type PlaceKind = keyof typeof PLACE_KINDS;

export async function nearbyPlaces(kind: PlaceKind, lat: number, lng: number, radiusM: number): Promise<Place[]> {
  const query = `[out:json][timeout:7];nwr${PLACE_KINDS[kind]}["name"](around:${radiusM},${lat},${lng});out center 40;`;
  const response = await overpass(query);
  const data = (await response.json()) as {
    elements: { lat?: number; lon?: number; center?: { lat: number; lon: number }; tags: Record<string, string> }[];
  };
  return data.elements
    .map((e) => {
      const pLat = e.lat ?? e.center?.lat;
      const pLng = e.lon ?? e.center?.lon;
      if (pLat === undefined || pLng === undefined) return null;
      const t = e.tags;
      const kindLabel = t.cuisine ? `${t.amenity ?? t.leisure ?? t.shop ?? ''} (${t.cuisine})` : (t.amenity ?? t.leisure ?? t.tourism ?? t.shop ?? t.railway ?? '');
      return { name: t.name, kind: kindLabel.replace(/_/g, ' '), lat: pLat, lng: pLng, distanceM: Math.round(distanceM(lat, lng, pLat, pLng)) };
    })
    .filter((p): p is Place => p !== null)
    .sort((a, b) => a.distanceM - b.distanceM)
    .slice(0, 12);
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
