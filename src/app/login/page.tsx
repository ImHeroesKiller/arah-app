"use client";

import Image from "next/image";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { Eye, EyeOff, LockKeyhole, Mail, ShieldCheck } from "lucide-react";
import { getSupabaseBrowserClient } from "@/lib/supabase";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("admin@arah.id");
  const [password, setPassword] = useState("demo1234");
  const [show, setShow] = useState(false);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  async function submit(event: React.FormEvent) {
    event.preventDefault(); setLoading(true); setMessage("");
    const supabase = getSupabaseBrowserClient();
    if (supabase) {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error && email !== "admin@arah.id") { setMessage(error.message); setLoading(false); return; }
    }
    window.localStorage.setItem("arah-demo-session", "active");
    router.push("/");
  }

  return <main className="auth-page">
    <section className="auth-visual"><div className="grid-glow"/><div className="auth-brand"><Image src="/arah-logo-light.webp" width={98} height={98} alt="ARAH" priority/><span>FLEET INTELLIGENCE PLATFORM</span></div><div className="auth-copy"><small>OPERATIONAL CONTROL, SIMPLIFIED</small><h1>Satu pusat kendali.<br/><em>Seluruh operasi terlihat.</em></h1><p>Pantau armada, order, dana operasional, dan issue lapangan secara real-time.</p></div><div className="auth-trust"><ShieldCheck/><span><b>Enterprise security</b><small>Protected access & audit trail</small></span></div></section>
    <section className="auth-form-wrap"><form className="auth-form" onSubmit={submit}><div className="mobile-auth-logo"><Image src="/arah-logo-light.webp" width={70} height={70} alt="ARAH"/></div><p>ARAH COMMAND CENTER</p><h2>Selamat datang kembali</h2><span>Masuk menggunakan akun operasional Anda.</span><label>Email<div><Mail/><input type="email" value={email} onChange={e=>setEmail(e.target.value)} required/></div></label><label>Kata sandi<div><LockKeyhole/><input type={show?"text":"password"} value={password} onChange={e=>setPassword(e.target.value)} required/><button type="button" onClick={()=>setShow(!show)}>{show?<EyeOff/>:<Eye/>}</button></div></label><div className="auth-options"><label><input type="checkbox" defaultChecked/> Ingat saya</label><button type="button">Lupa kata sandi?</button></div>{message&&<div className="auth-error">{message}</div>}<button className="login-button" disabled={loading}>{loading?"Memverifikasi…":"Masuk ke Command Center"}</button><small className="demo-hint">Demo: admin@arah.id / demo1234</small></form></section>
  </main>;
}
