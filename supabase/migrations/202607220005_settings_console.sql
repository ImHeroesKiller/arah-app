-- ARAH Settings Console: branch lifecycle and delegated settings access.
alter table public.branches add column if not exists active boolean not null default true;
alter table public.notifications add column if not exists read_at timestamptz;

drop policy if exists "fleet managers update settings" on public.app_settings;
create policy "fleet managers update settings" on public.app_settings
for update to authenticated
using (public.current_role() in ('super_admin','fleet_manager'))
with check (public.current_role() in ('super_admin','fleet_manager'));

drop policy if exists "fleet managers read audit" on public.audit_logs;
create policy "fleet managers read audit" on public.audit_logs
for select to authenticated
using (public.current_role() in ('super_admin','fleet_manager','finance_approver'));

drop policy if exists "settings managers update branches" on public.branches;
create policy "settings managers update branches" on public.branches
for update to authenticated
using (public.current_role() in ('super_admin','fleet_manager'))
with check (public.current_role() in ('super_admin','fleet_manager'));

insert into public.app_settings(key,value)
values ('operations','{"company_name":"ARAH Fleet Command Center","timezone":"Asia/Jakarta","gps_stale_minutes":10,"sla_warning_minutes":30,"sla_scan_minutes":5}'::jsonb)
on conflict(key) do update set value=public.app_settings.value || excluded.value;
