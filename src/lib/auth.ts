import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";
export type AppRole="super_admin"|"fleet_manager"|"dispatcher"|"finance_approver"|"viewer";
let client:SupabaseClient|null=null;
export function supabaseBrowser(){const url=process.env.NEXT_PUBLIC_SUPABASE_URL,key=process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;if(!url||!key)return null;client??=createBrowserClient(url,key);return client}
export const can=(role:AppRole|undefined,action:"operate"|"finance"|"users")=>!!role&&({operate:["super_admin","fleet_manager","dispatcher"],finance:["super_admin","finance_approver"],users:["super_admin"]}[action] as string[]).includes(role);
