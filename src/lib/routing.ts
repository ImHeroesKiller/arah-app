/** Traffic-aware routing: fastest path with toll preference (TomTom) + OSRM fallback. */

export type LonLat = [number, number]; // GeoJSON order: [lng, lat]
export type RouteResult = {
  coordinates: LonLat[];
  distanceKm: number;
  durationMinutes: number;
  trafficDelayMinutes: number;
  provider: "tomtom-traffic" | "osrm";
  usesToll?: boolean;
  score?: number;
};

const OSRM = "https://router.project-osrm.org";

function clampCoords(points: LonLat[]): LonLat[] {
  return points.filter(([lng, lat]) => Number.isFinite(lng) && Number.isFinite(lat) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180);
}

type TomTomRoute = {
  summary?: {
    travelTimeInSeconds?: number;
    trafficDelayInSeconds?: number;
    lengthInMeters?: number;
  };
  legs?: {points?: {latitude: number; longitude: number}[]}[];
  sections?: {sectionType?: string; startPointIndex?: number; endPointIndex?: number}[];
};

function geometryFromTomTom(route: TomTomRoute): LonLat[] {
  const points: LonLat[] = [];
  for (const leg of route.legs || []) {
    for (const p of leg.points || []) {
      if (p?.longitude != null && p?.latitude != null) points.push([p.longitude, p.latitude]);
    }
  }
  return points;
}

function tollMeters(route: TomTomRoute, lengthM: number): number {
  const sections = route.sections || [];
  const tollSections = sections.filter((s) => /toll/i.test(s.sectionType || ""));
  if (!tollSections.length) return 0;
  // Approximate: share of points covered by toll sections vs total length
  let tollPoints = 0;
  let totalPoints = 0;
  for (const leg of route.legs || []) totalPoints += (leg.points || []).length;
  for (const s of tollSections) {
    const a = s.startPointIndex ?? 0;
    const b = s.endPointIndex ?? a;
    tollPoints += Math.max(0, b - a + 1);
  }
  if (totalPoints <= 0) return lengthM * 0.35;
  return lengthM * Math.min(1, tollPoints / totalPoints);
}

/**
 * Score: lower is better.
 * Primary = travel time (fastest).
 * Bonus for toll usage so when times are close, prefer highways/toll corridors.
 * Penalty for large traffic delay.
 */
function scoreRoute(travelSec: number, delaySec: number, lengthM: number, tollM: number): number {
  const tollRatio = lengthM > 0 ? tollM / lengthM : 0;
  // Prefer toll: up to ~8% time credit when fully on toll corridor
  const tollBonusSec = travelSec * 0.08 * tollRatio;
  // Slight delay penalty already in travel time; add soft extra for heavy congestion
  const delayPenalty = delaySec * 0.15;
  return travelSec - tollBonusSec + delayPenalty;
}

function toResult(route: TomTomRoute): RouteResult {
  const summary = route.summary || {};
  const points = geometryFromTomTom(route);
  if (points.length < 2) throw new Error("TomTom: empty geometry");
  const travelSec = Number(summary.travelTimeInSeconds || 0);
  const delaySec = Number(summary.trafficDelayInSeconds || 0);
  const lengthM = Number(summary.lengthInMeters || 0);
  const tollM = tollMeters(route, lengthM);
  const score = scoreRoute(travelSec, delaySec, lengthM, tollM);
  return {
    coordinates: points,
    distanceKm: Math.round((lengthM / 1000) * 100) / 100,
    durationMinutes: Math.max(1, Math.round(travelSec / 60)),
    trafficDelayMinutes: Math.max(0, Math.round(delaySec / 60)),
    provider: "tomtom-traffic",
    usesToll: tollM > 200,
    score,
  };
}

/**
 * TomTom: fastest with traffic, allow toll roads, request alternatives,
 * then pick best score (time-first, toll-preferred).
 */
