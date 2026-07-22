import {createClient} from "@supabase/supabase-js";
import {createHash,timingSafeEqual} from "crypto";
import {NextResponse} from "next/server";

const digest=(value:string)=>createHash("sha256").update(value).digest("hex");

export async function POST(request:Request){
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!key)return NextResponse.json({error:"Server GPS belum dikonfigurasi"},{status:503});
  const deviceCode=request.headers.get("x-device-id")||"";
  const token=request.headers.get("x-device-token")||"";
  if(!deviceCode||!token)return NextResponse.json({error:"Device credential wajib diisi"},{status:401});
  const body=await request.json().catch(()=>null) as null|{latitude:number;longitude:number;speed_kph?:number;heading?:number;recorded_at?:string;fuel_percent?:number;odometer_km?:number};
  if(!body||!Number.isFinite(body.latitude)||!Number.isFinite(body.longitude)||Math.abs(body.latitude)>90||Math.abs(body.longitude)>180)
    return NextResponse.json({error:"Koordinat tidak valid"},{status:400});
  const admin=createClient(url,key,{auth:{persistSession:false}});
  const {data:device}=await admin.from("gps_devices").select("id,vehicle_id,token_hash,active").eq("device_code",deviceCode).maybeSingle();
  const supplied=digest(token),expected=device?.token_hash||"";
  const valid=device?.active&&supplied.length===expected.length&&timingSafeEqual(Buffer.from(supplied),Buffer.from(expected));
  if(!valid)return NextResponse.json({error:"Device credential tidak valid"},{status:401});
  const recordedAt=body.recorded_at||new Date().toISOString();
  const {error}=await admin.from("gps_positions").insert({vehicle_id:device.vehicle_id,latitude:body.latitude,longitude:body.longitude,speed_kph:body.speed_kph||0,heading:body.heading||0,recorded_at:recordedAt});
  if(error)return NextResponse.json({error:error.message},{status:500});
  await Promise.all([
    admin.from("gps_devices").update({last_seen_at:recordedAt}).eq("id",device.id),
    admin.from("vehicles").update({last_lat:body.latitude,last_lng:body.longitude,last_gps_at:recordedAt,...(body.fuel_percent!==undefined?{fuel_percent:body.fuel_percent}:{}),...(body.odometer_km!==undefined?{odometer_km:body.odometer_km}:{})}).eq("id",device.vehicle_id),
  ]);
  return NextResponse.json({accepted:true,vehicle_id:device.vehicle_id,recorded_at:recordedAt});
}
