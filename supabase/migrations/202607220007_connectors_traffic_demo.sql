-- ARAH Milestone 2 improvement: multi-source telemetry and rich demo dataset.
alter table public.branches add column if not exists code text unique;
alter table public.branches add column if not exists active boolean not null default true;
alter table public.gps_devices add column if not exists source_type text not null default 'gps_device'
  check (source_type in ('android','gps_device','uwb'));
alter table public.gps_positions add column if not exists source_type text not null default 'gps_device'
  check (source_type in ('android','gps_device','uwb'));
alter table public.gps_positions add column if not exists accuracy_m numeric(8,2);
alter table public.gps_positions add column if not exists external_tag_id text;
alter table public.gps_positions add column if not exists metadata jsonb not null default '{}'::jsonb;

create table if not exists public.telemetry_connectors (
  id uuid primary key default gen_random_uuid(), name text not null, source_type text not null
    check (source_type in ('android','gps_device','uwb')), endpoint_hint text,
  active boolean not null default true, configuration jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id), created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.telemetry_connectors enable row level security;
drop policy if exists "authenticated read telemetry connectors" on public.telemetry_connectors;
create policy "authenticated read telemetry connectors" on public.telemetry_connectors for select to authenticated using (true);
drop policy if exists "admins manage telemetry connectors" on public.telemetry_connectors;
create policy "admins manage telemetry connectors" on public.telemetry_connectors for all to authenticated
 using (public.current_role() in ('super_admin','fleet_manager')) with check (public.current_role() in ('super_admin','fleet_manager'));

insert into public.app_settings(key,value) values
 ('display_defaults','{"language":"id","windowOpacity":94,"fontScale":100,"contrast":"normal","traffic":true}'::jsonb),
 ('traffic','{"provider":"tomtom","enabled":true,"mode":"relative-flow"}'::jsonb)
on conflict(key) do update set value=public.app_settings.value || excluded.value;

-- Deterministic operational demo data; safe to rerun.
insert into public.branches(id,code,name,address,latitude,longitude,active) values
 ('10000000-0000-4000-8000-000000000001','JKT','Jakarta Hub','Cakung, Jakarta Timur',-6.185,106.947,true),
 ('10000000-0000-4000-8000-000000000002','TGR','Tangerang Depot','Balaraja, Tangerang',-6.199,106.519,true)
on conflict(id) do update set name=excluded.name,address=excluded.address,active=true;
insert into public.vendors(id,name,contact_name,phone,email,status) values
 ('20000000-0000-4000-8000-000000000001','ARAH Demo Logistics','Demo Operation','081200000001','demo.ops@arah.id','active')
on conflict(id) do nothing;
insert into public.drivers(id,employee_number,full_name,phone,license_number,status,vendor_id,branch_id) values
 ('30000000-0000-4000-8000-000000000001','DRV-001','Budi Santoso','081211110001','B1-001','assigned','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001'),
 ('30000000-0000-4000-8000-000000000002','DRV-002','Raka Pratama','081211110002','B1-002','available','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002')
on conflict(id) do nothing;
insert into public.vehicles(id,plate_number,vehicle_type,status,driver_name,driver_id,fuel_percent,last_lat,last_lng,last_gps_at,capacity_kg,branch_id,vendor_id) values
 ('40000000-0000-4000-8000-000000000001','B 9127 UYT','CDD Box','in_transit','Budi Santoso','30000000-0000-4000-8000-000000000001',72,-6.185,106.947,now(),5000,'10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001'),
 ('40000000-0000-4000-8000-000000000002','B 8831 KXR','Fuso','available','Raka Pratama','30000000-0000-4000-8000-000000000002',91,-6.199,106.519,now(),8000,'10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000001')
on conflict(id) do update set last_gps_at=now();
insert into public.orders(id,order_number,customer_name,origin,destination,status,vehicle_id,driver_id,cargo_description,cargo_weight_kg,scheduled_at,eta) values
 ('50000000-0000-4000-8000-000000000001','DO-DEMO-001','PT Nusantara Retail','Jakarta Hub','Bekasi DC','in_transit','40000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','Consumer goods',3200,now(),now()+interval '2 hours'),
 ('50000000-0000-4000-8000-000000000002','DO-DEMO-002','PT Indonesia Manufacturing','Tangerang Depot','Karawang Plant','assigned','40000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','Spare parts',5100,now()+interval '1 hour',now()+interval '5 hours')
on conflict(id) do nothing;

comment on table public.telemetry_connectors is 'Configuration registry for Android, physical GPS device, and UWB RTLS gateway connectors.';
