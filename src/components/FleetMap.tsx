"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import Map, { Layer, Marker, NavigationControl, Source, type MapRef } from "react-map-gl/maplibre";
import { Navigation } from "lucide-react";
import "maplibre-gl/dist/maplibre-gl.css";

type Coordinate=[number,number];
type RouteItem={id:string;vehicleId?:string;color:string;progress:number;waypoints:Coordinate[];points:Coordinate[]};
const seed:Omit<RouteItem,"points">[]=[
 {id:"B 9127 UYT",color:"#18c8de",progress:.46,waypoints:[[106.872,-6.105],[106.951,-6.188],[107.169,-6.310]]},
 {id:"B 8831 KXR",color:"#8c83ff",progress:.68,waypoints:[[106.519,-6.208],[106.695,-6.199],[106.870,-6.105]]},
 {id:"B 9712 FQA",color:"#ff6f61",progress:.31,waypoints:[[106.957,-6.105],[106.830,-6.180],[106.655,-6.126]]},
 {id:"B 7465 TXV",color:"#35d49a",progress:.12,waypoints:[[107.169,-6.310],[106.982,-6.330],[106.519,-6.208]]},
];

async function snap(point:Coordinate,signal:AbortSignal):Promise<Coordinate>{
 const res=await fetch(`https://router.project-osrm.org/nearest/v1/driving/${point[0]},${point[1]}?number=1`,{signal});
 if(!res.ok) throw new Error("nearest failed");
 const json=await res.json(); return json.waypoints?.[0]?.location||point;
}
async function roadRoute(route:Omit<RouteItem,"points">,signal:AbortSignal):Promise<RouteItem>{
 const snapped=await Promise.all(route.waypoints.map(p=>snap(p,signal)));
 const coords=snapped.map(p=>p.join(",")).join(";");
 const res=await fetch(`https://router.project-osrm.org/route/v1/driving/${coords}?overview=full&geometries=geojson&steps=false`,{signal});
 if(!res.ok) throw new Error("route failed"); const json=await res.json();
 return {...route,points:json.routes?.[0]?.geometry?.coordinates||snapped};
}
function pointAt(points:Coordinate[],progress:number){const lengths:number[]=[];let total=0;for(let i=1;i<points.length;i++){const dx=points[i][0]-points[i-1][0],dy=points[i][1]-points[i-1][1];const l=Math.hypot(dx,dy);lengths.push(l);total+=l}let target=progress*total,index=0;while(index<lengths.length-1&&target>lengths[index]){target-=lengths[index];index++}const a=points[index],b=points[index+1]||a,f=lengths[index]?target/lengths[index]:0;return{lng:a[0]+(b[0]-a[0])*f,lat:a[1]+(b[1]-a[1])*f,angle:Math.atan2(b[1]-a[1],b[0]-a[0])*180/Math.PI}}

