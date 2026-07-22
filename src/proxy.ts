import {createServerClient} from "@supabase/ssr";
import {NextResponse,type NextRequest} from "next/server";

export async function proxy(request:NextRequest){
  let response=NextResponse.next({request});
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if(!url||!key){
    if(request.nextUrl.pathname!=="/login")return NextResponse.redirect(new URL("/login?error=config",request.url));
    return response;
  }
  const supabase=createServerClient(url,key,{cookies:{
    getAll:()=>request.cookies.getAll(),
    setAll:items=>{items.forEach(({name,value})=>request.cookies.set(name,value));response=NextResponse.next({request});items.forEach(({name,value,options})=>response.cookies.set(name,value,options))}
  }});
  const {data:{user}}=await supabase.auth.getUser();
  const isLogin=request.nextUrl.pathname==="/login";
  if(!user&&!isLogin){const target=new URL("/login",request.url);target.searchParams.set("next",request.nextUrl.pathname);return NextResponse.redirect(target)}
  if(user){
    const {data:profiles,error:profileError}=await supabase.rpc("get_my_access_profile");
    const profile=Array.isArray(profiles)?profiles[0]:profiles;
    if(profileError)return NextResponse.redirect(new URL("/login?error=profile",request.url));
    if(!profile)return NextResponse.redirect(new URL("/login?error=unregistered",request.url));
    if(profile.status!=="active"){await supabase.auth.signOut();return NextResponse.redirect(new URL(`/login?error=${profile.status||"inactive"}`,request.url))}
    if(request.nextUrl.pathname.startsWith("/users")&&profile?.role!=="super_admin")return NextResponse.redirect(new URL("/?error=forbidden",request.url));
    if(request.nextUrl.pathname.startsWith("/settings")&&!['super_admin','fleet_manager','finance_approver','dispatcher'].includes(profile?.role||''))return NextResponse.redirect(new URL("/?error=forbidden",request.url));
    if(isLogin)return NextResponse.redirect(new URL("/",request.url));
  }
  response.headers.set("X-Content-Type-Options","nosniff");
  response.headers.set("Referrer-Policy","strict-origin-when-cross-origin");
  response.headers.set("Permissions-Policy","camera=(), microphone=(), geolocation=(self)");
  response.headers.set("X-Frame-Options","DENY");
  response.headers.set("Content-Security-Policy","frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
  return response;
}

export const config={matcher:["/((?!_next/static|_next/image|favicon.ico|api/).*)"]};
