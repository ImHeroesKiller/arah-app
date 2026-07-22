-- Milestone 3: Fleet & Order Control Center operational model and complete demo data.

alter table public.vehicles add column if not exists brand text;
alter table public.vehicles add column if not exists model text;
alter table public.vehicles add column if not exists year int;
alter table public.vehicles add column if not exists vendor_name text;
alter table public.vehicles add column if not exists photo_url text;
alter table public.vehicles add column if not exists device_status text default 'online';
alter table public.drivers add column if not exists photo_url text;
alter table public.orders add column if not exists cargo_category text;
alter table public.orders add column if not exists cargo_quantity numeric(12,2);
alter table public.orders add column if not exists cargo_unit text;
alter table public.orders add column if not exists cargo_volume_m3 numeric(12,2);
alter table public.orders add column if not exists declared_value numeric(18,2);
alter table public.orders add column if not exists handling_instructions text[];
alter table public.orders add column if not exists pickup_pic text;
alter table public.orders add column if not exists recipient_pic text;
alter table public.orders add column if not exists document_url text;

create table if not exists public.vehicle_health_checks (
 id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 component text not null, status text not null default 'ok' check(status in ('ok','warning','due','critical')),
 value text, last_checked_at timestamptz, next_due_at timestamptz, odometer_due_km numeric(12,2), notes text,
 updated_at timestamptz not null default now(), unique(vehicle_id,component)
);
create table if not exists public.cctv_devices (
 id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 camera_name text not null, camera_position text not null check(camera_position in ('front','cabin','rear','cargo')),
 status text not null default 'offline' check(status in ('online','offline','degraded')), stream_url text,
 last_seen_at timestamptz, firmware_version text, unique(vehicle_id,camera_position)
);
create table if not exists public.trip_communications (
 id uuid primary key default gen_random_uuid(), vehicle_id uuid references public.vehicles(id) on delete cascade,
 order_id uuid references public.orders(id) on delete cascade, sender_id uuid references public.profiles(id),
 sender_type text not null check(sender_type in ('dispatcher','driver','system','staff')),
 channel text not null check(channel in ('in_app','voice','video','phone','push')), message text not null,
 delivered_at timestamptz default now(), read_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.vehicle_history (
 id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id) on delete cascade,
 order_id uuid references public.orders(id) on delete set null, event_type text not null,
 title text not null, description text, cost numeric(15,2), downtime_minutes int,
 occurred_at timestamptz not null default now(), resolved_at timestamptz, pic_name text, metadata jsonb not null default '{}'::jsonb
);
create index if not exists vehicle_history_vehicle_time on public.vehicle_history(vehicle_id,occurred_at desc);
create index if not exists trip_communications_order_time on public.trip_communications(order_id,created_at desc);

alter table public.vehicle_health_checks enable row level security;
alter table public.cctv_devices enable row level security;
alter table public.trip_communications enable row level security;
alter table public.vehicle_history enable row level security;
drop policy if exists "authenticated read vehicle health" on public.vehicle_health_checks;
drop policy if exists "authenticated read cctv" on public.cctv_devices;
drop policy if exists "authenticated read communications" on public.trip_communications;
drop policy if exists "authenticated read vehicle history" on public.vehicle_history;
create policy "authenticated read vehicle health" on public.vehicle_health_checks for select to authenticated using(true);
create policy "authenticated read cctv" on public.cctv_devices for select to authenticated using(true);
create policy "authenticated read communications" on public.trip_communications for select to authenticated using(true);
create policy "authenticated read vehicle history" on public.vehicle_history for select to authenticated using(true);
create policy "authenticated send communications" on public.trip_communications for insert to authenticated with check(true);
create policy "operations manage vehicle health" on public.vehicle_health_checks for all to authenticated using((select role from public.profiles where id=auth.uid()) in ('super_admin','fleet_manager','dispatcher')) with check((select role from public.profiles where id=auth.uid()) in ('super_admin','fleet_manager','dispatcher'));
create policy "operations manage cctv" on public.cctv_devices for all to authenticated using((select role from public.profiles where id=auth.uid()) in ('super_admin','fleet_manager')) with check((select role from public.profiles where id=auth.uid()) in ('super_admin','fleet_manager'));
create policy "operations manage vehicle history" on public.vehicle_history for all to authenticated using((select role from public.profiles where id=auth.uid()) in ('super_admin','fleet_manager','dispatcher')) with check((select role from public.profiles where id=auth.uid()) in ('super_admin','fleet_manager','dispatcher'));

