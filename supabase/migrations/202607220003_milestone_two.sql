-- ARAH Milestone 2: end-to-end fleet operations
create extension if not exists pgcrypto;

create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(), name text not null,
  address text, latitude double precision, longitude double precision,
  created_at timestamptz not null default now()
);
create table if not exists public.vendors (
  id uuid primary key default gen_random_uuid(), name text not null,
  contact_name text, phone text, email text, status text not null default 'active'
    check (status in ('active','inactive')), created_at timestamptz not null default now()
);
create table if not exists public.drivers (
  id uuid primary key default gen_random_uuid(), employee_number text unique,
  full_name text not null, phone text, license_number text, license_expiry date,
  status text not null default 'available' check (status in ('available','assigned','off_duty','suspended')),
  vendor_id uuid references public.vendors(id), branch_id uuid references public.branches(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

alter table public.vehicles add column if not exists driver_id uuid references public.drivers(id);
alter table public.vehicles add column if not exists vendor_id uuid references public.vendors(id);
alter table public.vehicles add column if not exists branch_id uuid references public.branches(id);
alter table public.vehicles add column if not exists capacity_kg numeric(12,2);
alter table public.vehicles add column if not exists odometer_km numeric(12,1) default 0;
alter table public.vehicles add column if not exists registration_expiry date;

alter table public.orders add column if not exists driver_id uuid references public.drivers(id);
alter table public.orders add column if not exists customer_name text;
alter table public.orders add column if not exists cargo_description text;
alter table public.orders add column if not exists cargo_weight_kg numeric(12,2);
alter table public.orders add column if not exists pickup_at timestamptz;
alter table public.orders add column if not exists delivered_at timestamptz;
alter table public.orders add column if not exists pod_url text;
alter table public.orders add column if not exists notes text;
alter table public.orders add column if not exists updated_at timestamptz not null default now();

create table if not exists public.order_events (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  status public.order_status not null, note text, actor_id uuid references public.profiles(id),
  latitude double precision, longitude double precision, created_at timestamptz not null default now()
);
create table if not exists public.order_waypoints (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  sequence int not null, label text not null, latitude double precision not null,
  longitude double precision not null, completed_at timestamptz, unique(order_id, sequence)
);

alter table public.operational_funds add column if not exists description text;
alter table public.operational_funds add column if not exists reviewed_at timestamptz;
alter table public.operational_funds add column if not exists rejection_reason text;
alter table public.operational_funds add column if not exists settlement_amount numeric(15,2);
alter table public.operational_funds add column if not exists settlement_note text;
alter table public.operational_funds add column if not exists settled_at timestamptz;
alter table public.operational_funds add column if not exists receipt_url text;

alter table public.field_issues add column if not exists status text not null default 'reported'
  check (status in ('reported','assigned','in_progress','resolved','closed'));
alter table public.field_issues add column if not exists assigned_to uuid references public.profiles(id);
alter table public.field_issues add column if not exists due_at timestamptz;
alter table public.field_issues add column if not exists resolution text;
alter table public.field_issues add column if not exists location_lat double precision;
alter table public.field_issues add column if not exists location_lng double precision;
alter table public.field_issues add column if not exists attachment_url text;
alter table public.field_issues add column if not exists updated_at timestamptz not null default now();

create table if not exists public.geofences (
  id uuid primary key default gen_random_uuid(), name text not null,
  kind text not null default 'customer' check (kind in ('depot','customer','port','restricted')),
  latitude double precision not null, longitude double precision not null,
  radius_meters int not null default 250 check (radius_meters between 25 and 10000),
  active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.geofence_events (
  id bigint generated always as identity primary key,
  geofence_id uuid not null references public.geofences(id) on delete cascade,
  vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  event_type text not null check (event_type in ('enter','exit')),
  latitude double precision, longitude double precision, recorded_at timestamptz not null default now()
);
create table if not exists public.gps_devices (
  id uuid primary key default gen_random_uuid(), vehicle_id uuid not null unique references public.vehicles(id) on delete cascade,
  device_code text not null unique, token_hash text not null, active boolean not null default true,
  last_seen_at timestamptz, created_at timestamptz not null default now()
);
create table if not exists public.maintenance_records (
  id uuid primary key default gen_random_uuid(), vehicle_id uuid not null references public.vehicles(id) on delete cascade,
  maintenance_type text not null, scheduled_at timestamptz, completed_at timestamptz,
  odometer_km numeric(12,1), cost numeric(15,2), notes text, created_at timestamptz not null default now()
);

create index if not exists order_events_order_time on public.order_events(order_id,created_at desc);
create index if not exists orders_status_updated on public.orders(status,updated_at desc);
create index if not exists issues_status_due on public.field_issues(status,due_at);

do $$ begin
  alter type public.order_status add value if not exists 'pickup';
exception when duplicate_object then null; end $$;

alter table public.branches enable row level security; alter table public.vendors enable row level security;
alter table public.drivers enable row level security; alter table public.order_events enable row level security;
alter table public.order_waypoints enable row level security; alter table public.geofences enable row level security;
alter table public.geofence_events enable row level security; alter table public.gps_devices enable row level security;
alter table public.maintenance_records enable row level security;

do $$ declare t text; begin
  foreach t in array array['branches','vendors','drivers','order_events','order_waypoints','geofences','geofence_events','maintenance_records'] loop
    execute format('drop policy if exists "authenticated read %s" on public.%I',t,t);
    execute format('create policy "authenticated read %s" on public.%I for select to authenticated using (true)',t,t);
    execute format('drop policy if exists "operations manage %s" on public.%I',t,t);
    execute format('create policy "operations manage %s" on public.%I for all to authenticated using (public.current_role() in (''super_admin'',''fleet_manager'',''dispatcher'')) with check (public.current_role() in (''super_admin'',''fleet_manager'',''dispatcher''))',t,t);
  end loop;
end $$;
drop policy if exists "admins manage gps devices" on public.gps_devices;
create policy "admins manage gps devices" on public.gps_devices for all to authenticated
  using (public.current_role() in ('super_admin','fleet_manager'))
  with check (public.current_role() in ('super_admin','fleet_manager'));

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
values ('operations','operations',false,10485760,array['image/jpeg','image/png','image/webp','application/pdf'])
on conflict (id) do nothing;
drop policy if exists "authenticated upload operations" on storage.objects;
create policy "authenticated upload operations" on storage.objects for insert to authenticated
  with check (bucket_id='operations');
drop policy if exists "authenticated read operations" on storage.objects;
create policy "authenticated read operations" on storage.objects for select to authenticated
  using (bucket_id='operations');

do $$ begin alter publication supabase_realtime add table public.gps_positions;
exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.order_events;
exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.geofence_events;
exception when duplicate_object then null; end $$;
