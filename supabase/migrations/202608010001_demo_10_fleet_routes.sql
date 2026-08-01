-- ARAH Demo v3: 10 fleets only.
-- 5 fleets: Gudang Bandara (Soekarno-Hatta) → random areas in Tangerang, Depok, Bogor
-- 5 fleets: Gudang Tanjung Priok → random areas in Cikarang, Karawang, Semarang, Bandung
-- Removes the previous 20-fleet operational seed.

do $$
declare
  demo_user uuid;
begin
  select id into demo_user from auth.users where lower(email)='demo@arah.id' limit 1;
  if demo_user is null then raise exception 'Akun demo@arah.id belum tersedia'; end if;

  -- Wipe operational demo data (dependency order).
  delete from public.notifications where user_id=demo_user or title like '[DEMO ARAH]%';
  if to_regclass('public.operation_attachments') is not null then
    execute 'delete from public.operation_attachments where entity_type in (''order_pod'',''order_manifest'',''fund_receipt'',''issue_evidence'',''vehicle_document'',''driver_document'',''vendor_document'')';
  end if;
  if to_regclass('public.vehicle_history') is not null then
    execute 'delete from public.vehicle_history';
  end if;
  if to_regclass('public.trip_communications') is not null then
    execute 'delete from public.trip_communications';
  end if;
  if to_regclass('public.cctv_devices') is not null then
    execute 'delete from public.cctv_devices';
  end if;
  if to_regclass('public.vehicle_health_checks') is not null then
    execute 'delete from public.vehicle_health_checks';
  end if;
  if to_regclass('public.geofence_vehicle_state') is not null then
    execute 'delete from public.geofence_vehicle_state';
  end if;
  delete from public.geofence_events;
  delete from public.order_waypoints;
  delete from public.order_events;
  delete from public.routes;
  delete from public.gps_positions;
  delete from public.gps_devices;
  delete from public.maintenance_records;
  delete from public.field_issues;
  delete from public.operational_funds;
  delete from public.orders;
  delete from public.vehicles;
  delete from public.drivers;
  delete from public.vendors;
  delete from public.geofences;
  delete from public.branches;

  -- Master: two origin warehouses + destination coverage branches.
  insert into public.branches(id,code,name,address,latitude,longitude,active) values
    ('10000000-0000-4000-8000-000000000001','CGK','Gudang Bandara Soekarno-Hatta','Kawasan Kargo Bandara Soekarno-Hatta, Tangerang',-6.1256,106.6559,true),
    ('10000000-0000-4000-8000-000000000002','TJP','Gudang Tanjung Priok','Pelabuhan Tanjung Priok, Jakarta Utara',-6.1047,106.8819,true),
    ('10000000-0000-4000-8000-000000000003','TGR','Tangerang Delivery Zone','Area Tangerang & sekitarnya',-6.1783,106.6319,true),
    ('10000000-0000-4000-8000-000000000004','DPK','Depok Delivery Zone','Area Depok & sekitarnya',-6.4025,106.7942,true),
    ('10000000-0000-4000-8000-000000000005','BGR','Bogor Delivery Zone','Area Bogor & sekitarnya',-6.5971,106.8060,true),
    ('10000000-0000-4000-8000-000000000006','CKR','Cikarang Delivery Zone','Kawasan Industri Cikarang',-6.3034,107.1647,true),
    ('10000000-0000-4000-8000-000000000007','KRW','Karawang Delivery Zone','KIIC / Karawang Timur',-6.3269,107.3007,true),
    ('10000000-0000-4000-8000-000000000008','SMG','Semarang Delivery Zone','Semarang & sekitarnya',-6.9667,110.4167,true),
    ('10000000-0000-4000-8000-000000000009','BDG','Bandung Delivery Zone','Bandung & sekitarnya',-6.9175,107.6191,true);

  insert into public.vendors(id,name,contact_name,phone,email,status) values
    ('20000000-0000-4000-8000-000000000001','PT Lintas Kargo Nusantara','Andri Firmansyah','021-555-0101','operasional@lintaskargo.demo','active'),
    ('20000000-0000-4000-8000-000000000002','PT Trans Logistik Indonesia','Maya Kusuma','021-555-0102','fleet@translog.demo','active');

  -- 10 drivers (all assigned).
  insert into public.drivers(id,employee_number,full_name,phone,license_number,license_expiry,status,vendor_id,branch_id,photo_url,created_at,updated_at)
  select
    ('30000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'DRV-'||lpad(i::text,3,'0'),
    (array['Budi Santoso','Raka Pratama','Agus Setiawan','Dedi Kurniawan','Fajar Hidayat','Hendra Saputra','Irfan Maulana','Joko Susilo','Andi Wijaya','Bayu Ramadhan'])[i],
    '0812'||lpad((11000000+i)::text,8,'0'),
    'B1-'||lpad((260000+i)::text,6,'0'),
    current_date + (180+i*12),
    'assigned',
    ('20000000-0000-4000-8000-'||lpad(case when i<=5 then 1 else 2 end::text,12,'0'))::uuid,
    ('10000000-0000-4000-8000-'||lpad(case when i<=5 then 1 else 2 end::text,12,'0'))::uuid,
    'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=300&q=80',
    now()-interval '90 days'+i*interval '1 day',
    now()-i*interval '20 minutes'
  from generate_series(1,10) i;

  -- Destinations (deterministic “random” areas).
  -- i=1..5: Bandara → Tangerang / Depok / Bogor
  -- i=6..10: Tanjung Priok → Cikarang / Karawang / Semarang / Bandung
  -- Columns via temp-style arrays in SELECT.

  insert into public.vehicles(
    id,plate_number,vehicle_type,status,driver_name,driver_id,fuel_percent,
    last_lat,last_lng,last_gps_at,capacity_kg,odometer_km,registration_expiry,
    branch_id,vendor_id,brand,model,year,vendor_name,photo_url,device_status,created_at
  )
  select
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array['B 9127 UYT','B 8831 KXR','B 9402 TXZ','B 7654 KLM','B 8210 VRA','B 9321 NQS','B 7088 PHA','B 8567 ZKD','B 9012 RFS','B 7745 MNT'])[i],
    (array['CDD Box','Fuso Box','Colt Diesel Engkel','Tronton Wingbox','Reefer Truck','CDD Box','Fuso Box','Tronton Wingbox','Colt Diesel Engkel','Reefer Truck'])[i],
    'in_transit'::public.vehicle_status,
    (array['Budi Santoso','Raka Pratama','Agus Setiawan','Dedi Kurniawan','Fajar Hidayat','Hendra Saputra','Irfan Maulana','Joko Susilo','Andi Wijaya','Bayu Ramadhan'])[i],
    ('30000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    48+((i*7)%45),
    -- mid-route position between origin and destination
    (array[
      -6.1450,-6.1600,-6.2500,-6.2800,-6.3600,  -- bandara corridor south/west
      -6.1800,-6.2000,-6.4500,-6.5200,-6.2100   -- priok corridor east/south
    ])[i],
    (array[
      106.6400,106.6200,106.7200,106.7600,106.7800,
      107.0200,107.1000,108.6000,107.3000,107.0500
    ])[i],
    now()-i*interval '12 seconds',
    (array[2200,5000,3500,12000,7000,2200,5000,12000,3500,7000])[i],
    48000+i*3175,
    current_date+180+i*7,
    ('10000000-0000-4000-8000-'||lpad(case when i<=5 then 1 else 2 end::text,12,'0'))::uuid,
    ('20000000-0000-4000-8000-'||lpad(case when i<=5 then 1 else 2 end::text,12,'0'))::uuid,
    (array['Hino','Isuzu','Mitsubishi Fuso','UD Trucks','Toyota','Hino','Isuzu','UD Trucks','Mitsubishi Fuso','Toyota'])[i],
    (array['Dutro 130 HD','Elf NMR 71','Canter FE 74','Quester CWE','Dyna 136 HT','Dutro 130 HD','Elf NMR 71','Quester CWE','Canter FE 74','Dyna 136 HT'])[i],
    2020+(i%6),
    case when i<=5 then 'PT Lintas Kargo Nusantara' else 'PT Trans Logistik Indonesia' end,
    'https://images.unsplash.com/photo-1586191582151-f73872dfd183?auto=format&fit=crop&w=900&q=80',
    'online',
    now()-interval '120 days'+i*interval '2 days'
  from generate_series(1,10) i;

  -- 10 live in-transit orders with explicit origin/destination labels.
  insert into public.orders(
    id,order_number,customer_name,origin,destination,status,vehicle_id,driver_id,
    cargo_description,cargo_weight_kg,scheduled_at,eta,pickup_at,notes,created_at,updated_at,
    cargo_category,cargo_quantity,cargo_unit,cargo_volume_m3,declared_value,
    handling_instructions,pickup_pic,recipient_pic,document_url
  )
  select
    ('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'DO-LIVE-'||to_char(current_date,'YYMM')||'-'||lpad(i::text,3,'0'),
    (array[
      'PT Nusantara Retail','PT Indonesia Manufacturing','PT Sumber Pangan Sejahtera',
      'PT Elektronik Global Indonesia','PT Farma Medika Utama','PT Karya Baja Nasional',
      'PT Sentra Niaga Abadi','PT Mitra Otomotif Indonesia','PT Logistik Prima Jaya','PT Distribusi Cepat Nusantara'
    ])[i],
    case when i<=5 then 'Gudang Bandara Soekarno-Hatta' else 'Gudang Tanjung Priok' end,
    (array[
      'Tangerang — BSD City Cluster',
      'Tangerang — Cikokol Industrial',
      'Depok — Margonda Retail Hub',
      'Depok — Cimanggis Warehouse',
      'Bogor — Baranangsiang DC',
      'Cikarang — MM2100 Warehouse',
      'Karawang — KIIC Plant',
      'Semarang — Kaligawe DC',
      'Bandung — Rancaekek Industrial',
      'Cikarang — Jababeka Estate'
    ])[i],
    'in_transit'::public.order_status,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('30000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array[
      'Produk FMCG — 180 karton','Spare part otomotif — 24 pallet','Material kemasan — 320 roll',
      'Elektronik konsumen — 96 unit','Produk farmasi — 75 boks','Komponen baja — 18 peti',
      'Bahan baku produksi — 12 ton','Peralatan ritel — 140 koli','Suku cadang mesin — 40 crate',
      'Barang e-commerce — 220 koli'
    ])[i],
    1200+((i*487)%8800),
    now()-(40+i*3)*interval '1 minute',
    now()+(55+i*12)*interval '1 minute',
    now()-(25+i*2)*interval '1 minute',
    'Demo aktif: muatan diverifikasi di gudang asal, armada menuju area tujuan.',
    now()-(2+i%5)*interval '1 hour',
    now()-i*interval '1 minute',
    (array['FMCG','Otomotif','Kemasan','Elektronik','Farmasi','Material Industri','Bahan Baku','Retail Equipment','Spare Part','E-Commerce'])[i],
    40+i*7,
    (array['karton','pallet','roll','unit','boks','peti','ton','koli','crate','koli'])[i],
    8+(i*1.35),
    75000000+(i*27500000),
    case when i%5=0 then array['Temperature Controlled','Fragile'] when i%3=0 then array['Fragile','Keep Dry'] else array['Segel wajib utuh','Dilarang ditumpuk berlebih'] end,
    'Andi Pratama · 0812-8800-'||lpad(i::text,4,'0'),
    'Siti Rahma · 0813-9900-'||lpad(i::text,4,'0'),
    'https://arah-app-delta.vercel.app/'
  from generate_series(1,10) i;

  -- A few historical deliveries for reporting (using same 10 fleets).
  insert into public.orders(
    id,order_number,customer_name,origin,destination,status,vehicle_id,driver_id,
    cargo_description,cargo_weight_kg,scheduled_at,eta,pickup_at,delivered_at,pod_url,notes,created_at,updated_at
  )
  select
    ('50000000-2000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'DO-HIST-'||to_char(current_date,'YYMM')||'-'||lpad(i::text,3,'0'),
    (array['PT Nusantara Retail','PT Indonesia Manufacturing','PT Sumber Pangan Sejahtera','PT Elektronik Global Indonesia'])[((i-1)%4)+1],
    case when i%2=0 then 'Gudang Bandara Soekarno-Hatta' else 'Gudang Tanjung Priok' end,
    (array['Tangerang — BSD City Cluster','Depok — Margonda Retail Hub','Bogor — Baranangsiang DC','Cikarang — MM2100 Warehouse'])[((i-1)%4)+1],
    'delivered'::public.order_status,
    ('40000000-0000-4000-8000-'||lpad((((i-1)%10)+1)::text,12,'0'))::uuid,
    ('30000000-0000-4000-8000-'||lpad((((i-1)%10)+1)::text,12,'0'))::uuid,
    (array['Produk FMCG — 140 karton','Komponen otomotif — 16 pallet','Material kemasan — 210 roll','Peralatan elektronik — 64 unit'])[((i-1)%4)+1],
    950+i*510,
    now()-i*interval '2 day',
    now()-i*interval '2 day'+interval '4 hour',
    now()-i*interval '2 day'+interval '20 minute',
    now()-i*interval '2 day'+interval '3 hour 35 minute',
    'demo/pod/DO-HIST-'||lpad(i::text,3,'0')||'.jpg',
    'Pengantaran selesai, POD dan serah terima telah diverifikasi.',
    now()-i*interval '2 day',
    now()-i*interval '2 day'+interval '4 hour'
  from generate_series(1,6) i;

  -- Routes: origin → mid checkpoints → destination (GeoJSON lon,lat).
  -- Origins: Bandara (106.6559,-6.1256) | Priok (106.8819,-6.1047)
  insert into public.routes(id,order_id,geometry,distance_km,duration_minutes,route_provider,created_at)
  select
    ('51000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    jsonb_build_object('type','LineString','coordinates',
      case i
        -- Bandara → Tangerang BSD
        when 1 then jsonb_build_array(
          jsonb_build_array(106.6559,-6.1256),jsonb_build_array(106.6400,-6.1450),
          jsonb_build_array(106.6200,-6.1700),jsonb_build_array(106.6650,-6.3020))
        -- Bandara → Tangerang Cikokol
        when 2 then jsonb_build_array(
          jsonb_build_array(106.6559,-6.1256),jsonb_build_array(106.6300,-6.1500),
          jsonb_build_array(106.6100,-6.1750),jsonb_build_array(106.6305,-6.1850))
        -- Bandara → Depok Margonda
        when 3 then jsonb_build_array(
          jsonb_build_array(106.6559,-6.1256),jsonb_build_array(106.7000,-6.2200),
          jsonb_build_array(106.7600,-6.3200),jsonb_build_array(106.8320,-6.3920))
        -- Bandara → Depok Cimanggis
        when 4 then jsonb_build_array(
          jsonb_build_array(106.6559,-6.1256),jsonb_build_array(106.7200,-6.2400),
          jsonb_build_array(106.8000,-6.3400),jsonb_build_array(106.8700,-6.3700))
        -- Bandara → Bogor Baranangsiang
        when 5 then jsonb_build_array(
          jsonb_build_array(106.6559,-6.1256),jsonb_build_array(106.7400,-6.2800),
          jsonb_build_array(106.7900,-6.4500),jsonb_build_array(106.8060,-6.5971))
        -- Priok → Cikarang MM2100
        when 6 then jsonb_build_array(
          jsonb_build_array(106.8819,-6.1047),jsonb_build_array(106.9800,-6.1800),
          jsonb_build_array(107.0800,-6.2500),jsonb_build_array(107.1647,-6.3034))
        -- Priok → Karawang KIIC
        when 7 then jsonb_build_array(
          jsonb_build_array(106.8819,-6.1047),jsonb_build_array(107.0200,-6.2000),
          jsonb_build_array(107.1800,-6.2800),jsonb_build_array(107.3007,-6.3269))
        -- Priok → Semarang Kaligawe
        when 8 then jsonb_build_array(
          jsonb_build_array(106.8819,-6.1047),jsonb_build_array(107.5000,-6.3000),
          jsonb_build_array(108.8000,-6.7000),jsonb_build_array(110.4167,-6.9667))
        -- Priok → Bandung Rancaekek
        when 9 then jsonb_build_array(
          jsonb_build_array(106.8819,-6.1047),jsonb_build_array(107.1000,-6.3500),
          jsonb_build_array(107.4000,-6.7000),jsonb_build_array(107.6500,-6.9600))
        -- Priok → Cikarang Jababeka
        else jsonb_build_array(
          jsonb_build_array(106.8819,-6.1047),jsonb_build_array(106.9900,-6.1900),
          jsonb_build_array(107.0900,-6.2600),jsonb_build_array(107.1400,-6.2900))
      end
    ),
    (array[42,28,55,52,78,48,62,440,165,45])[i],
    (array[85,55,110,105,150,95,120,520,210,90])[i],
    'demo-route-v3',
    now()-i*interval '1 minute'
  from generate_series(1,10) i;

  insert into public.order_waypoints(order_id,sequence,label,latitude,longitude,completed_at)
  select
    ('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    s,
    case s when 1 then 'Pickup gudang selesai' when 2 then 'Checkpoint perjalanan' else 'Lokasi delivery' end,
    case i
      when 1 then (array[-6.1256,-6.1450,-6.3020])[s]
      when 2 then (array[-6.1256,-6.1600,-6.1850])[s]
      when 3 then (array[-6.1256,-6.2500,-6.3920])[s]
      when 4 then (array[-6.1256,-6.2800,-6.3700])[s]
      when 5 then (array[-6.1256,-6.3600,-6.5971])[s]
      when 6 then (array[-6.1047,-6.1800,-6.3034])[s]
      when 7 then (array[-6.1047,-6.2000,-6.3269])[s]
      when 8 then (array[-6.1047,-6.4500,-6.9667])[s]
      when 9 then (array[-6.1047,-6.5200,-6.9600])[s]
      else (array[-6.1047,-6.2100,-6.2900])[s]
    end,
    case i
      when 1 then (array[106.6559,106.6400,106.6650])[s]
      when 2 then (array[106.6559,106.6200,106.6305])[s]
      when 3 then (array[106.6559,106.7200,106.8320])[s]
      when 4 then (array[106.6559,106.7600,106.8700])[s]
      when 5 then (array[106.6559,106.7800,106.8060])[s]
      when 6 then (array[106.8819,107.0200,107.1647])[s]
      when 7 then (array[106.8819,107.1000,107.3007])[s]
      when 8 then (array[106.8819,108.6000,110.4167])[s]
      when 9 then (array[106.8819,107.3000,107.6500])[s]
      else (array[106.8819,107.0500,107.1400])[s]
    end,
    case when s=1 then now()-(20+i)*interval '1 minute' end
  from generate_series(1,10) i
  cross join generate_series(1,3) s;

  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'planned','Order dibuat dan divalidasi',demo_user,
    case when origin like '%Bandara%' then -6.1256 else -6.1047 end,
    case when origin like '%Bandara%' then 106.6559 else 106.8819 end,
    created_at from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'assigned','Armada dan pengemudi ditugaskan',demo_user,
    case when origin like '%Bandara%' then -6.1256 else -6.1047 end,
    case when origin like '%Bandara%' then 106.6559 else 106.8819 end,
    created_at+interval '10 minute' from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'pickup','Muatan diambil di gudang asal dan manifest diverifikasi',demo_user,
    case when origin like '%Bandara%' then -6.1256 else -6.1047 end,
    case when origin like '%Bandara%' then 106.6559 else 106.8819 end,
    pickup_at from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'in_transit','Armada bergerak menuju area tujuan',demo_user,
    case when origin like '%Bandara%' then -6.1450 else -6.1800 end,
    case when origin like '%Bandara%' then 106.6400 else 107.0200 end,
    pickup_at+interval '15 minute' from public.orders;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select id,'delivered','Barang diterima dan POD terverifikasi',demo_user,-6.27,107.05,delivered_at
  from public.orders where status='delivered';

  insert into public.gps_devices(id,vehicle_id,device_code,token_hash,active,last_seen_at,source_type,created_at)
  select
    ('60000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'ARAH-GPS-'||lpad(i::text,3,'0'),
    encode(digest('demo-device-'||i,'sha256'),'hex'),
    true,
    now()-i*interval '1 minute',
    case when i%4=0 then 'android' else 'gps_device' end,
    now()-interval '60 days'
  from generate_series(1,10) i;

  insert into public.gps_positions(vehicle_id,latitude,longitude,speed_kph,heading,recorded_at,source_type,accuracy_m,metadata)
  select
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array[-6.1450,-6.1600,-6.2500,-6.2800,-6.3600,-6.1800,-6.2000,-6.4500,-6.5200,-6.2100])[i]+p*.0025,
    (array[106.6400,106.6200,106.7200,106.7600,106.7800,107.0200,107.1000,108.6000,107.3000,107.0500])[i]+p*.004,
    32+((i+p)*3%43),
    (i*19+p*13)%360,
    now()-(6-p)*interval '3 minute'-i*interval '8 second',
    case when i%4=0 then 'android' else 'gps_device' end,
    3+(i%6),
    jsonb_build_object('ignition',true,'satellites',9+(i%6),'demo',true,'active_order',true,'corridor',case when i<=5 then 'bandara-south' else 'priok-east' end)
  from generate_series(1,10) i
  cross join generate_series(1,6) p;

  insert into public.operational_funds(id,vehicle_id,order_id,category,amount,status,requested_by,approved_by,description,reviewed_at,settlement_amount,settlement_note,settled_at,created_at,updated_at)
  select
    ('70000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad((((i-1)%10)+1)::text,12,'0'))::uuid,
    ('50000000-1000-4000-8000-'||lpad((((i-1)%10)+1)::text,12,'0'))::uuid,
    (array['BBM','Tol & Parkir','Uang Makan','Bongkar Muat','Perbaikan Darurat','Penyeberangan'])[((i-1)%6)+1],
    275000+((i*185000)%2600000),
    case when i<=3 then 'pending'::public.approval_status else 'approved'::public.approval_status end,
    demo_user,
    case when i>3 then demo_user end,
    'Dana perjalanan untuk order pengantaran aktif (10 fleet demo).',
    case when i>3 then now()-i*interval '12 minute' end,
    case when i between 4 and 8 then 250000+((i*175000)%2400000) end,
    case when i between 4 and 8 then 'Bukti transaksi lengkap.' end,
    case when i between 4 and 8 then now()-i*interval '8 minute' end,
    now()-i*interval '45 minute',
    now()-i*interval '20 minute'
  from generate_series(1,10) i;

  insert into public.field_issues(id,vehicle_id,order_id,title,description,severity,resolved_at,reported_by,status,assigned_to,due_at,resolution,location_lat,location_lng,created_at,updated_at)
  select
    ('80000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('50000000-1000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array['Kemacetan berat di jalur utama','Tekanan ban perlu diperiksa','Antrean bongkar muat','GPS sempat terlambat','Perubahan akses pelanggan','Suhu boks perlu inspeksi','Dokumen penerima belum siap','Jalan ditutup sementara'])[((i-1)%8)+1],
    'Temuan operasional terkait perjalanan aktif; tindakan dan SLA tercatat lengkap.',
    (array['medium','high','medium','low','high','critical','low','medium'])[((i-1)%8)+1]::public.issue_severity,
    case when i>6 then now()-i*interval '20 minute' end,
    demo_user,
    case when i<=2 then 'reported' when i<=5 then 'in_progress' else 'resolved' end,
    case when i>2 then demo_user end,
    now()+(i-5)*interval '45 minute',
    case when i>6 then 'Tindakan korektif selesai dan diverifikasi.' end,
    (array[-6.1450,-6.1600,-6.2500,-6.2800,-6.3600,-6.1800,-6.2000,-6.4500,-6.5200,-6.2100])[i],
    (array[106.6400,106.6200,106.7200,106.7600,106.7800,107.0200,107.1000,108.6000,107.3000,107.0500])[i],
    now()-i*interval '35 minute',
    now()-i*interval '15 minute'
  from generate_series(1,8) i;

  insert into public.geofences(id,name,kind,latitude,longitude,radius_meters,active) values
    ('90000000-0000-4000-8000-000000000001','Gudang Bandara Soekarno-Hatta','depot',-6.1256,106.6559,800,true),
    ('90000000-0000-4000-8000-000000000002','Gudang Tanjung Priok','port',-6.1047,106.8819,1000,true),
    ('90000000-0000-4000-8000-000000000003','Tangerang BSD Delivery','customer',-6.3020,106.6650,350,true),
    ('90000000-0000-4000-8000-000000000004','Depok Margonda Delivery','customer',-6.3920,106.8320,300,true),
    ('90000000-0000-4000-8000-000000000005','Bogor Baranangsiang Delivery','customer',-6.5971,106.8060,350,true),
    ('90000000-0000-4000-8000-000000000006','Cikarang MM2100 Delivery','customer',-6.3034,107.1647,400,true),
    ('90000000-0000-4000-8000-000000000007','Karawang KIIC Delivery','customer',-6.3269,107.3007,400,true),
    ('90000000-0000-4000-8000-000000000008','Semarang Kaligawe Delivery','customer',-6.9667,110.4167,450,true),
    ('90000000-0000-4000-8000-000000000009','Bandung Rancaekek Delivery','customer',-6.9600,107.6500,400,true);

  insert into public.geofence_events(geofence_id,vehicle_id,event_type,latitude,longitude,recorded_at)
  select
    ('90000000-0000-4000-8000-'||lpad(case when i<=5 then 1 else 2 end::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'exit',
    case when i<=5 then -6.1256 else -6.1047 end,
    case when i<=5 then 106.6559 else 106.8819 end,
    now()-(30+i)*interval '1 minute'
  from generate_series(1,10) i;

  insert into public.maintenance_records(id,vehicle_id,maintenance_type,scheduled_at,completed_at,odometer_km,cost,notes,created_at)
  select
    ('91000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array['Servis berkala','Penggantian oli dan filter','Inspeksi sistem rem','Rotasi dan balancing ban','Pemeriksaan pendingin boks'])[((i-1)%5)+1],
    now()+(i-4)*interval '3 day',
    case when i<=3 then now()-(4-i)*interval '5 day' end,
    52000+i*2900,
    750000+i*185000,
    'Catatan maintenance untuk 10 fleet demo.',
    now()-(10-i)*interval '7 day'
  from generate_series(1,6) i;

  if to_regclass('public.vehicle_health_checks') is not null then
    insert into public.vehicle_health_checks(vehicle_id,component,status,value,last_checked_at,next_due_at,notes)
    select v.id,c.component,
      case when right(v.id::text,2)::int in (3,7) and c.component in ('tires','brakes') then 'warning' else 'ok' end,
      case c.component
        when 'service' then 'Service terakhir 6.000 km lalu'
        when 'engine_oil' then 'Level 82% · SAE 15W-40'
        when 'tires' then 'Tekanan 92–98 PSI'
        when 'brakes' then 'Kampas 68%'
        when 'battery' then '12,6 V · sehat'
        when 'vehicle_tax' then 'Aktif'
        when 'stnk' then 'Dokumen tersedia'
        when 'kir' then 'Lulus uji'
        when 'insurance' then 'All Risk'
        when 'gps_cctv' then 'GPS + dual camera'
        else 'APAR 3 kg & P3K lengkap'
      end,
      now()-(right(v.id::text,2)::int%10)*interval '1 day',
      now()+interval '45 day',
      'Checklist Demo 10 fleet'
    from public.vehicles v
    cross join (values('service'),('engine_oil'),('tires'),('brakes'),('battery'),('vehicle_tax'),('stnk'),('kir'),('insurance'),('gps_cctv'),('safety_kit')) c(component)
    where v.id::text like '40000000-0000-4000-8000-%';
  end if;

  if to_regclass('public.cctv_devices') is not null then
    insert into public.cctv_devices(vehicle_id,camera_name,camera_position,status,last_seen_at,firmware_version)
    select v.id,'Kamera Depan','front','online',now()-right(v.id::text,2)::int*interval '5 second','ARAH-CAM 2.4.1'
    from public.vehicles v where v.id::text like '40000000-0000-4000-8000-%'
    union all
    select v.id,'Kamera Kabin','cabin','online',now()-right(v.id::text,2)::int*interval '6 second','ARAH-CAM 2.4.1'
    from public.vehicles v where v.id::text like '40000000-0000-4000-8000-%';
  end if;

  if to_regclass('public.trip_communications') is not null then
    insert into public.trip_communications(vehicle_id,order_id,sender_id,sender_type,channel,message,created_at,read_at)
    select o.vehicle_id,o.id,demo_user,'dispatcher','in_app','Konfirmasi posisi dan kondisi muatan.',now()-right(o.vehicle_id::text,2)::int*interval '7 minute',now()-right(o.vehicle_id::text,2)::int*interval '6 minute'
    from public.orders o where o.status='in_transit' and o.order_number like 'DO-LIVE-%'
    union all
    select o.vehicle_id,o.id,null,'driver','in_app','Posisi aman, muatan dan segel dalam kondisi baik.',now()-right(o.vehicle_id::text,2)::int*interval '6 minute',now()-right(o.vehicle_id::text,2)::int*interval '5 minute'
    from public.orders o where o.status='in_transit' and o.order_number like 'DO-LIVE-%';
  end if;

  if to_regclass('public.vehicle_history') is not null then
    insert into public.vehicle_history(vehicle_id,order_id,event_type,title,description,cost,downtime_minutes,occurred_at,resolved_at,pic_name)
    select v.id,null,'maintenance','Service berkala selesai','Penggantian oli, filter, dan pemeriksaan 21 titik.',1250000+(right(v.id::text,2)::int*75000),180,now()-interval '45 day'-right(v.id::text,2)::int*interval '1 day',now()-interval '45 day','Budi Santoso'
    from public.vehicles v where v.id::text like '40000000-0000-4000-8000-%'
    union all
    select o.vehicle_id,o.id,'trip','Order pengantaran dimulai',o.origin||' menuju '||o.destination,null,null,o.pickup_at,null,'Dispatcher ARAH'
    from public.orders o where o.status='in_transit' and o.order_number like 'DO-LIVE-%';
  end if;

  insert into public.notifications(company_id,employee_id,user_id,title,message,body,type,kind,is_read,action_link,created_at,read_at)
  select demo_user,demo_user,demo_user,'[DEMO ARAH] '||title,message,message,type,lower(type),false,'/',now()-i*interval '18 minute',null
  from (values
    (1,'10 armada sedang berjalan','5 dari Gudang Bandara (Tangerang/Depok/Bogor) + 5 dari Tanjung Priok (Cikarang/Karawang/Semarang/Bandung).','ORDER'),
    (2,'Koridor Bandara aktif','5 fleet berangkat dari Gudang Bandara Soekarno-Hatta.','FLEET'),
    (3,'Koridor Tanjung Priok aktif','5 fleet berangkat dari Gudang Tanjung Priok.','FLEET'),
    (4,'Traffic alert','Pantau kepadatan di koridor Cikampek dan Puncak.','TRAFFIC'),
    (5,'Dana operasional menunggu review','Tiga pengajuan dana perjalanan menunggu persetujuan.','APPROVAL'),
    (6,'GPS seluruh armada aktif','Sepuluh perangkat GPS mengirim telemetry terbaru.','GPS')
  ) n(i,title,message,type);
end $$;
