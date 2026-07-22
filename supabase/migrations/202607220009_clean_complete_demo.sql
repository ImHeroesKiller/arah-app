-- ARAH clean, deterministic and presentation-ready demo dataset.
-- Replaces the previous operational seed only; auth users, profiles, settings and audit logs are preserved.

-- Compatibility with the legacy notifications table that shares this Supabase project.
alter table public.notifications add column if not exists body text;
alter table public.notifications add column if not exists kind text not null default 'info';
alter table public.operational_funds add column if not exists updated_at timestamptz not null default now();

do $$
declare
  demo_user uuid;
begin
  select id into demo_user from auth.users where lower(email)='demo@arah.id' limit 1;
  if demo_user is null then raise exception 'Akun demo@arah.id belum tersedia'; end if;

  -- Remove the previous ARAH operational seed in dependency order.
  delete from public.notifications where user_id=demo_user or title like '[DEMO ARAH]%';
  if to_regclass('public.operation_attachments') is not null then
    execute 'delete from public.operation_attachments where entity_type in (''order_pod'',''order_manifest'',''fund_receipt'',''issue_evidence'',''vehicle_document'',''driver_document'',''vendor_document'')';
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

  insert into public.branches(id,code,name,address,latitude,longitude,active) values
    ('10000000-0000-4000-8000-000000000001','JKT','Jakarta Distribution Hub','Jl. Raya Cakung Cilincing, Jakarta Timur',-6.1850,106.9470,true),
    ('10000000-0000-4000-8000-000000000002','TGR','Tangerang Regional Depot','Jl. Raya Serang KM 24, Balaraja',-6.1990,106.5190,true),
    ('10000000-0000-4000-8000-000000000003','BKS','Bekasi Cross Dock','Kawasan Industri MM2100, Cibitung',-6.3101,107.0927,true),
    ('10000000-0000-4000-8000-000000000004','KRW','Karawang Fulfillment Center','KIIC, Telukjambe Timur, Karawang',-6.3667,107.3026,true),
    ('10000000-0000-4000-8000-000000000005','SBY','Surabaya East Java Hub','Rungkut Industri, Surabaya',-7.3305,112.7649,true);

  insert into public.vendors(id,name,contact_name,phone,email,status) values
    ('20000000-0000-4000-8000-000000000001','PT Lintas Kargo Nusantara','Andri Firmansyah','021-555-0101','operasional@lintaskargo.demo','active'),
    ('20000000-0000-4000-8000-000000000002','PT Trans Logistik Indonesia','Maya Kusuma','021-555-0102','fleet@translog.demo','active'),
    ('20000000-0000-4000-8000-000000000003','PT Cakra Distribusi Mandiri','Dimas Prakoso','021-555-0103','dispatch@cakradistribusi.demo','active'),
    ('20000000-0000-4000-8000-000000000004','PT Prima Angkutan Sejahtera','Sari Wulandari','031-555-0104','ops@primaangkutan.demo','active');

  insert into public.drivers(id,employee_number,full_name,phone,license_number,license_expiry,status,vendor_id,branch_id,created_at,updated_at)
  select
    ('30000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    'DRV-'||lpad(i::text,3,'0'),
    (array['Budi Santoso','Raka Pratama','Agus Setiawan','Dedi Kurniawan','Fajar Hidayat','Hendra Saputra','Irfan Maulana','Joko Susilo','Andi Wijaya','Bayu Ramadhan','Rizky Firmansyah','Wahyu Nugroho','Yusuf Permana','Arief Rahman','Doni Hermawan','Eko Prasetyo','Gilang Mahendra','Nanda Saputra','Taufik Akbar','Zainal Abidin'])[i],
    '0812'||lpad((11000000+i)::text,8,'0'), 'B1-'||lpad((260000+i)::text,6,'0'),
    current_date + (180+i*12), case when i<=12 then 'assigned' when i<=17 then 'available' when i<=19 then 'off_duty' else 'suspended' end,
    ('20000000-0000-4000-8000-'||lpad((((i-1)%4)+1)::text,12,'0'))::uuid,
    ('10000000-0000-4000-8000-'||lpad((((i-1)%5)+1)::text,12,'0'))::uuid,
    now()-interval '90 days'+i*interval '1 day', now()-i*interval '20 minutes'
  from generate_series(1,20) i;

  insert into public.vehicles(id,plate_number,vehicle_type,status,driver_name,driver_id,fuel_percent,last_lat,last_lng,last_gps_at,capacity_kg,odometer_km,registration_expiry,branch_id,vendor_id,created_at)
  select
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    (array['B 9127 UYT','B 8831 KXR','B 9402 TXZ','B 7654 KLM','B 8210 VRA','B 9321 NQS','B 7088 PHA','B 8567 ZKD','B 9012 RFS','B 7745 MNT','B 8456 JKU','B 9901 WED','B 7134 GHY','B 8678 LOP','B 9234 CBN','B 7890 QAZ','B 8345 XCV','B 9567 ASD','B 7456 FGH','B 8899 JKL'])[i],
    (array['CDD Box','Fuso Box','Colt Diesel Engkel','Tronton Wingbox','Reefer Truck'])[((i-1)%5)+1],
    case when i<=9 then 'in_transit'::public.vehicle_status when i<=15 then 'available'::public.vehicle_status when i<=18 then 'maintenance'::public.vehicle_status else 'offline'::public.vehicle_status end,
    (array['Budi Santoso','Raka Pratama','Agus Setiawan','Dedi Kurniawan','Fajar Hidayat','Hendra Saputra','Irfan Maulana','Joko Susilo','Andi Wijaya','Bayu Ramadhan','Rizky Firmansyah','Wahyu Nugroho','Yusuf Permana','Arief Rahman','Doni Hermawan','Eko Prasetyo','Gilang Mahendra','Nanda Saputra','Taufik Akbar','Zainal Abidin'])[i],
    ('30000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    38+((i*7)%59), -6.175-(i%8)*0.036, 106.84+(i%10)*0.045,
    case when i<=18 then now()-i*interval '1 minute' else now()-i*interval '2 hour' end,
    (array[2200,5000,3500,12000,7000])[((i-1)%5)+1], 48000+i*3175,
    current_date+180+i*7,
    ('10000000-0000-4000-8000-'||lpad((((i-1)%5)+1)::text,12,'0'))::uuid,
    ('20000000-0000-4000-8000-'||lpad((((i-1)%4)+1)::text,12,'0'))::uuid,
    now()-interval '120 days'+i*interval '2 days'
  from generate_series(1,20) i;

  insert into public.orders(id,order_number,customer_name,origin,destination,status,vehicle_id,driver_id,cargo_description,cargo_weight_kg,scheduled_at,eta,pickup_at,delivered_at,pod_url,notes,created_at,updated_at)
  select
    ('50000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid, 'DO-ARAH-'||to_char(current_date,'YYMM')||'-'||lpad(i::text,3,'0'),
    (array['PT Nusantara Retail','PT Indonesia Manufacturing','PT Sumber Pangan Sejahtera','PT Elektronik Global Indonesia','PT Farma Medika Utama','PT Karya Baja Nasional','PT Sentra Niaga Abadi','PT Mitra Otomotif Indonesia'])[((i-1)%8)+1],
    (array['Jakarta Distribution Hub','Tangerang Regional Depot','Bekasi Cross Dock','Karawang Fulfillment Center','Surabaya East Java Hub'])[((i-1)%5)+1],
    (array['Bekasi DC','Karawang Plant','Cikarang Warehouse','Bogor Distribution Point','Bandung Hub','Semarang DC','Surabaya Retail Center','Tangerang Store Cluster'])[((i+1)%8)+1],
    case when i<=5 then 'planned'::public.order_status when i<=10 then 'assigned'::public.order_status when i<=14 then 'pickup'::public.order_status when i<=21 then 'in_transit'::public.order_status when i<=28 then 'delivered'::public.order_status else 'cancelled'::public.order_status end,
    case when i<=5 then null else ('40000000-0000-4000-8000-'||lpad((((i-1)%20)+1)::text,12,'0'))::uuid end,
    case when i<=5 then null else ('30000000-0000-4000-8000-'||lpad((((i-1)%20)+1)::text,12,'0'))::uuid end,
    (array['Produk FMCG karton','Spare part otomotif','Material kemasan','Elektronik konsumen','Produk farmasi non-cold-chain','Komponen baja','Bahan baku produksi','Peralatan ritel'])[((i-1)%8)+1],
    900+((i*437)%7200), now()+(i-12)*interval '4 hour', now()+(i-10)*interval '4 hour',
    case when i between 11 and 28 then now()-(29-i)*interval '3 hour' end,
    case when i between 22 and 28 then now()-(29-i)*interval '2 hour' end,
    case when i between 22 and 28 then 'demo/pod/DO-ARAH-'||lpad(i::text,3,'0')||'.jpg' end,
    'Dataset demo ARAH — order operasional lengkap', now()-(31-i)*interval '6 hour', now()-(30-i)*interval '4 hour'
  from generate_series(1,30) i;

  insert into public.routes(id,order_id,geometry,distance_km,duration_minutes,route_provider,created_at)
  select ('51000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('50000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    jsonb_build_object('type','LineString','coordinates',jsonb_build_array(jsonb_build_array(106.80+i*.003,-6.20-i*.002),jsonb_build_array(106.90+i*.003,-6.25-i*.002))),
    28+(i*7%190), 55+(i*13%280), 'osrm-demo', now()-(30-i)*interval '6 hour'
  from generate_series(1,30) i;

  insert into public.order_waypoints(order_id,sequence,label,latitude,longitude,completed_at)
  select ('50000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid, s,
    case s when 1 then 'Lokasi Pickup' else 'Lokasi Delivery' end,
    -6.18-i*.003-s*.015,106.82+i*.004+s*.025,
    case when (i>10 and s=1) or (i>21 and s=2) then now()-(31-i)*interval '2 hour' end
  from generate_series(1,30) i cross join generate_series(1,2) s;

  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select o.id,'planned','Order dibuat pada sistem Demo',demo_user,-6.18,106.84,o.created_at from public.orders o;
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select o.id,'assigned','Armada dan pengemudi ditugaskan',demo_user,-6.19,106.86,o.created_at+interval '30 minutes' from public.orders o where o.status not in ('planned');
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select o.id,'pickup','Muatan telah diambil dan diverifikasi',demo_user,-6.21,106.89,o.created_at+interval '1 hour' from public.orders o where o.status in ('pickup','in_transit','delivered');
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select o.id,'in_transit','Armada dalam perjalanan menuju tujuan',demo_user,-6.24,106.94,o.created_at+interval '2 hours' from public.orders o where o.status in ('in_transit','delivered');
  insert into public.order_events(order_id,status,note,actor_id,latitude,longitude,created_at)
  select o.id,'delivered','Barang diterima dan POD tersedia',demo_user,-6.27,107.01,o.delivered_at from public.orders o where o.status='delivered';
  insert into public.order_events(order_id,status,note,actor_id,created_at)
  select o.id,'cancelled','Dibatalkan berdasarkan permintaan pelanggan',demo_user,o.updated_at from public.orders o where o.status='cancelled';

  insert into public.gps_devices(id,vehicle_id,device_code,token_hash,active,last_seen_at,source_type,created_at)
  select ('60000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'ARAH-GPS-'||lpad(i::text,3,'0'),
    encode(digest('demo-device-'||i,'sha256'),'hex'),i<20,now()-i*interval '1 minute',
    case when i%4=0 then 'android' else 'gps_device' end,now()-interval '60 days'
  from generate_series(1,20) i;

  insert into public.gps_positions(vehicle_id,latitude,longitude,speed_kph,heading,recorded_at,source_type,accuracy_m,metadata)
  select ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    -6.17-i*.006+p*.0025,106.82+i*.007+p*.004,case when i<=9 then 28+(p*5)%45 else 0 end,(i*17+p*11)%360,
    now()-(6-p)*interval '4 minute'-i*interval '10 second',case when i%4=0 then 'android' else 'gps_device' end,
    3.5+(i%6),jsonb_build_object('ignition',i<=9,'satellites',8+(i%7),'demo',true)
  from generate_series(1,20) i cross join generate_series(1,6) p;

  insert into public.operational_funds(id,vehicle_id,order_id,category,amount,status,requested_by,approved_by,description,reviewed_at,rejection_reason,settlement_amount,settlement_note,settled_at,created_at,updated_at)
  select ('70000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad((((i-1)%20)+1)::text,12,'0'))::uuid,
    ('50000000-0000-4000-8000-'||lpad((((i-1)%30)+1)::text,12,'0'))::uuid,
    (array['BBM','Tol & Parkir','Uang Makan','Bongkar Muat','Perbaikan Darurat','Penyeberangan'])[((i-1)%6)+1],
    250000+((i*175000)%2750000),case when i<=6 then 'pending'::public.approval_status when i<=20 then 'approved'::public.approval_status else 'rejected'::public.approval_status end,
    demo_user,case when i>6 then demo_user end,'Kebutuhan operasional perjalanan #'||i,
    case when i>6 then now()-(25-i)*interval '2 hour' end,case when i>20 then 'Bukti/nominal belum sesuai kebijakan' end,
    case when i between 7 and 16 then 230000+((i*170000)%2500000) end,
    case when i between 7 and 16 then 'Realisasi lengkap dan bukti diterima' end,
    case when i between 7 and 16 then now()-(20-i)*interval '1 hour' end,
    now()-(25-i)*interval '5 hour',now()-(24-i)*interval '3 hour'
  from generate_series(1,24) i;

  insert into public.field_issues(id,vehicle_id,order_id,title,description,severity,resolved_at,reported_by,status,assigned_to,due_at,resolution,location_lat,location_lng,created_at,updated_at)
  select ('80000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('50000000-0000-4000-8000-'||lpad((i+8)::text,12,'0'))::uuid,
    (array['Kemacetan berat di jalur utama','Ban belakang kehilangan tekanan','Dokumen penerimaan belum siap','GPS terlambat mengirim posisi','Antrean bongkar muat panjang','Perubahan akses lokasi pelanggan','Suhu boks perlu diperiksa','Kendaraan memerlukan inspeksi rem','Penerima belum berada di lokasi','Gangguan perangkat Android driver','Jalan ditutup sementara','Segel muatan perlu verifikasi'])[i],
    'Temuan lapangan dari skenario Demo ARAH dengan detail tindakan dan SLA.',
    (array['medium','high','low','medium','high','medium','critical','high','low','medium','high','medium'])[i]::public.issue_severity,
    case when i>=9 then now()-(13-i)*interval '2 hour' end,demo_user,
    case when i<=3 then 'reported' when i<=5 then 'assigned' when i<=8 then 'in_progress' when i<=10 then 'resolved' else 'closed' end,
    case when i>3 then demo_user end,now()+(i-6)*interval '2 hour',
    case when i>=9 then 'Tindakan korektif selesai dan sudah diverifikasi dispatcher.' end,
    -6.20-i*.009,106.85+i*.012,now()-(13-i)*interval '4 hour',now()-(12-i)*interval '2 hour'
  from generate_series(1,12) i;

  insert into public.geofences(id,name,kind,latitude,longitude,radius_meters,active) values
    ('90000000-0000-4000-8000-000000000001','Jakarta Distribution Hub','depot',-6.1850,106.9470,500,true),
    ('90000000-0000-4000-8000-000000000002','Tangerang Regional Depot','depot',-6.1990,106.5190,500,true),
    ('90000000-0000-4000-8000-000000000003','Bekasi Cross Dock','depot',-6.3101,107.0927,450,true),
    ('90000000-0000-4000-8000-000000000004','Karawang Fulfillment Center','depot',-6.3667,107.3026,600,true),
    ('90000000-0000-4000-8000-000000000005','Pelabuhan Tanjung Priok','port',-6.1047,106.8819,1000,true),
    ('90000000-0000-4000-8000-000000000006','Customer Bekasi DC','customer',-6.2383,106.9756,300,true),
    ('90000000-0000-4000-8000-000000000007','Customer Cikarang Warehouse','customer',-6.3034,107.1647,300,true),
    ('90000000-0000-4000-8000-000000000008','Customer Karawang Plant','customer',-6.3269,107.3007,350,true);

  insert into public.geofence_events(geofence_id,vehicle_id,event_type,latitude,longitude,recorded_at)
  select ('90000000-0000-4000-8000-'||lpad((((i-1)%8)+1)::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    case when i%2=0 then 'enter' else 'exit' end,-6.18-i*.008,106.86+i*.013,now()-i*interval '35 minute'
  from generate_series(1,16) i;

  insert into public.maintenance_records(id,vehicle_id,maintenance_type,scheduled_at,completed_at,odometer_km,cost,notes,created_at)
  select ('91000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
    ('40000000-0000-4000-8000-'||lpad((((i+7)%20)+1)::text,12,'0'))::uuid,
    (array['Servis berkala','Penggantian oli dan filter','Inspeksi sistem rem','Rotasi dan balancing ban','Pemeriksaan pendingin boks'])[((i-1)%5)+1],
    now()+(i-6)*interval '3 day',case when i<=5 then now()-(6-i)*interval '5 day' end,
    52000+i*2900,750000+i*185000,'Catatan maintenance lengkap untuk demonstrasi.',now()-(13-i)*interval '7 day'
  from generate_series(1,12) i;

  -- The shared notifications table predates ARAH and requires these legacy fields.
  insert into public.notifications(company_id,employee_id,user_id,title,message,body,type,kind,is_read,action_link,created_at,read_at)
  select demo_user,demo_user,demo_user,'[DEMO ARAH] '||title,message,message,type,lower(type),false,'/',now()-i*interval '25 minute',null
  from (values
    (1,'Armada memasuki geofence','B 9127 UYT telah memasuki area Bekasi DC.','GEOFENCE'),
    (2,'SLA issue perlu perhatian','Issue ban belakang mendekati batas SLA.','WARNING'),
    (3,'Dana operasional menunggu review','Enam pengajuan dana menunggu persetujuan.','APPROVAL'),
    (4,'GPS armada offline','B 8899 JKL tidak mengirim posisi lebih dari 30 menit.','GPS'),
    (5,'Order berhasil diselesaikan','DO Demo telah dilengkapi bukti POD.','ORDER'),
    (6,'Jadwal maintenance','Tiga armada memiliki jadwal servis minggu ini.','MAINTENANCE'),
    (7,'Traffic alert','Kepadatan tinggi terdeteksi pada koridor Cikampek.','TRAFFIC'),
    (8,'Lisensi pengemudi','Dua SIM pengemudi perlu diperpanjang dalam 30 hari.','DRIVER')
  ) n(i,title,message,type);
end $$;