export async function routeWithTomTom(from: LonLat, to: LonLat, apiKey: string, signal?: AbortSignal): Promise<RouteResult> {
  const path = `${from[1]},${from[0]}:${to[1]},${to[0]}`;
  const params = new URLSearchParams({
    key: apiKey,
    traffic: "true",
    travelMode: "truck",
    routeType: "fastest",
    vehicleMaxSpeed: "90",
    vehicleCommercial: "true",
    // Do NOT avoid tollRoads — we prioritize them when ETA is competitive
    sectionType: "tollRoad",
    maxAlternatives: "3",
    computeBestOrder: "false",
    // Keep ferries avoided for truck logistics
    avoid: "ferries",
  });
  // Request traffic sections too (repeat param supported by TomTom)
  const url =
    `https://api.tomtom.com/routing/1/calculateRoute/${path}/json?${params.toString()}` +
    `&sectionType=traffic`;
  const res = await fetch(url, {signal, cache: "no-store"});
  if (!res.ok) throw new Error(`TomTom routing ${res.status}`);
  const data = await res.json();
  const routes = (data?.routes || []) as TomTomRoute[];
  if (!routes.length) throw new Error("TomTom: no route");

  const ranked = routes
    .map((r) => {
      try {
        return toResult(r);
      } catch {
        return null;
      }
    })
    .filter((r): r is RouteResult => !!r)
    .sort((a, b) => (a.score ?? 1e12) - (b.score ?? 1e12));

  if (!ranked.length) throw new Error("TomTom: no usable geometry");
  return ranked[0];
}

/** OSRM free-flow (no live traffic / no toll metadata) — last-resort fallback. */
export async function routeWithOsrm(from: LonLat, to: LonLat, signal?: AbortSignal): Promise<RouteResult> {
  const coords = clampCoords([from, to]);
  if (coords.length < 2) throw new Error("OSRM: invalid coordinates");
  const nearest = await Promise.all(
    coords.map(async (p) => {
      const r = await fetch(`${OSRM}/nearest/v1/driving/${p[0]},${p[1]}?number=1`, {signal});
      if (!r.ok) return p;
      const j = await r.json();
      return (j.waypoints?.[0]?.location as LonLat) || p;
    })
  );
  // overview=full fastest driving profile; OSRM prefers major roads which often align with toll corridors
  const r = await fetch(
    `${OSRM}/route/v1/driving/${nearest.map((p) => p.join(",")).join(";")}?overview=full&geometries=geojson&steps=false&alternatives=true`,
    {signal}
  );
  if (!r.ok) throw new Error(`OSRM ${r.status}`);
  const j = await r.json();
  const list = (j.routes || []) as {distance: number; duration: number; geometry?: {coordinates?: LonLat[]}}[];
  if (!list.length) throw new Error("OSRM: no route");
  // Pick shortest duration (fastest)
  const best = [...list].sort((a, b) => a.duration - b.duration)[0];
  return {
    coordinates: (best.geometry?.coordinates as LonLat[]) || nearest,
    distanceKm: Math.round((best.distance / 1000) * 100) / 100,
    durationMinutes: Math.max(1, Math.round(best.duration / 60)),
    trafficDelayMinutes: 0,
    provider: "osrm",
    usesToll: false,
  };
}

/** Prefer TomTom traffic+toll algorithm when key is set; otherwise OSRM fastest. */
export async function calculateTrafficRoute(from: LonLat, to: LonLat, tomtomKey?: string | null, signal?: AbortSignal): Promise<RouteResult> {
  const a = clampCoords([from])[0];
  const b = clampCoords([to])[0];
  if (!a || !b) throw new Error("Invalid from/to");
  const distM = haversineMeters(a, b);
  if (distM < 40) {
    return {
      coordinates: [a, b],
      distanceKm: 0.04,
      durationMinutes: 1,
      trafficDelayMinutes: 0,
      provider: tomtomKey ? "tomtom-traffic" : "osrm",
      usesToll: false,
    };
  }
  if (tomtomKey) {
    try {
      return await routeWithTomTom(a, b, tomtomKey, signal);
    } catch {
      // fall through
    }
  }
  return routeWithOsrm(a, b, signal);
}

export function haversineMeters(a: LonLat, b: LonLat): number {
  const rad = Math.PI / 180;
  const dLat = (b[1] - a[1]) * rad;
  const dLng = (b[0] - a[0]) * rad;
  const x =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a[1] * rad) * Math.cos(b[1] * rad) * Math.sin(dLng / 2) ** 2;
  return 6371000 * 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

/** Destination = last geometry point; origin = live GPS if available, else first remaining point. */
export function resolveEndpoints(
  geometry: {coordinates?: LonLat[]} | null | undefined,
  live?: {lng: number | null; lat: number | null} | null
): {from: LonLat; to: LonLat} | null {
  const coords = clampCoords(geometry?.coordinates || []);
  if (coords.length < 2) return null;
  const to = coords[coords.length - 1];
  const from: LonLat =
    live?.lng != null && live?.lat != null && Number.isFinite(live.lng) && Number.isFinite(live.lat)
      ? [live.lng, live.lat]
      : coords[0];
  return {from, to};
}

export function etaFromNow(durationMinutes: number): string {
  return new Date(Date.now() + durationMinutes * 60_000).toISOString();
}
