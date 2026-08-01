import {createServerClient} from "@supabase/ssr";
import {createClient} from "@supabase/supabase-js";
import {cookies} from "next/headers";
import {NextResponse} from "next/server";
import {calculateTrafficRoute,etaFromNow,resolveEndpoints,type LonLat} from "@/lib/routing";

export const dynamic = "force-dynamic";
export const maxDuration = 60;

type RouteRow = {
  id: string;
  order_id: string;
  geometry: {coordinates?: LonLat[]} | null;
  orders:
    | {id: string; status: string; vehicle_id: string | null; eta: string | null}
    | {id: string; status: string; vehicle_id: string | null; eta: string | null}[]
    | null;
};

function orderOf(row: RouteRow) {
  return Array.isArray(row.orders) ? row.orders[0] : row.orders;
}

async function authorize(request: Request) {
  const cronSecret = process.env.CRON_SECRET;
  const auth = request.headers.get("authorization") || "";
  // Vercel Cron: Authorization Bearer CRON_SECRET and/or x-vercel-cron header
  if (cronSecret && auth === `Bearer ${cronSecret}`) return {mode: "cron" as const};
  if (request.headers.get("x-vercel-cron") === "1") return {mode: "cron" as const};

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) return null;
  const store = await cookies();
  const supabase = createServerClient(url, anon, {
    cookies: {
      getAll: () => store.getAll(),
      setAll: () => {},
    },
  });
  const {data: {user}} = await supabase.auth.getUser();
  if (!user) return null;
  return {mode: "user" as const, userId: user.id};
}

export async function POST(request: Request) {
  return refresh(request);
}

/** Vercel Cron uses GET by default. */
export async function GET(request: Request) {
  return refresh(request);
}

async function refresh(request: Request) {
  const auth = await authorize(request);
  if (!auth) return NextResponse.json({success: false, error: "Unauthorized"}, {status: 401});

  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const service = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !service) {
    return NextResponse.json({success: false, error: "Supabase service role belum dikonfigurasi"}, {status: 503});
  }

  const tomtomKey = process.env.NEXT_PUBLIC_TOMTOM_API_KEY || process.env.TOMTOM_API_KEY || null;
  const admin = createClient(url, service, {auth: {persistSession: false}});

  const {data: routes, error} = await admin
    .from("routes")
    .select("id,order_id,geometry,orders!inner(id,status,vehicle_id,eta)")
    .in("orders.status", ["assigned", "pickup", "in_transit"]);

  if (error) return NextResponse.json({success: false, error: error.message}, {status: 500});

  const rows = (routes || []) as unknown as RouteRow[];
  const vehicleIds = [...new Set(rows.map((r) => orderOf(r)?.vehicle_id).filter(Boolean))] as string[];
  const {data: vehicles} = vehicleIds.length
    ? await admin.from("vehicles").select("id,last_lat,last_lng,status").in("id", vehicleIds)
    : {data: [] as {id: string; last_lat: number | null; last_lng: number | null; status: string}[]};
  const vehicleMap = new Map((vehicles || []).map((v) => [v.id, v]));

  const results: {
    route_id: string;
    order_id: string;
    provider: string;
    distance_km: number;
    duration_minutes: number;
    traffic_delay_minutes: number;
    eta: string;
  }[] = [];
  const failures: {route_id: string; reason: string}[] = [];

  // Sequential with small delay to respect public API rate limits
  for (const row of rows) {
    const order = orderOf(row);
    if (!order) {
      failures.push({route_id: row.id, reason: "order missing"});
      continue;
    }
    const vehicle = order.vehicle_id ? vehicleMap.get(order.vehicle_id) : null;
    const ends = resolveEndpoints(row.geometry, vehicle ? {lng: vehicle.last_lng, lat: vehicle.last_lat} : null);
    if (!ends) {
      failures.push({route_id: row.id, reason: "geometry incomplete"});
      continue;
    }

    try {
      const calculated = await calculateTrafficRoute(ends.from, ends.to, tomtomKey);
      const eta = etaFromNow(calculated.durationMinutes);
      const geometry = {type: "LineString", coordinates: calculated.coordinates};
      const provider =
        calculated.provider === "tomtom-traffic"
          ? `tomtom-traffic+delay${calculated.trafficDelayMinutes}m`
          : "osrm-freeflow";

      const [{error: routeErr}, {error: orderErr}] = await Promise.all([
        admin
          .from("routes")
          .update({
            geometry,
            distance_km: calculated.distanceKm,
            duration_minutes: calculated.durationMinutes,
            route_provider: provider,
          })
          .eq("id", row.id),
        admin.from("orders").update({eta, updated_at: new Date().toISOString()}).eq("id", order.id),
      ]);

      if (routeErr || orderErr) {
        failures.push({route_id: row.id, reason: routeErr?.message || orderErr?.message || "update failed"});
        continue;
      }

      results.push({
        route_id: row.id,
        order_id: order.id,
        provider: calculated.provider,
        distance_km: calculated.distanceKm,
        duration_minutes: calculated.durationMinutes,
        traffic_delay_minutes: calculated.trafficDelayMinutes,
        eta,
      });

      // gentle throttle between external routing calls
      await new Promise((r) => setTimeout(r, 120));
    } catch (e) {
      failures.push({route_id: row.id, reason: e instanceof Error ? e.message : "routing failed"});
    }
  }

  if (auth.mode === "user") {
    await admin.from("audit_logs").insert({
      actor_id: auth.userId,
      action: "routes.traffic_refresh",
      entity_type: "routes",
      metadata: {
        refreshed: results.length,
        failed: failures.length,
        provider: tomtomKey ? "tomtom-traffic" : "osrm",
        interval_minutes: 5,
      },
    });
  }

  return NextResponse.json({
    success: true,
    refreshed_at: new Date().toISOString(),
    provider_preference: tomtomKey ? "tomtom-traffic" : "osrm",
    refreshed: results.length,
    failed: failures.length,
    results,
    failures,
  });
}
