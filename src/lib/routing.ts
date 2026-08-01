/** Traffic-aware routing: TomTom (realtime traffic) with OSRM free-flow fallback. */

export type LonLat = [number, number]; // GeoJSON order: [lng, lat]
export type RouteResult = {
  coordinates: LonLat[];
  distanceKm: number;
  durationMinutes: number;
  trafficDelayMinutes: number;
  provider: "tomtom-traffic" | "osrm";
};

const OSRM = "https://router.project-osrm.org";

function clampCoords(points: LonLat[]): LonLat[] {
  return points.filter(([lng, lat]) => Number.isFinite(lng) && Number.isFinite(lat) && Math.abs(lat) <= 90 && Math.abs(lng) <= 180);
}

/** TomTom Routing API with live traffic (travelMode truck). */
export async function routeWithTomTom(from: LonLat, to: LonLat, apiKey: string, signal?: AbortSignal): Promise<RouteResult> {
  // TomTom expects lat,lon path segments
  const path = `${from[1]},${from[0]}:${to[1]},${to[0]}`;
  const url =
    `https://api.tomtom.com/routing/1/calculateRoute/${path}/json` +
    `?key=${encodeURIComponent(apiKey)}` +
    `&traffic=true&travelMode=truck&routeType=fastest` +
    `&vehicleMaxSpeed=90&sectionType=traffic&computeBestOrder=false`;
  const res = await fetch(url, {signal, next: {revalidate: 0}});
  if (!res.ok) throw new Error(`TomTom routing ${res.status}`);
  const data = await res.json();
  const route = data?.routes?.[0];
  if (!route) throw new Error("TomTom: no route");
  const summary = route.summary || {};
  const legs = route.legs || [];
  const points: LonLat[] = [];
  for (const leg of legs) {
    for (const p of leg.points || []) {
      if (p?.longitude != null && p?.latitude != null) points.push([p.longitude, p.latitude]);
    }
  }
  if (points.length < 2) throw new Error("TomTom: empty geometry");
  const travelSec = Number(summary.travelTimeInSeconds || 0);
  const delaySec = Number(summary.trafficDelayInSeconds || 0);
  const lengthM = Number(summary.lengthInMeters || 0);
  return {
    coordinates: points,
    distanceKm: Math.round((lengthM / 1000) * 100) / 100,
    durationMinutes: Math.max(1, Math.round(travelSec / 60)),
    trafficDelayMinutes: Math.max(0, Math.round(delaySec / 60)),
    provider: "tomtom-traffic",
  };
}

/** OSRM free-flow (no live traffic) — last-resort fallback. */
export async function routeWithOsrm(from: LonLat, to: LonLat, signal?: AbortSignal): Promise<RouteResult> {
  const coords = clampCoords([from, to]);
  if (coords.length < 2) throw new Error("OSRM: invalid coordinates");
  // Snap endpoints to road network for better geometry
  const nearest = await Promise.all(
    coords.map(async (p) => {
      const r = await fetch(`${OSRM}/nearest/v1/driving/${p[0]},${p[1]}?number=1`, {signal});
      if (!r.ok) return p;
      const j = await r.json();
      return (j.waypoints?.[0]?.location as LonLat) || p;
    })
  );
  const r = await fetch(
    `${OSRM}/route/v1/driving/${nearest.map((p) => p.join(",")).join(";")}?overview=full&geometries=geojson&steps=false`,
    {signal}
  );
  if (!r.ok) throw new Error(`OSRM ${r.status}`);
  const j = await r.json();
  const route = j.routes?.[0];
  if (!route) throw new Error("OSRM: no route");
  return {
    coordinates: (route.geometry?.coordinates as LonLat[]) || nearest,
    distanceKm: Math.round((route.distance / 1000) * 100) / 100,
    durationMinutes: Math.max(1, Math.round(route.duration / 60)),
    trafficDelayMinutes: 0,
    provider: "osrm",
  };
}

/** Prefer TomTom traffic when key is set; otherwise OSRM. */
export async function calculateTrafficRoute(from: LonLat, to: LonLat, tomtomKey?: string | null, signal?: AbortSignal): Promise<RouteResult> {
  const a = clampCoords([from])[0];
  const b = clampCoords([to])[0];
  if (!a || !b) throw new Error("Invalid from/to");
  // Same-point short circuit
  const distM = haversineMeters(a, b);
  if (distM < 40) {
    return {coordinates: [a, b], distanceKm: 0.04, durationMinutes: 1, trafficDelayMinutes: 0, provider: tomtomKey ? "tomtom-traffic" : "osrm"};
  }
  if (tomtomKey) {
    try {
      return await routeWithTomTom(a, b, tomtomKey, signal);
    } catch {
      // fall through to OSRM
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
