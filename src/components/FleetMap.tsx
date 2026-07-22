"use client";
import { useEffect, useMemo, useState } from "react";
import Map, { Layer, Marker, NavigationControl, Source } from "react-map-gl/maplibre";
import { Truck } from "lucide-react";
import "maplibre-gl/dist/maplibre-gl.css";

const routes = [
 {id:"B 9127 UYT", color:"#17c8e4", points:[[106.8706,-6.105],[106.938,-6.155],[107.065,-6.274],[107.162,-6.305]]},
 {id:"B 8831 KXR", color:"#8c7cff", points:[[106.354,-6.216],[106.52,-6.195],[106.73,-6.17],[106.87,-6.105]]},
 {id:"B 9712 FQA", color:"#ff774d", points:[[106.96,-6.105],[106.82,-6.17],[106.71,-6.24],[106.66,-6.125]]},
 {id:"B 7465 TXV", color:"#3ee0a1", points:[[107.16,-6.31],[107.03,-6.34],[106.83,-6.28],[106.52,-6.21]]},
];
export default function FleetMap({selectedId,onSelect}:{selectedId:string,onSelect:(id:string)=>void}) {
 const [tick,setTick]=useState(0);
 useEffect(()=>{const t=setInterval(()=>setTick(v=>(v+1)%1000),70);return()=>clearInterval(t)},[]);
 const geo=useMemo(()=>({type:"FeatureCollection" as const,features:routes.map(r=>({type:"Feature" as const,properties:{color:r.color},geometry:{type:"LineString" as const,coordinates:r.points}}))}),[]);
 return <div className="map-frame"><Map initialViewState={{longitude:106.81,latitude:-6.21,zoom:9.2}} mapStyle="https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json" attributionControl={false}><NavigationControl position="bottom-right"/><Source id="routes" type="geojson" data={geo}><Layer id="route-glow" type="line" paint={{"line-color":["get","color"],"line-width":8,"line-opacity":0.15}}/><Layer id="route" type="line" paint={{"line-color":["get","color"],"line-width":3,"line-opacity":0.9,"line-dasharray":[2,1]}}/></Source>{routes.map((r,idx)=>{const p=(tick/1000+idx*.21)%1;const seg=p*(r.points.length-1);const i=Math.min(Math.floor(seg),r.points.length-2);const f=seg-i;const lng=r.points[i][0]+(r.points[i+1][0]-r.points[i][0])*f;const lat=r.points[i][1]+(r.points[i+1][1]-r.points[i][1])*f;return <Marker key={r.id} longitude={lng} latitude={lat} anchor="center"><button onClick={()=>onSelect(r.id)} aria-label={r.id} className={selectedId===r.id?"truck-marker selected":"truck-marker"} style={{"--marker-color":r.color} as React.CSSProperties}><Truck/></button></Marker>})}</Map><div className="map-chips"><span>JABODETABEK</span><span><i/> 4 UNIT LIVE</span></div></div>
}
