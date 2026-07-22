-- Resolve the signed-in user's access profile without depending on table RLS.
create or replace function public.get_my_access_profile()
returns table (
  id uuid,
  role text,
  status text
)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.role, p.status
  from public.profiles p
  where p.id = auth.uid()
  limit 1
$$;

revoke all
  on function public.get_my_access_profile()
  from public, anon;

grant execute
  on function public.get_my_access_profile()
  to authenticated;
