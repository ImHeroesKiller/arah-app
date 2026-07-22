"use client";

import Image from "next/image";
import { useState, useSyncExternalStore } from "react";
import { useRouter } from "next/navigation";
import { Eye, EyeOff, LockKeyhole, Mail, ShieldCheck } from "lucide-react";
import { getSupabaseBrowserClient } from "@/lib/supabase";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [show, setShow] = useState(false);
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);

  const queryError = useSyncExternalStore(
    () => () => undefined,
    () => new URLSearchParams(window.location.search).get("error"),
    () => null,
  );
  const messages: Record<string, string> = {
    unregistered: "Akun Anda berhasil diautentikasi, tetapi belum terdaftar di ARAH. Hubungi administrator.",
    inactive: "Akun Anda sedang tidak aktif. Hubungi administrator.",
    suspended: "Akun Anda ditangguhkan. Hubungi administrator.",
    profile: "Profil akses tidak dapat diperiksa. Silakan coba lagi atau hubungi administrator.",
    config: "Konfigurasi layanan autentikasi belum tersedia.",
  };
  const visibleMessage = message || (queryError ? messages[queryError] ?? "Akses tidak dapat diproses. Silakan masuk kembali." : "");

  async function submit(event: React.FormEvent) {
    event.preventDefault(); setLoading(true); setMessage("");
    const supabase = getSupabaseBrowserClient();
    if (!supabase) { setMessage("Konfigurasi Supabase belum tersedia."); setLoading(false); return; }
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) { setMessage("Email atau kata sandi tidak valid."); setLoading(false); return; }
    if(data.user)await supabase.from("audit_logs").insert({actor_id:data.user.id,action:"auth.login",entity_type:"session",metadata:{method:"password"}});
    router.push("/");
  }

  return <main className="auth-page">
    <section className="auth-visual"><div className="grid-glow"/><div className="auth-brand"><Image src="/arah-logo.png" width={98} height={98} alt="ARAH" priority/><span>FLEET INTELLIGENCE PLATFORM</span></div><div className="auth-copy"><small>OPERATIONAL CONTROL, SIMPLIFIED</small><h1>Satu pusat kendali.<br/><em>Seluruh operasi terlihat.</em></h1><p>Pantau armada, order, dana operasional, dan issue lapangan secara real-time.</p></div><div className="auth-trust"><ShieldCheck/><span><b>Enterprise security</b><small>Protected access & audit trail</small></span></div></section>
    <section className="auth-form-wrap"><form className="auth-form" onSubmit={submit}><div className="mobile-auth-logo"><Image src="/arah-logo.png" width={70} height={70} alt="ARAH"/></div><p>ARAH COMMAND CENTER</p><h2>Selamat datang kembali</h2><span>Masuk menggunakan akun operasional Anda.</span><label>Email<div><Mail/><input type="email" value={email} onChange={e=>setEmail(e.target.value)} required/></div></label><label>Kata sandi<div><LockKeyhole/><input type={show?"text":"password"} value={password} onChange={e=>setPassword(e.target.value)} required/><button type="button" onClick={()=>setShow(!show)}>{show?<EyeOff/>:<Eye/>}</button></div></label><div className="auth-options"><label><input type="checkbox" defaultChecked/> Ingat saya</label><button type="button" onClick={async()=>{if(!email){setMessage("Masukkan email terlebih dahulu.");return}const sb=getSupabaseBrowserClient();if(!sb)return;const {error}=await sb.auth.resetPasswordForEmail(email,{redirectTo:`${location.origin}/login?reset=1`});setMessage(error?error.message:"Tautan pemulihan telah dikirim ke email Anda.")}}>Lupa kata sandi?</button></div>{visibleMessage&&<div className="auth-error" role="alert">{visibleMessage}</div>}<button className="login-button" disabled={loading}>{loading?"Memverifikasi…":"Masuk ke Command Center"}</button><small className="demo-hint">Gunakan akun yang terdaftar di ARAH.</small></form></section>
  </main>;
}
