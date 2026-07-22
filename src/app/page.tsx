"use client";

import dynamic from "next/dynamic";
import Image from "next/image";
import Link from "next/link";
import { useMemo, useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  Bell, Check, ChevronLeft, ChevronRight, CircleDollarSign, Clock3, Fuel,
  Gauge, LayoutDashboard, Map, Menu, PackageCheck, PanelLeftClose, Route,
  Search, Settings, ShieldCheck, Truck, Users, WalletCards, Wrench, X,
  AlertTriangle, Navigation, Radio, Maximize2, Minimize2, Layers3
} from "lucide-react";

const FleetMap = dynamic(() => import("@/components/FleetMap"), { ssr: false });

const fleet = [
  { id:"B 9127 UYT", driver:"Dimas Prakoso", type:"Wingbox", route:"Priok → Cikarang", status:"In Transit", speed:58, eta:"16:42", fuel:76 },
  { id:"B 8831 KXR", driver:"Rizky Maulana", type:"CDD Long", route:"Cikande → Priok", status:"In Transit", speed:46, eta:"17:18", fuel:64 },
  { id:"B 9712 FQA", driver:"Ari Saputra", type:"Trailer 40ft", route:"Marunda → Soetta", status:"Delayed", speed:18, eta:"18:05", fuel:42 },
  { id:"B 7465 TXV", driver:"Bayu Akbar", type:"Fuso", route:"Cikarang → Cikande", status:"Ready", speed:0, eta:"Ready", fuel:91 },
];

const nav = [
  [LayoutDashboard,"Command Center"], [Map,"Live Map"], [Truck,"Armada"],
  [PackageCheck,"Order Handling"], [WalletCards,"Dana Operasional"], [Wrench,"Issue Lapangan"],
] as const;

type Toast = { tone:"ok"|"info"; text:string } | null;

