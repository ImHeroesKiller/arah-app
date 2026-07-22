"use client";
import {useEffect,useMemo,useRef,useState} from "react";
import Map,{Layer,Marker,NavigationControl,Source,type MapRef} from "react-map-gl/maplibre";
import {Flag,MapPin,Navigation} from "lucide-react";
import "maplibre-gl/dist/maplibre-gl.css";

type Coordinate=[number,number];
type LiveVehicle={id:string;plate_number:string;status:string;last_lat:number|null;last_lng:number|null;last_gps_at:string|null};
type LiveRoute={id:string;vehicle_id:string|null;status?:string|null;eta?:string|null;geometry:{coordinates?:Coordinate[]}|null};
type RouteItem={id:string;vehicleId:string;color:string;progress:number;points:Coordinate[]};

async function roadRoute(points:Coordinate[],signal:AbortSignal){
 const anchors=points.length>2?[points[0],points[Math.floor(points.length/2)],points[points.length-1]]:points;
 const nearest=await Promise.all(anchors.map(async p=>{const r=await fetch(`https://router.project-osrm.org/nearest/v1/driving/${p[0]},${p[1]}?number=1`,{signal});if(!r.ok)throw new Error("nearest");const j=await r.json();return (j.waypoints?.[0]?.location||p) as Coordinate}));
 const r=await fetch(`https://router.project-osrm.org/route/v1/driving/${nearest.map(p=>p.join(",")).join(";")}?overview=full&geometries=geojson&steps=false`,{signal});if(!r.ok)throw new Error("route");const j=await r.json();return (j.routes?.[0]?.geometry?.coordinates||nearest) as Coordinate[];
}
function colorFor(route:LiveRoute,vehicle?:LiveVehicle){
 if(!vehicle||!["assigned","pickup","in_transit"].includes(route.status||"")||!["assigned","pickup","in_transit"].includes(vehicle.status))return "#9aa7b8";
 if(!route.eta)return "#35d49a";const remaining=(new Date(route.eta).getTime()-Date.now())/60000;
 return remaining < -10?"#ff5f67":remaining<25?"#f6c85f":"#35d49a";
}
function pointAt(points:Coordinate[],progress:number){const lengths:number[]=[];let total=0;for(let i=1;i<points.length;i++){const l=Math.hypot(points[i][0]-points[i-1][0],points[i][1]-points[i-1][1]);lengths.push(l);total+=l}let target=progress*total,index=0;while(index<lengths.length-1&&target>lengths[index])target-=lengths[index++];const a=points[index],b=points[index+1]||a,f=lengths[index]?target/lengths[index]:0;return{lng:a[0]+(b[0]-a[0])*f,lat:a[1]+(b[1]-a[1])*f,angle:Math.atan2(b[1]-a[1],b[0]-a[0])*180/Math.PI}}

