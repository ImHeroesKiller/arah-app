"use client";

import dynamic from "next/dynamic";
import Image from "next/image";
import { useMemo, useState } from "react";
import { motion } from "framer-motion";
import {
  Bell, ChevronDown, Clock3, Gauge, LayoutDashboard,
  Map, Menu, PackageCheck, Search, Settings, ShieldCheck, Truck, Users,
  WalletCards, Wrench, Zap, ArrowUpRight, Check, X, Route, Fuel,
} from "lucide-react";

const FleetMap = dynamic(() => import("@/components/FleetMap"), { ssr: false, loading: () => <div className="map-loading">Menyiapkan live map…</div> });
const TruckScene = dynamic(() => import("@/components/TruckScene"), { ssr: false });

const fleet = [
  { id:"B 9127 UYT", driver:"Dimas Prakoso", type:"Wingbox", route:"Priok → Cikarang", status:"In Transit", speed:58, eta:"16:42", fuel:76 },
  { id:"B 8831 KXR", driver:"Rizky Maulana", type:"CDD Long", route:"Cikande → Priok", status:"In Transit", speed:46, eta:"17:18", fuel:64 },
  { id:"B 9712 FQA", driver:"Ari Saputra", type:"Trailer 40ft", route:"Marunda → Soetta", status:"Delayed", speed:18, eta:"18:05", fuel:42 },
  { id:"B 7465 TXV", driver:"Bayu Akbar", type:"Fuso", route:"Cikarang → Cikande", status:"Ready", speed:0, eta:"Ready", fuel:91 },
];

const nav = [
  [LayoutDashboard,"Command Center"], [Map,"Live Map"], [Truck,"Armada"],
  [PackageCheck,"Order & Booking"], [WalletCards,"Dana Operasional"], [Wrench,"Maintenance"],
];