export default function Home() {
  const [active, setActive] = useState("Command Center");
  const [selected, setSelected] = useState(fleet[0]);
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [panelOpen, setPanelOpen] = useState(true);
  const [expanded, setExpanded] = useState(false);
  const [searchOpen, setSearchOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [approvals, setApprovals] = useState([true,true,true]);
  const [toast, setToast] = useState<Toast>(null);
  const rows = useMemo(()=>fleet.filter(x=>JSON.stringify(x).toLowerCase().includes(query.toLowerCase())),[query]);
  const notify=(text:string,tone:"ok"|"info"="ok")=>{setToast({text,tone});window.setTimeout(()=>setToast(null),2600)};
  const choose=(label:string)=>{setActive(label);setPanelOpen(true)};

  return <main className={`map-app ${sidebarOpen?"":"sidebar-collapsed"}`}>
    <div className="map-stage"><FleetMap selectedId={selected.id} onSelect={id=>{setSelected(fleet.find(x=>x.id===id)||fleet[0]);setPanelOpen(true)}} /></div>

    <header className="map-header">
      <button className="square-action mobile-only" onClick={()=>setSidebarOpen(v=>!v)} aria-label="Menu"><Menu/></button>
      <div className="map-brand"><Image src="/arah-logo-dark.webp" width={44} height={44} alt="ARAH"/><div><b>ARAH</b><span>FLEET COMMAND CENTER</span></div></div>
      <div className="live-status"><i/> LIVE OPERATIONS <span>JABODETABEK</span></div>
      <div className="header-actions">
        {searchOpen&&<label className="map-search"><Search/><input autoFocus value={query} onChange={e=>setQuery(e.target.value)} placeholder="Cari unit atau pengemudi"/></label>}
        <button className="square-action" onClick={()=>setSearchOpen(v=>!v)} aria-label="Cari"><Search/></button>
        <button className="square-action has-dot" onClick={()=>notify("Tidak ada notifikasi baru","info")} aria-label="Notifikasi"><Bell/></button>
        <Link className="avatar" href="/users" title="Pengguna & akses">AW</Link>
      </div>
    </header>

    <aside className="map-sidebar">
      <button className="sidebar-toggle" onClick={()=>setSidebarOpen(v=>!v)} aria-label="Collapse sidebar">{sidebarOpen?<PanelLeftClose/>:<ChevronRight/>}</button>
      <div className="nav-caption">WORKSPACE</div>
      {nav.map(([Icon,label])=><button key={label} className={active===label?"map-nav active":"map-nav"} onClick={()=>choose(label)} title={label}><Icon/><span>{label}</span></button>)}
      <div className="nav-spacer"/>
      <Link className="map-nav" href="/users" title="Pengguna"><Users/><span>Pengguna</span></Link>
      <button className="map-nav" onClick={()=>notify("Pengaturan sistem dibuka","info")}><Settings/><span>Pengaturan</span></button>
      <div className="system-mini"><Radio/><div><b>System Online</b><small>GPS demo · OSRM active</small></div></div>
    </aside>

    <section className="kpi-dock">
      <MiniKpi icon={Truck} label="Availability" value="87.5%" tone="green" onClick={()=>choose("Armada")}/>
      <MiniKpi icon={CircleDollarSign} label="Dana Operasional" value="Rp 286,4 Jt" tone="blue" onClick={()=>choose("Dana Operasional")}/>
      <MiniKpi icon={PackageCheck} label="Order Aktif" value="23" tone="cyan" onClick={()=>choose("Order Handling")}/>
      <MiniKpi icon={AlertTriangle} label="Issue Lapangan" value="7" tone="orange" onClick={()=>choose("Issue Lapangan")}/>
    </section>

    <AnimatePresence>
      {panelOpen&&<motion.section initial={{opacity:0,x:25}} animate={{opacity:1,x:0}} exit={{opacity:0,x:25}} className={`floating-window ${expanded?"expanded":""}`}>
        <div className="window-bar"><div><span>OPERATIONS / LIVE</span><h1>{active}</h1></div><div><button onClick={()=>setExpanded(v=>!v)}>{expanded?<Minimize2/>:<Maximize2/>}</button><button onClick={()=>setPanelOpen(false)}><X/></button></div></div>
        <DashboardContent active={active} rows={rows} selected={selected} setSelected={setSelected} approvals={approvals} setApprovals={setApprovals} notify={notify}/>
      </motion.section>}
    </AnimatePresence>
    {!panelOpen&&<button className="reopen-panel" onClick={()=>setPanelOpen(true)}><ChevronLeft/> Buka panel</button>}

    <div className="map-tools"><button onClick={()=>notify("Tampilan layer: traffic & kendaraan","info")}><Layers3/></button><button onClick={()=>notify("Map dipusatkan ke armada terpilih","info")}><Navigation/></button></div>
    <div className="provider-pill"><Route/> OSRM ROAD-SNAPPED <i/> GPS DEMO</div>
    {toast&&<div className={`action-toast ${toast.tone}`}><Check/>{toast.text}</div>}
  </main>
}

function DashboardContent({active,rows,selected,setSelected,approvals,setApprovals,notify}:{active:string;rows:typeof fleet;selected:typeof fleet[number];setSelected:(x:typeof fleet[number])=>void;approvals:boolean[];setApprovals:(x:boolean[])=>void;notify:(x:string,t?:"ok"|"info")=>void}) {
  if(active==="Armada"||active==="Live Map") return <div className="window-content"><SectionTitle title="Armada Aktif" sub="Pilih unit untuk memusatkan monitoring"/><FleetList rows={rows} selected={selected} setSelected={setSelected}/></div>;
  if(active==="Order Handling") return <div className="window-content"><SectionTitle title="Order Handling" sub="23 order aktif · SLA 96,2%"/><StatRows rows={[["ORD-260722-118","Priok → Cikarang","In Transit"],["ORD-260722-116","Cikande → Priok","In Transit"],["ORD-260722-109","Marunda → Soetta","Delayed"]]}/><button className="primary-wide" onClick={()=>notify("Form order baru siap digunakan","info")}>+ Buat order baru</button></div>;
  if(active==="Dana Operasional") return <div className="window-content"><SectionTitle title="Persetujuan Dana" sub="Permintaan clearance & perjalanan"/>{approvals.map((v,i)=>v&&<Approval key={i} i={i} setApprovals={setApprovals} approvals={approvals} notify={notify}/>) }{approvals.every(v=>!v)&&<div className="window-empty"><ShieldCheck/>Semua permintaan sudah diproses</div>}</div>;
  if(active==="Issue Lapangan") return <div className="window-content"><SectionTitle title="Operational Issues" sub="2 kritis · 5 dalam pemantauan"/><StatRows rows={[["Potensi keterlambatan","B 9712 FQA · Tol Dalam Kota","Kritis"],["Fuel level rendah","B 6231 WRY · 19% tersisa","Pantau"],["Maintenance due","B 8280 KLM · Service 5.000 km","Terjadwal"]]}/><button className="primary-wide" onClick={()=>notify("Form laporan issue dibuka","info")}>+ Laporkan issue</button></div>;
  return <div className="window-content"><SectionTitle title="Live Fleet Intelligence" sub="Ringkasan operasional saat ini"/><div className="selected-unit"><div><span>SELECTED VEHICLE</span><h2>{selected.id}</h2><small>{selected.type} · {selected.driver}</small></div><b>{selected.status}</b></div><div className="compact-metrics"><Metric icon={Gauge} label="Speed" value={`${selected.speed} km/h`}/><Metric icon={Fuel} label="Fuel" value={`${selected.fuel}%`}/><Metric icon={Clock3} label="ETA" value={selected.eta}/><Metric icon={ShieldCheck} label="Health" value="Good"/></div><SectionTitle title="Active Fleet Movement" sub="Pembaruan simulasi telematika"/><FleetList rows={rows} selected={selected} setSelected={setSelected}/></div>;
}

function MiniKpi({icon:Icon,label,value,tone,onClick}:{icon:typeof Truck;label:string;value:string;tone:string;onClick:()=>void}){return <button className={`mini-kpi ${tone}`} onClick={onClick}><Icon/><span><small>{label}</small><b>{value}</b></span><ChevronRight/></button>}
function SectionTitle({title,sub}:{title:string;sub:string}){return <div className="section-title"><div><h2>{title}</h2><p>{sub}</p></div><button>•••</button></div>}
function FleetList({rows,selected,setSelected}:{rows:typeof fleet;selected:typeof fleet[number];setSelected:(x:typeof fleet[number])=>void}){return <div className="fleet-list">{rows.map(x=><button key={x.id} onClick={()=>setSelected(x)} className={selected.id===x.id?"selected":""}><i className={x.status==="Delayed"?"delay":x.status==="Ready"?"ready":""}/><div><b>{x.id}</b><small>{x.driver} · {x.route}</small></div><span><b>{x.speed} km/h</b><small>ETA {x.eta}</small></span><ChevronRight/></button>)}</div>}
function Metric({icon:Icon,label,value}:{icon:typeof Gauge;label:string;value:string}){return <div><Icon/><span><small>{label}</small><b>{value}</b></span></div>}
function StatRows({rows}:{rows:string[][]}){return <div className="stat-rows">{rows.map(r=><button key={r[0]}><div><b>{r[0]}</b><small>{r[1]}</small></div><span>{r[2]}</span><ChevronRight/></button>)}</div>}
function Approval({i,setApprovals,approvals,notify}:{i:number;setApprovals:(x:boolean[])=>void;approvals:boolean[];notify:(x:string)=>void}){const data=[["Gate pass Tanjung Priok","Rp 1.850.000"],["Tol & BBM perjalanan","Rp 2.275.000"],["Overtime clearance Soetta","Rp 1.200.000"]][i];const act=(ok:boolean)=>{setApprovals(approvals.map((v,j)=>j===i?false:v));notify(ok?"Permintaan disetujui":"Permintaan ditolak")};return <div className="approval-mini"><div><b>{data[0]}</b><small>B 9127 UYT · 12 menit lalu</small><strong>{data[1]}</strong></div><button className="reject" onClick={()=>act(false)}><X/></button><button className="approve" onClick={()=>act(true)}><Check/></button></div>}
