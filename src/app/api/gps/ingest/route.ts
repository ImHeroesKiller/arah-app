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
  const source=request.headers.get("x-telemetry-source")||"gps_device";
  if(!["android","gps_device","uwb"].includes(source))return NextResponse.json({error:"Sumber telemetry tidak didukung"},{status:400});
  const body=await request.json().catch(()=>null) as null|{latitude:number;longitude:number;speed_kph?:number;heading?:number;recorded_at?:string;fuel_percent?:number;odometer_km?:number;accuracy_m?:number;tag_id?:string;zone?:string};
  if(!body||!Number.isFinite(body.latitude)||!Number.isFinite(body.longitude)||Math.abs(body.latitude)>90||Math.abs(body.longitude)>180)
    return NextResponse.json({error:"Koordinat tidak valid"},{status:400});
  if(body.speed_kph!==undefined&&(!Number.isFinite(body.speed_kph)||body.speed_kph<0||body.speed_kph>250))return NextResponse.json({error:"Kecepatan tidak valid"},{status:400});
  if(body.heading!==undefined&&(!Number.isFinite(body.heading)||body.heading<0||body.heading>=360))return NextResponse.json({error:"Heading tidak valid"},{status:400});
  if(body.fuel_percent!==undefined&&(!Number.isFinite(body.fuel_percent)||body.fuel_percent<0||body.fuel_percent>100))return NextResponse.json({error:"Fuel tidak valid"},{status:400});
  if(body.odometer_km!==undefined&&(!Number.isFinite(body.odometer_km)||body.odometer_km<0))return NextResponse.json({error:"Odometer tidak valid"},{status:400});
  const admin=createClient(url,key,{auth:{persistSession:false}});
  const {data:device}=await admin.from("gps_devices").select("id,vehicle_id,token_hash,active").eq("device_code",deviceCode).maybeSingle();
  const supplied=digest(token),expected=device?.token_hash||"";
  const valid=device?.active&&supplied.length===expected.length&&timingSafeEqual(Buffer.from(supplied),Buffer.from(expected));
  if(!valid)return NextResponse.json({error:"Device credential tidak valid"},{status:401});
  const recordedDate=body.recorded_at?new Date(body.recorded_at):new Date();
  if(Number.isNaN(recordedDate.getTime())||recordedDate.getTime()>Date.now()+5*60_000||recordedDate.getTime()<Date.now()-24*60*60_000)return NextResponse.json({error:"Timestamp di luar rentang yang diizinkan"},{status:400});
  const recordedAt=recordedDate.toISOString();
  const {data:recent}=await admin.from("gps_positions").select("id").eq("vehicle_id",device.vehicle_id).eq("recorded_at",recordedAt).maybeSingle();
  if(recent)return NextResponse.json({error:"Telemetry duplikat"},{status:409});
  const {data:position,error}=await admin.from("gps_positions").insert({vehicle_id:device.vehicle_id,latitude:body.latitude,longitude:body.longitude,speed_kph:body.speed_kph||0,heading:body.heading||0,recorded_at:recordedAt,source_type:source,accuracy_m:body.accuracy_m??null,external_tag_id:body.tag_id??null,metadata:body.zone?{zone:body.zone}:{}}).select("id").single();
  if(error)return NextResponse.json({error:error.message},{status:500});
  const updates=await Promise.all([
    admin.from("gps_devices").update({last_seen_at:recordedAt}).eq("id",device.id),
    admin.from("vehicles").update({last_lat:body.latitude,last_lng:body.longitude,last_gps_at:recordedAt,...(body.fuel_percent!==undefined?{fuel_percent:body.fuel_percent}:{}),...(body.odometer_km!==undefined?{odometer_km:body.odometer_km}:{})}).eq("id",device.vehicle_id),
  ]);
  const updateError=updates.find(x=>x.error)?.error;
  if(updateError){await admin.from("gps_positions").delete().eq("id",position.id);return NextResponse.json({error:`Sinkronisasi GPS gagal: ${updateError.message}`},{status:500})}
  const {data:geofences}=await admin.from("geofences").select("id,latitude,longitude,radius_meters").eq("active",true);
  for(const fence of geofences||[]){
    const rad=Math.PI/180,dLat=(body.latitude-fence.latitude)*rad,dLng=(body.longitude-fence.longitude)*rad;
    const a=Math.sin(dLat/2)**2+Math.cos(fence.latitude*rad)*Math.cos(body.latitude*rad)*Math.sin(dLng/2)**2;
    const inside=6371000*2*Math.atan2(Math.sqrt(a),Math.sqrt(1-a))<=fence.radius_meters;
    const {data:previous}=await admin.from("geofence_vehicle_state").select("is_inside").eq("geofence_id",fence.id).eq("vehicle_id",device.vehicle_id).maybeSingle();
    if(previous&&previous.is_inside!==inside)await admin.from("geofence_events").insert({geofence_id:fence.id,vehicle_id:device.vehicle_id,event_type:inside?"enter":"exit",latitude:body.latitude,longitude:body.longitude,recorded_at:recordedAt,source_position_id:position.id});
    await admin.from("geofence_vehicle_state").upsert({geofence_id:fence.id,vehicle_id:device.vehicle_id,is_inside:inside,updated_at:recordedAt});
  }
  return NextResponse.json({accepted:true,source,vehicle_id:device.vehicle_id,recorded_at:recordedAt});
}
