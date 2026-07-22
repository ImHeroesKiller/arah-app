-- ARAH audit remediation: atomic workflows, scoped access, attachments and alerts.
create extension if not exists pgcrypto;

alter table public.branches add column if not exists code text unique;
update public.branches set code=coalesce(code,upper(left(regexp_replace(name,'[^A-Za-z0-9]','','g'),12))) where code is null;
alter table public.profiles add column if not exists branch_id uuid references public.branches(id);
alter table public.operational_funds add column if not exists updated_at timestamptz not null default now();
alter table public.geofence_events add column if not exists source_position_id bigint references public.gps_positions(id);

create table if not exists public.operation_attachments(
 id uuid primary key default gen_random_uuid(), entity_type text not null check(entity_type in ('order_pod','order_manifest','fund_receipt','issue_evidence','vehicle_document','driver_document','vendor_document')),
 entity_id uuid not null, storage_path text not null unique, file_name text not null, mime_type text not null,
 size_bytes bigint not null check(size_bytes between 1 and 10485760), uploaded_by uuid not null references public.profiles(id), created_at timestamptz not null default now()
);
create table if not exists public.geofence_vehicle_state(
 geofence_id uuid references public.geofences(id) on delete cascade, vehicle_id uuid references public.vehicles(id) on delete cascade,
 is_inside boolean not null, updated_at timestamptz not null default now(), primary key(geofence_id,vehicle_id)
);
alter table public.operation_attachments enable row level security;
alter table public.geofence_vehicle_state enable row level security;

create or replace function public.current_scope() returns text language sql stable security definer set search_path=public as $$select operational_scope from public.profiles where id=auth.uid()$$;
create or replace function public.current_branch() returns uuid language sql stable security definer set search_path=public as $$select branch_id from public.profiles where id=auth.uid()$$;
create or replace function public.scope_allows(row_branch uuid) returns boolean language sql stable security definer set search_path=public as $$select public.current_role()='super_admin' or public.current_scope() in ('all','Semua Area') or row_branch=public.current_branch()$$;

drop policy if exists "authenticated read vehicles" on public.vehicles;
create policy "scoped read vehicles" on public.vehicles for select to authenticated using(public.scope_allows(branch_id));
drop policy if exists "authenticated read orders" on public.orders;
create policy "scoped read orders" on public.orders for select to authenticated using(vehicle_id is null or exists(select 1 from public.vehicles v where v.id=vehicle_id and public.scope_allows(v.branch_id)));
drop policy if exists "authenticated read drivers" on public.drivers;
create policy "scoped read drivers" on public.drivers for select to authenticated using(public.scope_allows(branch_id));

drop policy if exists "finance manage funds" on public.operational_funds;
create policy "operations request funds" on public.operational_funds for insert to authenticated with check(requested_by=auth.uid() and public.current_role() in ('super_admin','fleet_manager','dispatcher'));
create policy "finance update funds" on public.operational_funds for update to authenticated using(public.current_role() in ('super_admin','finance_approver')) with check(public.current_role() in ('super_admin','finance_approver'));

create policy "scoped attachments read" on public.operation_attachments for select to authenticated using(uploaded_by=auth.uid() or public.current_role() in ('super_admin','fleet_manager','finance_approver'));
create policy "operations attachments write" on public.operation_attachments for insert to authenticated with check(uploaded_by=auth.uid());
create policy "geofence state read" on public.geofence_vehicle_state for select to authenticated using(true);

drop policy if exists "authenticated upload operations" on storage.objects;
drop policy if exists "authenticated read operations" on storage.objects;
create policy "scoped operations upload" on storage.objects for insert to authenticated with check(bucket_id='operations' and (storage.foldername(name))[1]=auth.uid()::text);
create policy "scoped operations read" on storage.objects for select to authenticated using(bucket_id='operations' and ((storage.foldername(name))[1]=auth.uid()::text or public.current_role() in ('super_admin','fleet_manager','finance_approver')));

