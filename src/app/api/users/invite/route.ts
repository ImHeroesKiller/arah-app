import {createClient} from "@supabase/supabase-js";
import {NextRequest,NextResponse} from "next/server";
import type {AppRole} from "@/lib/auth";

const roles:AppRole[]=["super_admin","fleet_manager","dispatcher","finance_approver","viewer"];

export async function POST(req:NextRequest){
 const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,service=process.env.SUPABASE_SERVICE_ROLE_KEY;
 if(!url||!key||!service)return NextResponse.json({error:"SUPABASE_SERVICE_ROLE_KEY belum dikonfigurasi di Vercel."},{status:503});
 const token=req.headers.get("authorization")?.replace(/^Bearer\s+/i,"");
 if(!token)return NextResponse.json({error:"Unauthorized"},{status:401});
 const pub=createClient(url,key),{data:{user}}=await pub.auth.getUser(token);
 if(!user)return NextResponse.json({error:"Unauthorized"},{status:401});
 const admin=createClient(url,service,{auth:{autoRefreshToken:false,persistSession:false}});
 const {data:profile}=await admin.from("profiles").select("role,status").eq("id",user.id).single();
 if(profile?.role!=="super_admin"||profile.status!=="active")return NextResponse.json({error:"Forbidden"},{status:403});
 const body=await req.json().catch(()=>null) as null|{email?:string;full_name?:string;role?:AppRole;operational_scope?:string};
 const email=body?.email?.trim().toLowerCase(),fullName=body?.full_name?.trim(),role=body?.role,scope=body?.operational_scope?.trim();
 if(!email||!/^\S+@\S+\.\S+$/.test(email)||!fullName||!role||!roles.includes(role)||!scope)
  return NextResponse.json({error:"Data undangan tidak valid."},{status:400});
 const {data,error}=await admin.auth.admin.inviteUserByEmail(email,{data:{full_name:fullName}});
 if(error)return NextResponse.json({error:error.message},{status:400});
 const {error:profileError}=await admin.from("profiles").upsert({id:data.user.id,full_name:fullName,role,operational_scope:scope,status:"invited"});
 if(profileError)return NextResponse.json({error:`Akun dibuat, tetapi profil gagal disimpan: ${profileError.message}`},{status:500});
 const {error:auditError}=await admin.from("audit_logs").insert({actor_id:user.id,action:"user.invited",entity_type:"profile",entity_id:data.user.id,metadata:{email,role}});
 if(auditError)return NextResponse.json({error:`Undangan berhasil, tetapi audit log gagal: ${auditError.message}`},{status:500});
 return NextResponse.json({ok:true});
}
