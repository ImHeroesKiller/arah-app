-- ARAH Demo v2: presentation dataset aligned with the Fleet & Order Control Center.
-- Exactly 19 of 20 vehicles (95%) have an active delivery and a drawable route.

do $$
declare
  demo_user uuid;
begin
  select id into demo_user from auth.users where lower(email)='demo@arah.id' limit 1;
  if demo_user is null then raise exception 'Akun demo@arah.id belum tersedia'; end if;

  -- Reset transaction-dependent demo data while preserving users and master data.
  delete from public.notifications where user_id=demo_user or title like '[DEMO ARAH]%';
  if to_regclass('public.operation_attachments') is not null then
    execute 'delete from public.operation_attachments where entity_type in (''order_pod'',''order_manifest'',''fund_receipt'',''issue_evidence'')';
  end if;
  delete from public.order_waypoints;
  delete from public.order_events;
  delete from public.routes;
  delete from public.field_issues;
  delete from public.operational_funds;
  delete from public.orders;
  delete from public.gps_positions;

  update public.drivers
  set status=case when id='30000000-0000-4000-8000-000000000020' then 'available' else 'assigned' end,
      updated_at=now();

  update public.vehicles
  set status=case when id='40000000-0000-4000-8000-000000000020' then 'available'::public.vehicle_status else 'in_transit'::public.vehicle_status end,
      last_lat=-6.125-((substring(id::text from 36 for 1)::int%5)*.045),
      last_lng=106.575+((substring(id::text from 36 for 1)::int%10)*.065),
      last_gps_at=now()-(substring(id::text from 36 for 1)::int)*interval '8 seconds',
      fuel_percent=48+((substring(id::text from 36 for 1)::int*7)%48);

  -- 19 live deliveries: one active order for every moving vehicle.
  insert into public.orders(id,order_number,customer_name,origin,destination,status,vehicle_id,driver_id,cargo_description,cargo_weight_kg,scheduled_at,eta,pickup_at,notes,created_at,updated_at)
  select
    ('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'DO-LIVE-'||to_char(current_date,'YYMM')||'-'||lpad(i::text,3,'0'),
    (array['PT Nusantara Retail','PT Indonesia Manufacturing','PT Sumber Pangan Sejahtera','PT Elektronik Global Indonesia','PT Farma Medika Utama','PT Karya Baja Nasional','PT Sentra Niaga Abadi','PT Mitra Otomotif Indonesia'])[((i-1)%8)+1],
    (array['Jakarta Distribution Hub','Tangerang Regional Depot','Bekasi Cross Dock','Karawang Fulfillment Center','Pelabuhan Tanjung Priok'])[((i-1)%5)+1],
    (array['Bekasi DC','Karawang Plant','Cikarang Warehouse','Bogor Distribution Point','Bandung Hub','Tangerang Store Cluster','Depok Fulfillment Point','Cilegon Industrial Estate'])[((i+1)%8)+1],
    'in_transit'::public.order_status,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('30000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array['Produk FMCG — 180 karton','Spare part otomotif — 24 pallet','Material kemasan — 320 roll','Elektronik konsumen — 96 unit','Produk farmasi — 75 boks','Komponen baja — 18 peti','Bahan baku produksi — 12 ton','Peralatan ritel — 140 koli'])[((i-1)%8)+1],
    1200+((i*487)%8800),now()-(40+i*3)*interval '1 minute',now()+(55+i*8)*interval '1 minute',
    now()-(25+i*2)*interval '1 minute','Demo aktif: muatan telah diverifikasi, armada bergerak menuju lokasi delivery.',
    now()-(2+i%5)*interval '1 hour',now()-i*interval '1 minute'
  from generate_series(1,19) i;

  -- Completed trips provide history, POD and reporting scenarios.
  insert into public.orders(id,order_number,customer_name,origin,destination,status,vehicle_id,driver_id,cargo_description,cargo_weight_kg,scheduled_at,eta,pickup_at,delivered_at,pod_url,notes,created_at,updated_at)
  select
    ('50000000-2000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'DO-HIST-'||to_char(current_date,'YYMM')||'-'||lpad(i::text,3,'0'),
    (array['PT Nusantara Retail','PT Indonesia Manufacturing','PT Sumber Pangan Sejahtera','PT Elektronik Global Indonesia'])[((i-1)%4)+1],
    'Jakarta Distribution Hub',(array['Bekasi DC','Karawang Plant','Cikarang Warehouse','Bogor Distribution Point'])[((i-1)%4)+1],
    'delivered'::public.order_status,
    ('40000000-0000-4000-8000-'||lpad((((i+10)%19)+1)::text,12,'0'))::uuid,
    ('30000000-0000-4000-8000-'||lpad((((i+10)%19)+1)::text,12,'0'))::uuid,
    (array['Produk FMCG — 140 karton','Komponen otomotif — 16 pallet','Material kemasan — 210 roll','Peralatan elektronik — 64 unit'])[((i-1)%4)+1],
    950+i*510,now()-i*interval '2 day',now()-i*interval '2 day'+interval '4 hour',now()-i*interval '2 day'+interval '20 minute',
    now()-i*interval '2 day'+interval '3 hour 35 minute','demo/pod/DO-HIST-'||lpad(i::text,3,'0')||'.jpg',
    'Pengantaran selesai, POD dan serah terima telah diverifikasi.',now()-i*interval '2 day',now()-i*interval '2 day'+interval '4 hour'
  from generate_series(1,8) i;

  -- A three-segment route per live delivery; coordinates are unique and remain in the Jabodetabek corridor.
  insert into public.routes(id,order_id,geometry,distance_km,duration_minutes,route_provider,created_at)
  select
    ('51000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    jsonb_build_object('type','LineString','coordinates',jsonb_build_array(
      jsonb_build_array(106.54+(i%5)*.075,-6.12-(i%4)*.055),
      jsonb_build_array(106.66+(i%6)*.073,-6.17-(i%5)*.042),
      jsonb_build_array(106.82+(i%7)*.065,-6.20-(i%4)*.048),
      jsonb_build_array(106.94+(i%6)*.071,-6.24-(i%3)*.052)
    )),32+(i*9%145),70+(i*11%190),'demo-route-v2',now()-i*interval '1 minute'
  from generate_series(1,19) i;

  insert into public.order_waypoints(order_id,sequence,label,latitude,longitude,completed_at)
  select ('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,s,
    case s when 1 then 'Pickup selesai' when 2 then 'Checkpoint perjalanan' else 'Lokasi delivery' end,
    case s when 1 then -6.12-(i%4)*.055 when 2 then -6.17-(i%5)*.042 else -6.24-(i%3)*.052 end,
    case s when 1 then 106.54+(i%5)*.075 when 2 then 106.66+(i%6)*.073 else 106.94+(i%6)*.071 end,
    case when s=1 then now()-(20+i)*interval '1 minute' end
  from generate_series(1,19) i cross join generate_series(1,3) s;

  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'planned','Order dibuat dan divalidasi',demo_user,-6.18,106.84,created_at from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'assigned','Armada dan pengemudi ditugaskan',demo_user,-6.18,106.86,created_at+interval '10 minute' from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'pickup','Muatan diambil dan manifest diverifikasi',demo_user,-6.19,106.88,pickup_at from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'in_transit','Armada bergerak menuju lokasi delivery',demo_user,-6.22,106.94,pickup_at+interval '15 minute' from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'delivered','Barang diterima dan POD terverifikasi',demo_user,-6.27,107.05,delivered_at from public.orders where status='delivered';

  insert into public.gps_positions(vehicle_id,latitude,longitude,speed_kph,heading,recorded_at,source_type,accuracy_m,metadata)
  select ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    -6.13-(i%4)*.045+p*.003,106.57+(i%7)*.067+p*.006,
    case when i<=19 then 32+((i+p)*3%43) else 0 end,(i*19+p*13)%360,
    now()-(6-p)*interval '3 minute'-i*interval '8 second',case when i%4=0 then 'android' else 'gps_device' end,
    3+(i%6),jsonb_build_object('ignition',i<=19,'satellites',9+(i%6),'demo',true,'active_order',i<=19)
  from generate_series(1,20) i cross join generate_series(1,6) p;

  insert into public.operational_funds(id,vehicle_id,order_id,category,amount,status,requested_by,approved_by,description,reviewed_at,settlement_amount,settlement_note,settled_at,created_at,updated_at)
  select ('70000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad((((i-1)%19)+1)::text,12,'0'))::uuid,
    ('50000000-1000-4000-8000-'||lpad((((i-1)%19)+1)::text,12,'0'))::uuid,
    (array['BBM','Tol & Parkir','Uang Makan','Bongkar Muat','Perbaikan Darurat','Penyeberangan'])[((i-1)%6)+1],
    275000+((i*185000)%2600000),case when i<=5 then 'pending'::public.approval_status else 'approved'::public.approval_status end,
    demo_user,case when i>5 then demo_user end,'Dana perjalanan untuk order pengantaran aktif.',case when i>5 then now()-i*interval '12 minute' end,
    case when i between 6 and 14 then 250000+((i*175000)%2400000) end,case when i between 6 and 14 then 'Bukti transaksi lengkap.' end,
    case when i between 6 and 14 then now()-i*interval '8 minute' end,now()-i*interval '45 minute',now()-i*interval '20 minute'
  from generate_series(1,24) i;

  insert into public.field_issues(id,vehicle_id,order_id,title,description,severity,resolved_at,reported_by,status,assigned_to,due_at,resolution,location_lat,location_lng,created_at,updated_at)
  select ('80000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array['Kemacetan berat di jalur utama','Tekanan ban perlu diperiksa','Antrean bongkar muat','GPS sempat terlambat','Perubahan akses pelanggan','Suhu boks perlu inspeksi','Dokumen penerima belum siap','Jalan ditutup sementara'])[((i-1)%8)+1],
    'Temuan operasional terkait perjalanan aktif; tindakan dan SLA tercatat lengkap.',
    (array['medium','high','medium','low','high','critical','low','medium'])[((i-1)%8)+1]::public.issue_severity,
    case when i>8 then now()-i*interval '20 minute' end,demo_user,case when i<=3 then 'reported' when i<=6 then 'in_progress' else 'resolved' end,
    case when i>3 then demo_user end,now()+(i-5)*interval '45 minute',case when i>8 then 'Tindakan korektif selesai dan diverifikasi.' end,
    -6.18-i*.006,106.84+i*.013,now()-i*interval '35 minute',now()-i*interval '15 minute'
  from generate_series(1,12) i;

  insert into public.notifications(company_id,employee_id,user_id,title,message,body,type,kind,is_read,action_link,created_at,read_at)
  select demo_user,demo_user,demo_user,'[DEMO ARAH] '||title,message,message,type,lower(type),false,'/',now()-i*interval '18 minute',null
  from (values
    (1,'19 armada sedang berjalan','95% armada memiliki order pengantaran aktif.','ORDER'),
    (2,'Armada cadangan tersedia','B 8899 JKL siap menerima assignment baru.','FLEET'),
    (3,'Traffic alert','Kepadatan tinggi terdeteksi pada koridor Cikampek.','TRAFFIC'),
    (4,'Dana operasional menunggu review','Lima pengajuan dana perjalanan menunggu persetujuan.','APPROVAL'),
    (5,'Issue SLA perlu perhatian','Tiga issue perjalanan aktif membutuhkan respons dispatcher.','WARNING'),
    (6,'GPS seluruh armada aktif','Dua puluh perangkat GPS mengirim telemetry terbaru.','GPS')
  ) n(i,title,message,type);
end $$;