create or replace function public.transition_order(p_order uuid,p_status public.order_status,p_note text default null,p_pod_path text default null)
returns void language plpgsql security definer set search_path=public as $$
declare old_status public.order_status; allowed boolean:=false;
begin
 if public.current_role() not in ('super_admin','fleet_manager','dispatcher') then raise exception 'forbidden'; end if;
 select status into old_status from orders where id=p_order for update;
 allowed := (old_status='planned' and p_status in ('assigned','cancelled')) or (old_status='assigned' and p_status in ('pickup','cancelled')) or (old_status='pickup' and p_status in ('in_transit','cancelled')) or (old_status='in_transit' and p_status='delivered');
 if not allowed then raise exception 'invalid transition: % -> %',old_status,p_status; end if;
 if p_status='delivered' and coalesce(p_pod_path,'')='' and not exists(select 1 from operation_attachments where entity_type='order_pod' and entity_id=p_order) then raise exception 'POD wajib sebelum delivered'; end if;
 update orders set status=p_status,updated_at=now(),pickup_at=case when p_status='pickup' then now() else pickup_at end,delivered_at=case when p_status='delivered' then now() else delivered_at end,pod_url=coalesce(p_pod_path,pod_url) where id=p_order;
 insert into order_events(order_id,status,note,actor_id) values(p_order,p_status,p_note,auth.uid());
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'order.'||p_status,'order',p_order::text,jsonb_build_object('from',old_status,'to',p_status));
end$$;

create or replace function public.review_fund(p_fund uuid,p_decision public.approval_status,p_reason text default null)
returns void language plpgsql security definer set search_path=public as $$
begin
 if public.current_role() not in ('super_admin','finance_approver') then raise exception 'forbidden'; end if;
 if p_decision not in ('approved','rejected') or (p_decision='rejected' and nullif(trim(p_reason),'') is null) then raise exception 'Keputusan/alasan penolakan tidak valid'; end if;
 update operational_funds set status=p_decision,approved_by=auth.uid(),reviewed_at=now(),rejection_reason=case when p_decision='rejected' then p_reason end,updated_at=now() where id=p_fund and status='pending';
 if not found then raise exception 'Dana tidak ditemukan atau sudah direview'; end if;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'fund.'||p_decision,'operational_fund',p_fund::text,jsonb_build_object('reason',p_reason));
end$$;

create or replace function public.update_issue_status(p_issue uuid,p_status text,p_assignee uuid default null,p_resolution text default null)
returns void language plpgsql security definer set search_path=public as $$
declare old_status text;
begin
 if public.current_role() not in ('super_admin','fleet_manager','dispatcher') then raise exception 'forbidden'; end if;
 select status into old_status from field_issues where id=p_issue for update;
 if (old_status='reported' and p_status<>'assigned') or (old_status='assigned' and p_status not in ('in_progress','resolved')) or (old_status='in_progress' and p_status<>'resolved') or (old_status='resolved' and p_status<>'closed') then raise exception 'Transisi issue tidak valid'; end if;
 if p_status='assigned' and p_assignee is null then raise exception 'PIC wajib dipilih'; end if;
 if p_status='resolved' and nullif(trim(p_resolution),'') is null then raise exception 'Resolusi wajib diisi'; end if;
 update field_issues set status=p_status,assigned_to=coalesce(p_assignee,assigned_to),resolution=case when p_status='resolved' then p_resolution else resolution end,resolved_at=case when p_status='resolved' then now() else resolved_at end,updated_at=now() where id=p_issue;
 insert into audit_logs(actor_id,action,entity_type,entity_id,metadata) values(auth.uid(),'issue.'||p_status,'field_issue',p_issue::text,jsonb_build_object('from',old_status,'assignee',p_assignee));
end$$;

alter table public.notifications add column if not exists read_at timestamptz;
create or replace function public.mark_notification_read(p_id uuid) returns void language sql security definer set search_path=public as $$update notifications set read_at=now() where id=p_id and user_id=auth.uid()$$;
create or replace function public.generate_sla_notifications() returns integer language plpgsql security definer set search_path=public as $$
declare count_rows int;
begin
 insert into notifications(user_id,title,body,kind)
 select coalesce(f.assigned_to,f.reported_by),'SLA issue mendekati/melewati batas',f.title,'warning' from field_issues f
 where f.status not in ('resolved','closed') and f.due_at<=now()+interval '30 minutes' and coalesce(f.assigned_to,f.reported_by) is not null
 and not exists(select 1 from notifications n where n.user_id=coalesce(f.assigned_to,f.reported_by) and n.body=f.title and n.created_at>now()-interval '6 hours');
 get diagnostics count_rows=row_count; return count_rows;
end$$;

grant execute on function public.transition_order(uuid,public.order_status,text,text) to authenticated;
grant execute on function public.review_fund(uuid,public.approval_status,text) to authenticated;
grant execute on function public.update_issue_status(uuid,text,uuid,text) to authenticated;
grant execute on function public.mark_notification_read(uuid) to authenticated;
revoke all on function public.generate_sla_notifications() from public,anon,authenticated;
