import type { Metadata } from "next";
import { Plus_Jakarta_Sans } from "next/font/google";
import "./globals.css";
import AuthGate from "@/components/AuthGate";
const jakarta=Plus_Jakarta_Sans({subsets:["latin"],variable:"--font-jakarta"});
export const metadata:Metadata={title:"ARAH Fleet System",description:"Fleet command center untuk visibilitas armada, optimasi rute, dan field clearance."};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="id"><body className={jakarta.variable}><AuthGate>{children}</AuthGate></body></html>}
