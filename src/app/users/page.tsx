"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";
import { ArrowLeft, MoreHorizontal, Plus, Search, ShieldCheck, UserCheck, Users } from "lucide-react";

const seedUsers = [
  { name:"Ary Wibowo", email:"ary@arah.id", role:"Super Admin", scope:"Semua Area", status:"Aktif", last:"Baru saja" },
  { name:"Raka Pratama", email:"raka@arah.id", role:"Fleet Manager", scope:"Jabodetabek", status:"Aktif", last:"12 menit lalu" },
  { name:"Nadia Putri", email:"nadia@arah.id", role:"Finance Approver", scope:"Nasional", status:"Aktif", last:"1 jam lalu" },
  { name:"Teguh Saputra", email:"teguh@arah.id", role:"Dispatcher", scope:"Jakarta Utara", status:"Aktif", last:"Kemarin" },
  { name:"Sinta Larasati", email:"sinta@arah.id", role:"Viewer", scope:"Cikarang", status:"Diundang", last:"Belum masuk" },
];

export default function UsersPage(){
  const [query,setQuery]=useState(""); const [invite,setInvite]=useState(false);
  const rows=seedUsers.filter(user=>`${user.name} ${user.email} ${user.role}`.toLowerCase().includes(query.toLowerCase()));
  return <main className="management-page"><header className="management-topbar"><Link href="/" className="back-button"><ArrowLeft/></Link><Image src="/arah-logo-light.webp" width={44} height={44} alt="ARAH"/><div><b>ARAH</b><span>ACCESS MANAGEMENT</span></div><div className="management-profile">AW</div></header><section className="management-content"><div className="management-heading"><div><p>ADMINISTRATION / USER ACCESS</p><h1>Pengguna & Akses</h1><span>Kelola akun, peran, dan cakupan akses operasional.</span></div><button onClick={()=>setInvite(true)}><Plus/> Tambah Pengguna</button></div><div className="access-stats"><article><Users/><div><span>Total pengguna</span><b>24</b></div></article><article><UserCheck/><div><span>Aktif hari ini</span><b>18</b></div></article><article><ShieldCheck/><div><span>Administrator</span><b>3</b></div></article></div><section className="users-panel"><div className="users-toolbar"><label><Search/><input placeholder="Cari nama, email, atau peran…" value={query} onChange={e=>setQuery(e.target.value)}/></label><select><option>Semua peran</option><option>Administrator</option><option>Operasional</option><option>Viewer</option></select></div><div className="table-wrap"><table className="users-table"><thead><tr><th>Pengguna</th><th>Peran</th><th>Cakupan Akses</th><th>Status</th><th>Aktivitas Terakhir</th><th/></tr></thead><tbody>{rows.map(user=><tr key={user.email}><td><div className="user-cell"><i>{user.name.split(" ").map(x=>x[0]).slice(0,2).join("")}</i><span><b>{user.name}</b><small>{user.email}</small></span></div></td><td>{user.role}</td><td>{user.scope}</td><td><span className={`user-status ${user.status.toLowerCase()}`}>{user.status}</span></td><td>{user.last}</td><td><button className="row-more"><MoreHorizontal/></button></td></tr>)}</tbody></table></div></section></section>{invite&&<div className="modal-backdrop" onClick={()=>setInvite(false)}><form className="invite-modal" onClick={e=>e.stopPropagation()}><p>AKSES BARU</p><h2>Undang pengguna</h2><label>Nama lengkap<input placeholder="Nama pengguna"/></label><label>Email<input type="email" placeholder="nama@perusahaan.com"/></label><label>Peran<select><option>Viewer</option><option>Dispatcher</option><option>Fleet Manager</option><option>Finance Approver</option><option>Super Admin</option></select></label><div><button type="button" className="cancel" onClick={()=>setInvite(false)}>Batal</button><button type="button" className="send" onClick={()=>setInvite(false)}>Kirim Undangan</button></div></form></div>}</main>;
}
