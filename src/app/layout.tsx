import type { Metadata } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import "./globals.css";
import "./milestone-two.css";
import AuthGate from "@/components/AuthGate";
const jakarta=Plus_Jakarta_Sans({subsets:["latin"],variable:"--font-jakarta"});
export const metadata:Metadata={title:"ARAH Fleet System",description:"Fleet command center untuk visibilitas armada, optimasi rute, dan field clearance.",icons:{icon:[{url:"/favicon.ico",sizes:"any"},{url:"/icon.png",type:"image/png",sizes:"512x512"}],apple:[{url:"/apple-icon.png",sizes:"180x180",type:"image/png"}],shortcut:"/favicon.ico"},manifest:"/manifest.webmanifest"};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="id"><body className={jakarta.variable}><AuthGate>{children}</AuthGate></body></html>}
