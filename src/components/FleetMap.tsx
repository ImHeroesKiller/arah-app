"use client";

import { useEffect, useMemo, useState } from "react";
import Map, { Layer, Marker, NavigationControl, Source } from "react-map-gl/maplibre";
import { Navigation } from "lucide-react";
import "maplibre-gl/dist/maplibre-gl.css";

type Coordinate = [number, number];

// Demo geometry follows the main road corridors. Replace coordinates/progress
// with GPS + routing-engine output when the telematics feed is connected.
const routes: { id: string; color: string; progress: number; points: Coordinate[] }[] = [
  { id: "B 9127 UYT", color: "#00d4e8", progress: .46, points: [[106.8701,-6.1049],[106.8788,-6.1106],[106.8896,-6.1198],[106.9026,-6.1324],[106.9169,-6.1457],[106.9298,-6.1588],[106.9449,-6.1741],[106.9633,-6.1934],[106.9829,-6.2119],[107.0037,-6.2321],[107.0258,-6.2495],[107.0492,-6.2678],[107.0788,-6.2858],[107.1114,-6.3001],[107.1474,-6.3074],[107.1698,-6.3098]] },
  { id: "B 8831 KXR", color: "#8b7cff", progress: .68, points: [[106.357,-6.216],[106.383,-6.210],[106.414,-6.205],[106.446,-6.200],[106.481,-6.196],[106.518,-6.193],[106.557,-6.188],[106.597,-6.181],[106.637,-6.174],[106.681,-6.167],[106.724,-6.159],[106.765,-6.151],[106.802,-6.143],[106.834,-6.128],[106.856,-6.113],[106.8701,-6.1049]] },
  { id: "B 9712 FQA", color: "#ff704f", progress: .31, points: [[106.959,-6.105],[106.938,-6.111],[106.918,-6.122],[106.899,-6.137],[106.879,-6.151],[106.855,-6.167],[106.834,-6.181],[106.810,-6.196],[106.786,-6.209],[106.761,-6.222],[106.739,-6.232],[106.721,-6.230],[106.704,-6.213],[106.691,-6.189],[106.679,-6.161],[106.663,-6.128]] },
  { id: "B 7465 TXV", color: "#35d49a", progress: .12, points: [[107.169,-6.310],[107.146,-6.314],[107.119,-6.319],[107.087,-6.324],[107.052,-6.330],[107.016,-6.333],[106.981,-6.329],[106.944,-6.320],[106.907,-6.309],[106.868,-6.297],[106.830,-6.284],[106.786,-6.270],[106.741,-6.255],[106.695,-6.239],[106.647,-6.225],[106.597,-6.216],[106.553,-6.211],[106.519,-6.208]] },
];

function pointAt(points: Coordinate[], progress: number) {
  const segment = progress * (points.length - 1);
  const index = Math.min(Math.floor(segment), points.length - 2);
  const fraction = segment - index;
  const current = points[index];
  const next = points[index + 1];
  return {
    lng: current[0] + (next[0] - current[0]) * fraction,
    lat: current[1] + (next[1] - current[1]) * fraction,
    angle: Math.atan2(next[1] - current[1], next[0] - current[0]) * 180 / Math.PI,
  };
}

export default function FleetMap({ selectedId, onSelect }: { selectedId: string; onSelect: (id: string) => void }) {
  const [tick, setTick] = useState(0);
  useEffect(() => { const timer = window.setInterval(() => setTick(value => value + 1), 90); return () => window.clearInterval(timer); }, []);
  const geojson = useMemo(() => ({ type: "FeatureCollection" as const, features: routes.map(route => ({ type: "Feature" as const, properties: { color: route.color }, geometry: { type: "LineString" as const, coordinates: route.points } })) }), []);

  return <div className="map-frame">
    <Map initialViewState={{ longitude: 106.82, latitude: -6.21, zoom: 9.15 }} mapStyle="https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json" attributionControl={false}>
      <NavigationControl position="bottom-right" />
      <Source id="road-routes" type="geojson" data={geojson} lineMetrics>
        <Layer id="route-glow" type="line" layout={{ "line-cap": "round", "line-join": "round" }} paint={{ "line-color": ["get", "color"], "line-width": 9, "line-opacity": .13 }} />
        <Layer id="route-base" type="line" layout={{ "line-cap": "round", "line-join": "round" }} paint={{ "line-color": ["get", "color"], "line-width": 2.5, "line-opacity": .65 }} />
        <Layer id="route-motion" type="line" layout={{ "line-cap": "round", "line-join": "round" }} paint={{ "line-color": "#ffffff", "line-width": 2, "line-opacity": .55 + Math.abs(Math.sin(tick / 7)) * .4, "line-dasharray": (tick % 14) < 7 ? [1.2, 2.6] : [2.6, 1.2] }} />
      </Source>
      {routes.map((route, index) => {
        const progress = (route.progress + tick * .00022 * (1 + index * .08)) % 1;
        const position = pointAt(route.points, progress);
        return <Marker key={route.id} longitude={position.lng} latitude={position.lat} anchor="center">
          <button onClick={() => onSelect(route.id)} aria-label={`Pilih kendaraan ${route.id}`} className={selectedId === route.id ? "truck-marker selected" : "truck-marker"} style={{ "--marker-color": route.color } as React.CSSProperties}>
            <Navigation style={{ transform: `rotate(${90 - position.angle}deg)` }} />
            <span>{route.id}</span>
          </button>
        </Marker>;
      })}
    </Map>
    <div className="map-chips"><span>JABODETABEK</span><span><i /> GPS DEMO · 4 UNIT</span></div>
    <div className="gps-note">SIMULASI GPS <b>LIVE</b></div>
  </div>;
}