do $$
declare demo_user uuid;
begin
 select id into demo_user from auth.users where lower(email)='demo@arah.id' limit 1;
 if demo_user is null then raise exception 'Akun demo@arah.id belum tersedia'; end if;

 update public.vehicles v set
  brand=(array['Hino','Isuzu','Mitsubishi Fuso','UD Trucks','Toyota'])[((right(v.id::text,2)::int-1)%5)+1],
  model=(array['Dutro 130 HD','Elf NMR 71','Canter FE 74','Quester CWE','Dyna 136 HT'])[((right(v.id::text,2)::int-1)%5)+1],
  year=2020+((right(v.id::text,2)::int)%6),
  vendor_name=(array['PT Trans Logistik Utama','PT Karya Angkut Nusantara','PT Mitra Fleet Indonesia','PT Jalur Prima Logistik'])[((right(v.id::text,2)::int-1)%4)+1],
  photo_url='https://images.unsplash.com/photo-1586191582151-f73872dfd183?auto=format&fit=crop&w=900&q=80',
  device_status=case when right(v.id::text,2)::int=18 then 'degraded' else 'online' end
 where v.id::text like '40000000-0000-4000-8000-%';

 update public.drivers d set
  photo_url='https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=300&q=80'
 where d.id::text like '30000000-0000-4000-8000-%';

 update public.orders o set
  cargo_category=(array['FMCG','Otomotif','Kemasan','Elektronik','Farmasi','Material Industri','Bahan Baku','Retail Equipment'])[((right(o.vehicle_id::text,2)::int-1)%8)+1],
  cargo_quantity=40+right(o.vehicle_id::text,2)::int*7,
  cargo_unit=(array['karton','pallet','roll','unit','boks','peti'])[((right(o.vehicle_id::text,2)::int-1)%6)+1],
  cargo_volume_m3=8+(right(o.vehicle_id::text,2)::int*1.35),
  declared_value=75000000+(right(o.vehicle_id::text,2)::int*27500000),
  handling_instructions=case when right(o.vehicle_id::text,2)::int%5=0 then array['Temperature Controlled','Fragile'] when right(o.vehicle_id::text,2)::int%3=0 then array['Fragile','Keep Dry'] else array['Segel wajib utuh','Dilarang ditumpuk berlebih'] end,
  pickup_pic='Andi Pratama · 0812-8800-'||lpad(right(o.vehicle_id::text,2),4,'0'),
  recipient_pic='Siti Rahma · 0813-9900-'||lpad(right(o.vehicle_id::text,2),4,'0'),
  document_url='https://arah-app-delta.vercel.app/'
 where o.vehicle_id::text like '40000000-0000-4000-8000-%';

 delete from public.vehicle_health_checks where vehicle_id::text like '40000000-0000-4000-8000-%';
 insert into public.vehicle_health_checks(vehicle_id,component,status,value,last_checked_at,next_due_at,notes)
 select v.id,c.component,
  case when right(v.id::text,2)::int in (7,14) and c.component in ('tires','brakes') then 'warning' when right(v.id::text,2)::int=19 and c.component='kir' then 'due' else 'ok' end,
  case c.component when 'service' then 'Service terakhir 6.000 km lalu' when 'engine_oil' then 'Level 82% · SAE 15W-40' when 'tires' then 'Tekanan 92–98 PSI' when 'brakes' then 'Kampas 68%' when 'battery' then '12,6 V · sehat' when 'vehicle_tax' then 'Aktif' when 'stnk' then 'Dokumen tersedia' when 'kir' then 'Lulus uji' when 'insurance' then 'All Risk' when 'gps_cctv' then 'GPS + dual camera' else 'APAR 3 kg & P3K lengkap' end,
  now()-(right(v.id::text,2)::int%20)*interval '1 day',
  case c.component when 'service' then now()+interval '45 day' when 'engine_oil' then now()+interval '60 day' when 'tires' then now()+interval '14 day' when 'brakes' then now()+interval '30 day' when 'battery' then now()+interval '90 day' when 'vehicle_tax' then now()+interval '120 day' when 'stnk' then now()+interval '180 day' when 'kir' then now()+case when right(v.id::text,2)::int=19 then interval '5 day' else interval '100 day' end when 'insurance' then now()+interval '210 day' when 'gps_cctv' then now()+interval '7 day' else now()+interval '80 day' end,
  'Checklist Demo terverifikasi oleh Fleet Inspector'
 from public.vehicles v cross join (values('service'),('engine_oil'),('tires'),('brakes'),('battery'),('vehicle_tax'),('stnk'),('kir'),('insurance'),('gps_cctv'),('safety_kit')) c(component)
 where v.id::text like '40000000-0000-4000-8000-%';

 delete from public.cctv_devices where vehicle_id::text like '40000000-0000-4000-8000-%';
 insert into public.cctv_devices(vehicle_id,camera_name,camera_position,status,last_seen_at,firmware_version)
 select v.id,'Kamera Depan','front',case when right(v.id::text,2)::int=18 then 'degraded' else 'online' end,now()-right(v.id::text,2)::int*interval '5 second','ARAH-CAM 2.4.1' from public.vehicles v where v.id::text like '40000000-0000-4000-8000-%'
 union all
 select v.id,'Kamera Kabin','cabin',case when right(v.id::text,2)::int=18 then 'offline' else 'online' end,now()-right(v.id::text,2)::int*interval '6 second','ARAH-CAM 2.4.1' from public.vehicles v where v.id::text like '40000000-0000-4000-8000-%';

 delete from public.trip_communications where vehicle_id::text like '40000000-0000-4000-8000-%';
 insert into public.trip_communications(vehicle_id,order_id,sender_id,sender_type,channel,message,created_at,read_at)
 select o.vehicle_id,o.id,demo_user,'dispatcher','in_app','Konfirmasi posisi dan kondisi muatan.',now()-right(o.vehicle_id::text,2)::int*interval '7 minute',now()-right(o.vehicle_id::text,2)::int*interval '6 minute' from public.orders o where o.status='in_transit' and o.order_number like 'DO-LIVE-%'
 union all
 select o.vehicle_id,o.id,null,'driver','in_app','Posisi aman, muatan dan segel dalam kondisi baik.',now()-right(o.vehicle_id::text,2)::int*interval '6 minute',now()-right(o.vehicle_id::text,2)::int*interval '5 minute' from public.orders o where o.status='in_transit' and o.order_number like 'DO-LIVE-%';

 delete from public.vehicle_history where vehicle_id::text like '40000000-0000-4000-8000-%';
 insert into public.vehicle_history(vehicle_id,order_id,event_type,title,description,cost,downtime_minutes,occurred_at,resolved_at,pic_name)
 select v.id,null,'maintenance','Service berkala selesai','Penggantian oli, filter, dan pemeriksaan 21 titik.',1250000+(right(v.id::text,2)::int*75000),180,now()-interval '45 day'-right(v.id::text,2)::int*interval '1 day',now()-interval '45 day','Budi Santoso' from public.vehicles v where v.id::text like '40000000-0000-4000-8000-%'
 union all
 select o.vehicle_id,o.id,'trip','Order pengantaran dimulai',o.origin||' menuju '||o.destination,null,null,o.pickup_at,null,'Dispatcher ARAH' from public.orders o where o.status='in_transit' and o.order_number like 'DO-LIVE-%'
 union all
 select i.vehicle_id,i.order_id,'incident',i.title,i.description,null,case when i.status='resolved' then 45 else null end,i.created_at,i.resolved_at,'Fleet Operations' from public.field_issues i where i.vehicle_id::text like '40000000-0000-4000-8000-%';
end $$;