type LiveVehicle={id:string;plate_number:string;status:string;last_lat:number|null;last_lng:number|null;last_gps_at:string|null};
type LiveRoute={id:string;vehicle_id:string|null;geometry:{coordinates?:Coordinate[]}|null};
const colors=["#18c8de","#8c83ff","#ff6f61","#35d49a","#f6c85f","#ef6fff","#4da3ff"];
export default function FleetMap({focusedIds,onSelect,vehicles=[],liveRoutes=[],traffic=true}:{focusedIds:string[];onSelect:(id:string)=>void;vehicles?:LiveVehicle[];liveRoutes?:LiveRoute[];traffic?:boolean}){
 const mapRef=useRef<MapRef>(null);
 const [fallbackRoutes,setFallbackRoutes]=useState<RouteItem[]>(seed.map(r=>({...r,points:r.waypoints})));
 const [tick,setTick]=useState(0); const [routing,setRouting]=useState<"loading"|"ready"|"fallback">("loading");
 useEffect(()=>{if(liveRoutes.length)return;const controller=new AbortController();Promise.all(seed.map(r=>roadRoute(r,controller.signal))).then(x=>{setFallbackRoutes(x);setRouting("ready")}).catch(()=>setRouting("fallback"));return()=>controller.abort()},[liveRoutes.length]);
 useEffect(()=>{const t=window.setInterval(()=>setTick(v=>v+1),80);return()=>window.clearInterval(t)},[]);
 const routes=useMemo<RouteItem[]>(()=>liveRoutes.length?liveRoutes.flatMap((route,i)=>{const vehicle=vehicles.find(v=>v.id===route.vehicle_id),points=route.geometry?.coordinates;if(!vehicle||!points||points.length<2)return[];return [{id:vehicle.plate_number,vehicleId:vehicle.id,color:colors[i%colors.length],progress:(i*.071)%1,waypoints:points,points}]}):fallbackRoutes,[liveRoutes,vehicles,fallbackRoutes]);
 const data=useMemo(()=>({type:"FeatureCollection" as const,features:routes.map(r=>({type:"Feature" as const,properties:{color:r.color},geometry:{type:"LineString" as const,coordinates:r.points}}))}),[routes]);
 const visibleVehicles=useMemo(()=>vehicles.filter(v=>v.last_lat!=null&&v.last_lng!=null&&(focusedIds.length===0||focusedIds.includes(v.id))),[vehicles,focusedIds]);
 const visibleRoutes=useMemo(()=>routes.filter(r=>focusedIds.length===0||(r.vehicleId&&focusedIds.includes(r.vehicleId))),[routes,focusedIds]);
 const visibleData=useMemo(()=>({...data,features:data.features.filter(f=>visibleRoutes.some(r=>r.color===f.properties.color))}),[data,visibleRoutes]);
 useEffect(()=>{const map=mapRef.current;if(!map||focusedIds.length===0||visibleVehicles.length===0)return;const points=visibleVehicles.map(v=>[v.last_lng!,v.last_lat!] as Coordinate);if(points.length===1){map.flyTo({center:points[0],zoom:14,duration:700});return}const lngs=points.map(p=>p[0]),lats=points.map(p=>p[1]);map.fitBounds([[Math.min(...lngs),Math.min(...lats)],[Math.max(...lngs),Math.max(...lats)]],{padding:110,maxZoom:14,duration:700})},[focusedIds,visibleVehicles]);
 return <div className="fullscreen-map"><Map ref={mapRef} initialViewState={{longitude:106.84,latitude:-6.21,zoom:9.45}} mapStyle="https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json" attributionControl={false} reuseMaps>
  <NavigationControl position="bottom-right"/>
 <Source id="routes" type="geojson" data={visibleData} lineMetrics>
   <Layer id="route-halo" type="line" layout={{"line-cap":"round","line-join":"round"}} paint={{"line-color":["get","color"],"line-width":10,"line-opacity":.12}}/>
   <Layer id="route-main" type="line" layout={{"line-cap":"round","line-join":"round"}} paint={{"line-color":["get","color"],"line-width":3,"line-opacity":.82}}/>
   <Layer id="route-flow" type="line" layout={{"line-cap":"round","line-join":"round"}} paint={{"line-color":"#fff","line-width":1.5,"line-opacity":.25+Math.abs(Math.sin(tick/8))*.65,"line-dasharray":[1.2+(tick%8)/12,2.8]}}/>
  </Source>
  {traffic&&process.env.NEXT_PUBLIC_TOMTOM_API_KEY&&<Source id="tomtom-traffic" type="raster" tiles={[`https://api.tomtom.com/traffic/map/4/tile/flow/relative0/{z}/{x}/{y}.png?tileSize=512&key=${process.env.NEXT_PUBLIC_TOMTOM_API_KEY}`]} tileSize={512}><Layer id="traffic-flow" type="raster" paint={{"raster-opacity":.72}}/></Source>}
  {visibleRoutes.map((r,i)=>{const vehicle=vehicles.find(v=>v.id===r.vehicleId),moving=vehicle?.status==="in_transit",p=pointAt(r.points,moving?(r.progress+tick*.00012*(1+(i%5)*.04))%1:r.progress);return <Marker key={r.vehicleId||r.id} longitude={p.lng} latitude={p.lat}><button className={r.vehicleId&&focusedIds.includes(r.vehicleId)?"vehicle-pin selected live":"vehicle-pin live"} style={{"--pin":r.color} as React.CSSProperties} onClick={()=>r.vehicleId&&onSelect(r.vehicleId)} title={`${moving?"Dalam pengantaran":"Posisi terakhir"} · ${vehicle?.last_gps_at||"Demo"}`}><Navigation style={{transform:`rotate(${90-p.angle}deg)`}}/><span>{r.id} · {moving?"BERJALAN":"GPS"}</span></button></Marker>})}
  {visibleVehicles.filter(v=>!visibleRoutes.some(r=>r.vehicleId===v.id)).map(v=><Marker key={v.id} longitude={v.last_lng!} latitude={v.last_lat!}><button className={focusedIds.includes(v.id)?"vehicle-pin selected live":"vehicle-pin live"} style={{"--pin":"#8b98a9"} as React.CSSProperties} onClick={()=>onSelect(v.id)} title={`GPS ${v.last_gps_at||""}`}><Navigation/><span>{v.plate_number} · {v.status.toUpperCase()}</span></button></Marker>)}
 </Map><div className={`routing-state ${liveRoutes.length?"ready":routing}`}>{liveRoutes.length?"19 LIVE DELIVERY ROUTES":routing==="loading"?"OSRM SNAPPING…":routing==="ready"?"OSRM ROAD MATCHED":"ROUTING FALLBACK"}</div></div>
}
