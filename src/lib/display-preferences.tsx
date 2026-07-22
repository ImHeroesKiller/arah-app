"use client";
import {createContext,useContext,useState} from "react";

export type Language="id"|"en";
export type DisplayPreferences={language:Language;windowOpacity:number;fontScale:number;contrast:"normal"|"high";motion:boolean;traffic:boolean};
export const defaultDisplayPreferences:DisplayPreferences={language:"id",windowOpacity:94,fontScale:115,contrast:"normal",motion:true,traffic:true};
const defaults=defaultDisplayPreferences;
const Context=createContext<{prefs:DisplayPreferences;setPrefs:(x:DisplayPreferences)=>void}>({prefs:defaults,setPrefs:()=>{}});

export function DisplayPreferencesProvider({children}:{children:React.ReactNode}){
 const [prefs,setState]=useState<DisplayPreferences>(()=>{if(typeof window==="undefined")return defaults;try{const saved=localStorage.getItem("arah-display");return saved?{...defaults,...JSON.parse(saved)}:defaults}catch{return defaults}});
 const setPrefs=(next:DisplayPreferences)=>{setState(next);localStorage.setItem("arah-display",JSON.stringify(next))};
 return <Context.Provider value={{prefs,setPrefs}}><div data-theme="arah" data-contrast={prefs.contrast} style={{"--window-opacity":`${prefs.windowOpacity/100}`,"--font-scale":`${prefs.fontScale/100}`} as React.CSSProperties}>{children}</div></Context.Provider>;
}
export const useDisplayPreferences=()=>useContext(Context);
export const copy={
 id:{settings:"Pengaturan",users:"Pengguna",logout:"Keluar",traffic:"Trafik",workspace:"Ruang Kerja",command:"Pusat Kendali",liveMap:"Peta Langsung",fleet:"Armada",drivers:"Pengemudi",orders:"Penanganan Order",funds:"Dana Operasional",issues:"Issue Lapangan",master:"Data Master"},
 en:{settings:"Settings",users:"Users",logout:"Sign out",traffic:"Traffic",workspace:"Workspace",command:"Command Center",liveMap:"Live Map",fleet:"Fleet",drivers:"Drivers",orders:"Order Handling",funds:"Operational Funds",issues:"Field Issues",master:"Master Data"}
} as const;