export default function Home() {
  const [active, setActive] = useState("Command Center");
  const [selected, setSelected] = useState(fleet[0]);
  const [query, setQuery] = useState("");
  const [approvals, setApprovals] = useState([true,true,true]);
  const [mobileNav, setMobileNav] = useState(false);
  const rows = useMemo(() => fleet.filter(x => JSON.stringify(x).toLowerCase().includes(query.toLowerCase())), [query]);

  return <main className="app-shell">
    <header className="topbar">
      <button className="mobile-menu" onClick={() => setMobileNav(!mobileNav)} aria-label="Buka navigasi"><Menu/></button>
      <div className="brand"><Image src="/arah-logo.png" width={54} height={54} alt="ARAH Fleet System" priority/><div><b>ARAH</b><span>FLEET SYSTEM</span></div></div>
      <label className="search"><Search/><input value={query} onChange={e=>setQuery(e.target.value)} placeholder="Cari nopol, pengemudi, atau rute…"/></label>
      <div className="top-actions"><button className="icon-button" aria-label="Notifikasi"><Bell/><i/></button><div className="profile"><span>AW</span><div><b>Ary Wibowo</b><small>System Administrator</small></div><ChevronDown/></div></div>
    </header>

    <aside className={mobileNav ? "sidebar open" : "sidebar"}>
      <div className="nav-label">WORKSPACE</div>
      {nav.map(([Icon,label]) => { const I=Icon as typeof LayoutDashboard; const l=label as string; return <button key={l} onClick={()=>{setActive(l);setMobileNav(false)}} className={active===l?"nav-item active":"nav-item"}><I/><span>{l}</span></button>})}
      <div className="nav-label bottom">SYSTEM</div>
      <button className="nav-item"><Users/><span>Pengguna & Akses</span></button><button className="nav-item"><Settings/><span>Pengaturan</span></button>
      <div className="system-card"><div><Zap/><span>System status</span><i/></div><b>All systems operational</b><small>Terakhir diperbarui 1 menit lalu</small></div>
    </aside>

    <section className="workspace">
      <div className="page-heading"><div><p>CONTROL ROOM / <span>LIVE OVERVIEW</span></p><h1>{active}</h1><small>Selasa, 22 Juli 2026 · Operasional Jabodetabek</small></div><div className="live-pill"><i/> LIVE DATA <span>14:32:18 WIB</span></div></div>

      <section className="kpi-grid">
        <Kpi icon={Truck} label="Total Armada" value="48" note="36 sedang beroperasi" trend="+4.2%" tone="blue"/>
        <Kpi icon={Gauge} label="Utilisasi Armada" value="87.4%" note="Target bulanan 85%" trend="+2.4%" tone="cyan"/>
        <Kpi icon={PackageCheck} label="Pengiriman Aktif" value="23" note="8 tiba dalam < 2 jam" trend="3 prioritas" tone="orange"/>
        <Kpi icon={Clock3} label="On-Time Delivery" value="94.8%" note="142 pengiriman bulan ini" trend="+1.8%" tone="green"/>
      </section>

      <section className="command-grid">
        <div className="map-card panel">
          <div className="panel-head"><div><h2>Live Fleet Intelligence</h2><p>Pergerakan armada & optimasi rute secara real-time</p></div><div className="legend"><span><i className="green"/>Normal</span><span><i className="orange"/>Perhatian</span><span><i className="red"/>Delay</span></div></div>
          <FleetMap selectedId={selected.id} onSelect={id=>setSelected(fleet.find(x=>x.id===id) || fleet[0])}/>
          <div className="map-float"><Route/><div><small>ROUTE EFFICIENCY</small><b>92.6%</b></div><span>+3.1%</span></div>
        </div>

        <div className="side-column">
          <div className="panel vehicle-card"><div className="panel-head compact"><div><p>SELECTED VEHICLE</p><h2>{selected.id}</h2></div><button className="more">•••</button></div><div className="truck-scene"><TruckScene/></div><div className="vehicle-title"><div><span className="status-dot"/> {selected.status}</div><small>{selected.type} · {selected.driver}</small></div><div className="telemetry"><Metric icon={Gauge} label="Speed" value={`${selected.speed} km/h`}/><Metric icon={Fuel} label="Fuel" value={`${selected.fuel}%`}/><Metric icon={Clock3} label="ETA" value={selected.eta}/><Metric icon={ShieldCheck} label="Health" value="Good"/></div><button className="detail-button">Lihat detail kendaraan <ArrowUpRight/></button></div>
          <div className="panel alerts"><div className="panel-head compact"><div><h2>Operational Alerts</h2><p>Butuh perhatian Anda</p></div><span className="count">3</span></div><Alert tone="red" title="Potensi keterlambatan" text="B 9712 FQA · Tol Dalam Kota" time="2 menit"/><Alert tone="orange" title="Fuel level rendah" text="B 6231 WRY · 19% tersisa" time="8 menit"/><Alert tone="blue" title="Maintenance due" text="B 8280 KLM · Service 5.000 km" time="1 jam"/></div>
        </div>
      </section>

      <section className="bottom-grid">
        <div className="panel table-card"><div className="panel-head"><div><h2>Active Fleet Movement</h2><p>Pembaruan langsung dari perangkat telematika</p></div><button className="ghost">Lihat semua <ArrowUpRight/></button></div><div className="table-wrap"><table><thead><tr><th>Unit</th><th>Pengemudi</th><th>Rute</th><th>Status</th><th>Kecepatan</th><th>ETA</th></tr></thead><tbody>{rows.map(x=><tr key={x.id} onClick={()=>setSelected(x)} className={selected.id===x.id?"selected":""}><td><b>{x.id}</b><small>{x.type}</small></td><td>{x.driver}</td><td>{x.route}</td><td><span className={`badge ${x.status.toLowerCase().replace(" ","-")}`}>{x.status}</span></td><td>{x.speed} km/h</td><td>{x.eta}</td></tr>)}</tbody></table></div></div>
        <div className="panel approvals"><div className="panel-head compact"><div><h2>Persetujuan Dana</h2><p>Clearance & operasional</p></div><span className="count amber">{approvals.filter(Boolean).length}</span></div>{[
          ["Gate pass Tanjung Priok","B 9127 UYT","Rp 1.850.000"], ["Tol & BBM perjalanan","B 8831 KXR","Rp 2.275.000"], ["Overtime clearance Soetta","B 9712 FQA","Rp 1.200.000"]
        ].map((x,i)=>approvals[i]&&<div className="approval" key={x[0]}><div><b>{x[0]}</b><small>{x[1]} · diajukan 12 menit lalu</small><strong>{x[2]}</strong></div><div><button onClick={()=>setApprovals(a=>a.map((v,j)=>j===i?false:v))} className="reject"><X/></button><button onClick={()=>setApprovals(a=>a.map((v,j)=>j===i?false:v))} className="approve"><Check/></button></div></div>)}{approvals.every(x=>!x)&&<div className="empty"><ShieldCheck/><b>Semua sudah diproses</b></div>}<button className="detail-button">Buka pusat persetujuan <ArrowUpRight/></button></div>
      </section>
    </section>
  </main>
}

function Kpi({icon:Icon,label,value,note,trend,tone}:{icon:typeof Truck,label:string,value:string,note:string,trend:string,tone:string}) { return <motion.article initial={{opacity:0,y:12}} animate={{opacity:1,y:0}} className={`kpi panel ${tone}`}><div className="kpi-icon"><Icon/></div><div><p>{label}</p><h2>{value}</h2><small>{note}</small></div><span className="trend">{trend}</span></motion.article> }
function Metric({icon:Icon,label,value}:{icon:typeof Gauge,label:string,value:string}) { return <div><Icon/><span><small>{label}</small><b>{value}</b></span></div> }
function Alert({tone,title,text,time}:{tone:string,title:string,text:string,time:string}) { return <div className="alert-row"><i className={tone}/><div><b>{title}</b><small>{text}</small></div><time>{time}</time></div> }