export default function FleetMap({focusedIds,onSelect,vehicles=[],liveRoutes=[],traffic=true,motion=true,resetToken=0}:{focusedIds:string[];onSelect:(id:string)=>void;vehicles?:LiveVehicle[];liveRoutes?:LiveRoute[];traffic?:boolean;motion?:boolean;resetToken?:number}){
 const mapRef=useRef<MapRef>(null),[tick,setTick]=useState(0),[snapped,setSnapped]=useState<Record<string,Coordinate[]>>({}),[routing,setRouting]=useState<"loading"|"ready"|"fallback">("loading");
 useEffect(()=>{if(!motion)return;const t=window.setInterval(()=>setTick(v=>v+1),80);return()=>clearInterval(t)},[motion]);
 useEffect(()=>{const controller=new AbortController();Promise.all(liveRoutes.map(async r=>[r.id,await roadRoute(r.geometry?.coordinates||[],controller.signal)] as const)).then(rows=>{setSnapped(Object.fromEntries(rows));setRouting("ready")}).catch(()=>setRouting("fallback"));return()=>controller.abort()},[liveRoutes]);
 const routes=useMemo<RouteItem[]>(()=>liveRoutes.flatMap((r,i)=>{const vehicle=vehicles.find(v=>v.id===r.vehicle_id),points=snapped[r.id]||r.geometry?.coordinates;if(!vehicle||!points||points.length<2)return[];return[{id:vehicle.plate_number,vehicleId:vehicle.id,color:colorFor(r,vehicle),progress:(i*.071)%1,points}]}),[liveRoutes,vehicles,snapped]);
 const visibleRoutes=routes.filter(r=>!focusedIds.length||focusedIds.includes(r.vehicleId));
 const visibleVehicles=vehicles.filter(v=>v.last_lat!=null&&v.last_lng!=null&&(!focusedIds.length||focusedIds.includes(v.id)));
 const data={type:"FeatureCollection" as const,features:visibleRoutes.map(r=>({type:"Feature" as const,properties:{color:r.color},geometry:{type:"LineString" as const,coordinates:r.points}}))};
 useEffect(()=>{const map=mapRef.current;if(!map||!focusedIds.length||!visibleVehicles.length)return;const points=visibleVehicles.map(v=>[v.last_lng!,v.last_lat!] as Coordinate);if(points.length===1)map.flyTo({center:points[0],zoom:14,duration:700});else map.fitBounds([[Math.min(...points.map(p=>p[0])),Math.min(...points.map(p=>p[1]))],[Math.max(...points.map(p=>p[0])),Math.max(...points.map(p=>p[1]))]],{padding:110,maxZoom:14,duration:700})},[focusedIds,visibleVehicles]);
 useEffect(()=>{mapRef.current?.flyTo({center:[106.84,-6.21],zoom:9.45,duration:700})},[resetToken]);
 return <div className="fullscreen-map"><Map ref={mapRef} initialViewState={{longitude:106.84,latitude:-6.21,zoom:9.45}} mapStyle="https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json" attributionControl={false} reuseMaps><NavigationControl position="bottom-right"/>
  <Source id="routes" type="geojson" data={data}><Layer id="route-halo" type="line" layout={{"line-cap":"round","line-join":"round"}} paint={{"line-color":["get","color"],"line-width":10,"line-opacity":.14}}/><Layer id="route-main" type="line" layout={{"line-cap":"round","line-join":"round"}} paint={{"line-color":["get","color"],"line-width":4,"line-opacity":.9}}/></Source>
  {traffic&&process.env.NEXT_PUBLIC_TOMTOM_API_KEY&&<Source id="tomtom-traffic" type="raster" tiles={[`https://api.tomtom.com/traffic/map/4/tile/flow/relative0/{z}/{x}/{y}.png?tileSize=512&key=${process.env.NEXT_PUBLIC_TOMTOM_API_KEY}`]} tileSize={512}><Layer id="traffic-flow" type="raster" paint={{"raster-opacity":.72}}/></Source>}
  {visibleRoutes.map((r,i)=>{const vehicle=vehicles.find(v=>v.id===r.vehicleId),moving=vehicle?.status==="in_transit",p=pointAt(r.points,moving?(r.progress+tick*.00012*(1+(i%5)*.04))%1:r.progress),start=r.points[0],end=r.points[r.points.length-1];return <span key={r.vehicleId}><Marker longitude={start[0]} latitude={start[1]}><div className="endpoint-pin origin" title="Titik asal"><MapPin/></div></Marker><Marker longitude={end[0]} latitude={end[1]}><div className="endpoint-pin destination" title="Titik tujuan"><Flag/></div></Marker><Marker longitude={p.lng} latitude={p.lat}><button className={focusedIds.includes(r.vehicleId)?"vehicle-pin selected live":"vehicle-pin live"} style={{"--pin":r.color} as React.CSSProperties} onClick={()=>onSelect(r.vehicleId)} title={`${moving?"Dalam pengantaran":"Posisi terakhir"} · ${vehicle?.last_gps_at||"Demo"}`}><Navigation style={{transform:`rotate(${90-p.angle}deg)`}}/><span>{r.id} · {moving?"BERJALAN":"GPS"}</span></button></Marker></span>})}
  {visibleVehicles.filter(v=>!visibleRoutes.some(r=>r.vehicleId===v.id)).map(v=><Marker key={v.id} longitude={v.last_lng!} latitude={v.last_lat!}><button className={focusedIds.includes(v.id)?"vehicle-pin selected live":"vehicle-pin live"} style={{"--pin":"#9aa7b8"} as React.CSSProperties} onClick={()=>onSelect(v.id)}><Navigation/><span>{v.plate_number} · {v.status.toUpperCase()}</span></button></Marker>)}
 </Map><div className={`routing-state ${routing}`}>{routing==="loading"?"OSRM SNAPPING…":routing==="ready"?`${routes.length} OSRM ROAD-SNAPPED ROUTES`:"OSRM FALLBACK"}</div><div className="map-legend"><span className="green">Lancar / sesuai ETA</span><span className="yellow">Tersendat / mendekati ETA</span><span className="red">Macet / terlambat</span><span className="silver">Idle / tanpa order</span></div></div>
}
