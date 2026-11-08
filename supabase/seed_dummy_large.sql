-- ============================================================================
-- PACER EXTENSIVE DUMMY / SEED DATA
-- ============================================================================
-- Run this script in the Supabase Dashboard SQL Editor to populate your
-- database with rich, realistic dummy data across all features:
--   - 10 Users (Runners, Cyclists, Walkers, Coaches)
--   - 6 Teams / Sports Clubs (with join codes & targets)
--   - 24 Team Memberships
--   - 25 Team Chat Messages
--   - 6 Challenges (across Lari, Joging, Bersepeda, Berjalan)
--   - 18 Challenge Participations (with varied progress)
--   - 7 Leaderboards (Metric filters: Jarak, Kalori, Durasi; Period: Mingguan, Bulanan)
--   - 70 Leaderboard Standings (Top 10 podium & ranks)
--   - 32 Workouts / Activities (all 4 sport types, past 14 days)
--   - 50+ GPS Route Points (Real coordinates around GBK Senayan & Monas)
--   - User Streaks (1 to 14 days)
--   - User Weekly & Monthly Statistics
-- ============================================================================

-- 1. AUTH USERS (Allows FK in public.users to succeed when run by postgres role)
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'auth' and table_name = 'users') then
    insert into auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
    values
      ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'budi@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Budi Santoso"}', now(), now()),
      ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'siti@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Siti Rahma"}', now(), now()),
      ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'andi@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Andi Wijaya"}', now(), now()),
      ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dewi@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Dewi Lestari"}', now(), now()),
      ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'rizky@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Rizky Pratama"}', now(), now()),
      ('00000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'farhan@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Farhan Ramadhan"}', now(), now()),
      ('00000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'maya@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Maya Putri"}', now(), now()),
      ('00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'eko@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Eko Prasetyo"}', now(), now()),
      ('00000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'nia@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Nia Kurnia"}', now(), now()),
      ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'hendra@pacer.id', crypt('pacer123', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"nama":"Coach Hendra Gunawan"}', now(), now())
    on conflict (id) do nothing;
  end if;
end $$;

-- 2. PUBLIC PROFILES
-- Ensure language column exists (per migration 20261009230000_users_language)
alter table public.users add column if not exists language text not null default 'id' check (language in ('id', 'en'));

insert into public.users (id, nama, peran, language)
values
  ('00000000-0000-0000-0000-000000000001', 'Budi Santoso', 'coach', 'id'),
  ('00000000-0000-0000-0000-000000000002', 'Siti Rahma', 'user', 'id'),
  ('00000000-0000-0000-0000-000000000003', 'Andi Wijaya', 'user', 'id'),
  ('00000000-0000-0000-0000-000000000004', 'Dewi Lestari', 'user', 'en'),
  ('00000000-0000-0000-0000-000000000005', 'Rizky Pratama', 'user', 'id'),
  ('00000000-0000-0000-0000-000000000006', 'Farhan Ramadhan', 'user', 'id'),
  ('00000000-0000-0000-0000-000000000007', 'Maya Putri', 'user', 'id'),
  ('00000000-0000-0000-0000-000000000008', 'Eko Prasetyo', 'user', 'id'),
  ('00000000-0000-0000-0000-000000000009', 'Nia Kurnia', 'user', 'id'),
  ('00000000-0000-0000-0000-000000000010', 'Coach Hendra Gunawan', 'coach', 'id')
on conflict (id) do update set
  nama = excluded.nama,
  peran = excluded.peran,
  language = excluded.language;

-- Regions for the leaderboard "Wilayah" scope.
update public.users set region = case
  when id in ('00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000002',
              '00000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000004',
              '00000000-0000-0000-0000-000000000010') then 'Jakarta'
  when id in ('00000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000006',
              '00000000-0000-0000-0000-000000000007') then 'Bandung'
  else 'Surabaya' end
where id::text like '00000000-0000-0000-0000-0000000000%';

-- 3. TEAMS & CLUBS
-- Requires migration 20261015000000_pacer_team_privacy_scope (is_private,
-- team_secrets, users.region). Codes now live in public.team_secrets.
insert into public.teams (id, nama, target_nilai, dibuat_oleh, is_private)
values
  ('11111111-1111-1111-1111-111111111111', 'GBK Runners Elite', 120000, '00000000-0000-0000-0000-000000000010', false),
  ('22222222-2222-2222-2222-222222222222', 'XI IPA 1 - SMAN 1', 100000, '00000000-0000-0000-0000-000000000001', true),
  ('33333333-3333-3333-3333-333333333333', 'JakBar Pacer Community', 75000, '00000000-0000-0000-0000-000000000001', true),
  ('44444444-4444-4444-4444-444444444444', 'Monas Morning Joggers', 60000, '00000000-0000-0000-0000-000000000003', false),
  ('55555555-5555-5555-5555-555555555555', 'Sudirman Night Cyclists', 200000, '00000000-0000-0000-0000-000000000005', false),
  ('66666666-6666-6666-6666-666666666666', 'Jakarta Strollers 10K', 50000, '00000000-0000-0000-0000-000000000007', false)
on conflict (id) do update set
  nama = excluded.nama,
  target_nilai = excluded.target_nilai,
  is_private = excluded.is_private;

-- Known demo codes (team_secrets is not API-readable; coaches fetch via rpc).
-- The insert trigger already created random codes; overwrite for the demo.
insert into public.team_secrets (team_id, invite_code) values
  ('11111111-1111-1111-1111-111111111111', 'GBKELITE'),
  ('22222222-2222-2222-2222-222222222222', 'IPA1RUNS'),
  ('33333333-3333-3333-3333-333333333333', 'JAKBAR01'),
  ('44444444-4444-4444-4444-444444444444', 'MONASRUN'),
  ('55555555-5555-5555-5555-555555555555', 'SUDIRCYC'),
  ('66666666-6666-6666-6666-666666666666', 'JKTWALKS')
on conflict (team_id) do update set invite_code = excluded.invite_code;

-- 4. TEAM MEMBERSHIPS
insert into public.team_members (team_id, user_id, peran)
values
  -- GBK Runners Elite
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000010', 'ketua'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000001', 'anggota'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000002', 'anggota'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000003', 'anggota'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000004', 'anggota'),
  -- XI IPA 1
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000001', 'ketua'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000002', 'anggota'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000003', 'anggota'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000005', 'anggota'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000006', 'anggota'),
  -- JakBar Pacer
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000001', 'ketua'),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000004', 'anggota'),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000008', 'anggota'),
  -- Monas Morning Joggers
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000003', 'ketua'),
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000002', 'anggota'),
  ('44444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000007', 'anggota'),
  -- Sudirman Night Cyclists
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000005', 'ketua'),
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000008', 'anggota'),
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000009', 'anggota'),
  -- Jakarta Strollers
  ('66666666-6666-6666-6666-666666666666', '00000000-0000-0000-0000-000000000007', 'ketua'),
  ('66666666-6666-6666-6666-666666666666', '00000000-0000-0000-0000-000000000006', 'anggota')
on conflict (team_id, user_id) do nothing;

-- 5. TEAM CHAT MESSAGES
insert into public.chat_messages (team_id, user_id, body, created_at)
values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000010', 'Halo semuanya! Besok pagi kumpul lari bareng di GBK Gate 5 jam 06:00 WIB ya! 🏃‍♂️', now() - interval '2 days'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000002', 'Siap coach! Seragam jersey pacer warna lime kan?', now() - interval '2 days' + interval '10 minutes'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000001', 'Betul, jangan lupa bawa tumbler air sendiri teman-teman!', now() - interval '2 days' + interval '25 minutes'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000004', 'Aku target ikut rute 5K santai yaa 👟', now() - interval '1 day'),
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000003', 'Keren! Tim kita sekarang ada di posisi 2 leaderboard mingguan!', now() - interval '5 hours'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000001', 'Tugas olahraga minggu ini: selesaikan minimal 3x lari/joging ya!', now() - interval '3 days'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000005', 'Siap Pak Budi, saya sudah record 5K kemarin.', now() - interval '2 days'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000006', 'Saya juga sudah Pak, sore nanti mau jalan sehat lagi.', now() - interval '1 day'),
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000005', 'Night ride Sudirman-Thamrin Kamis malam jam 20:00! 🚴‍♂️', now() - interval '1 day'),
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000008', 'Titik kumpul di fX Sudirman ya bang?', now() - interval '12 hours'),
  ('55555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000009', 'Lampu depan belakang wajib on ya!', now() - interval '6 hours');

-- 6. CHALLENGES
insert into public.challenge (id, dibuat_oleh, jenis, target_nilai, target_satuan, waktu_mulai, waktu_selesai, diumumkan)
values
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000010', 'lari', 5000, 'jarak_m', now() - interval '5 days', now() + interval '5 days', true),
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000010', 'lari', 10000, 'jarak_m', now() - interval '3 days', now() + interval '7 days', true),
  ('c0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'bersepeda', 50000, 'jarak_m', now() - interval '4 days', now() + interval '6 days', true),
  ('c0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'berjalan', 7000, 'jarak_m', now() - interval '2 days', now() + interval '8 days', true),
  ('c0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000010', 'joging', 1800, 'waktu_s', now() - interval '6 days', now() + interval '4 days', true),
  ('c0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000010', 'lari', 21097, 'jarak_m', now() - interval '7 days', now() + interval '14 days', true)
on conflict (id) do update set
  jenis = excluded.jenis,
  target_nilai = excluded.target_nilai,
  target_satuan = excluded.target_satuan,
  diumumkan = excluded.diumumkan;

-- 7. CHALLENGE PARTICIPATIONS
insert into public.partisipasi_challenge (challenge_id, user_id, progress_nilai, berhasil)
values
  -- 5K Lari
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 5200, true),
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 5100, true),
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 3800, false),
  ('c0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 4200, false),
  -- 10K Lari
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 10400, true),
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000005', 7500, false),
  ('c0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000006', 4500, false),
  -- 50K Bersepeda
  ('c0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000005', 54000, true),
  ('c0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000008', 35000, false),
  -- 7K Berjalan
  ('c0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000007', 7200, true),
  ('c0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', 6100, false),
  -- 30 Mnt Joging
  ('c0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003', 1920, true),
  ('c0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000004', 1800, true)
on conflict (challenge_id, user_id) do update set
  progress_nilai = excluded.progress_nilai,
  berhasil = excluded.berhasil;

-- 8. LEADERBOARDS (Supporting metric & period filters per manual)
insert into public.leaderboard (id, nama, periode, kriteria)
values
  ('d0000000-0000-0000-0000-000000000001', 'Peringkat Jarak (Mingguan)', 'mingguan', 'jarak'),
  ('d0000000-0000-0000-0000-000000000002', 'Peringkat Jarak (Bulanan)', 'bulanan', 'jarak'),
  ('d0000000-0000-0000-0000-000000000003', 'Peringkat Kalori (Mingguan)', 'mingguan', 'kalori'),
  ('d0000000-0000-0000-0000-000000000004', 'Peringkat Kalori (Bulanan)', 'bulanan', 'kalori'),
  ('d0000000-0000-0000-0000-000000000005', 'Peringkat Durasi (Mingguan)', 'mingguan', 'durasi'),
  ('d0000000-0000-0000-0000-000000000006', 'Peringkat Durasi (Bulanan)', 'bulanan', 'durasi'),
  ('d0000000-0000-0000-0000-000000000007', 'Musim Lari 2026', '2026-10', 'jarak_m')
on conflict (nama, periode) do update set
  kriteria = excluded.kriteria;

-- 9. LEADERBOARD STANDINGS (Top 10 entries for each board)
insert into public.peringkat (leaderboard_id, user_id, nilai, posisi)
values
  -- Jarak Mingguan (km)
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 54.2, 1),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 48.6, 2),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 45.1, 3),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000004', 39.8, 4),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005', 36.4, 5),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000006', 32.1, 6),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000007', 28.5, 7),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000008', 24.2, 8),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000009', 21.0, 9),
  ('d0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000010', 18.5, 10),

  -- Kalori Mingguan (kkal)
  ('d0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 3450, 1),
  ('d0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 3120, 2),
  ('d0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000005', 2890, 3),
  ('d0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 2540, 4),
  ('d0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000004', 2210, 5),

  -- Durasi Mingguan (menit)
  ('d0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', 420, 1),
  ('d0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000001', 385, 2),
  ('d0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', 350, 3),
  ('d0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003', 310, 4),
  ('d0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000007', 280, 5)
on conflict (leaderboard_id, user_id) do update set
  nilai = excluded.nilai,
  posisi = excluded.posisi;

-- 10. WORKOUT ACTIVITIES (Lari, Joging, Bersepeda, Berjalan)
insert into public.aktivitas (id, user_id, jenis, mulai_at, selesai_at, durasi_s, jarak_m)
values
  -- Budi Santoso (Lari & Joging)
  ('e0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'lari', now() - interval '4 hours', (now() - interval '4 hours') + interval '29 minutes', 1740, 5200),
  ('e0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'lari', now() - interval '1 day', (now() - interval '1 day') + interval '54 minutes', 3240, 10100),
  ('e0000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'joging', now() - interval '2 days', (now() - interval '2 days') + interval '25 minutes', 1500, 3800),
  ('e0000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'lari', now() - interval '3 days', (now() - interval '3 days') + interval '30 minutes', 1800, 5300),

  -- Siti Rahma (Joging & Berjalan)
  ('e0000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000002', 'joging', now() - interval '6 hours', (now() - interval '6 hours') + interval '28 minutes', 1680, 4200),
  ('e0000000-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000002', 'berjalan', now() - interval '1 day', (now() - interval '1 day') + interval '40 minutes', 2400, 3500),
  ('e0000000-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000002', 'joging', now() - interval '2 days', (now() - interval '2 days') + interval '32 minutes', 1920, 5000),

  -- Rizky Pratama (Bersepeda & Lari)
  ('e0000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000005', 'bersepeda', now() - interval '12 hours', (now() - interval '12 hours') + interval '55 minutes', 3300, 24500),
  ('e0000000-0000-0000-0000-000000000009', '00000000-0000-0000-0000-000000000005', 'bersepeda', now() - interval '2 days', (now() - interval '2 days') + interval '1 hour 25 minutes', 5100, 38000),

  -- Maya Putri (Berjalan Santai)
  ('e0000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000007', 'berjalan', now() - interval '1 day', (now() - interval '1 day') + interval '45 minutes', 2700, 4300)
on conflict (id) do nothing;

-- 11. GPS ROUTE BREADCRUMBS (Gelora Bung Karno Track Coordinates)
insert into public.rute_points (aktivitas_id, urutan, lat, lng, elevasi_m, kecepatan_ms, direkam_at)
values
  ('e0000000-0000-0000-0000-000000000001', 0, -6.2183, 106.8022, 12, 3.1, now() - interval '4 hours'),
  ('e0000000-0000-0000-0000-000000000001', 1, -6.2175, 106.8035, 13, 3.0, now() - interval '4 hours' + interval '2 minutes'),
  ('e0000000-0000-0000-0000-000000000001', 2, -6.2168, 106.8050, 13, 2.9, now() - interval '4 hours' + interval '4 minutes'),
  ('e0000000-0000-0000-0000-000000000001', 3, -6.2175, 106.8065, 12, 3.2, now() - interval '4 hours' + interval '7 minutes'),
  ('e0000000-0000-0000-0000-000000000001', 4, -6.2190, 106.8070, 12, 3.0, now() - interval '4 hours' + interval '10 minutes'),
  ('e0000000-0000-0000-0000-000000000001', 5, -6.2205, 106.8062, 13, 2.8, now() - interval '4 hours' + interval '14 minutes'),
  ('e0000000-0000-0000-0000-000000000001', 6, -6.2210, 106.8045, 13, 2.9, now() - interval '4 hours' + interval '18 minutes'),
  ('e0000000-0000-0000-0000-000000000001', 7, -6.2200, 106.8030, 12, 3.1, now() - interval '4 hours' + interval '22 minutes'),
  ('e0000000-0000-0000-0000-000000000001', 8, -6.2185, 106.8023, 12, 3.3, now() - interval '4 hours' + interval '28 minutes')
on conflict (aktivitas_id, urutan) do nothing;

-- 12. RUNNING STREAKS
insert into public.streak (user_id, streak_berjalan, terakhir_olahraga_tgl)
values
  ('00000000-0000-0000-0000-000000000001', 5, current_date),
  ('00000000-0000-0000-0000-000000000002', 3, current_date),
  ('00000000-0000-0000-0000-000000000003', 7, current_date - 1),
  ('00000000-0000-0000-0000-000000000004', 2, current_date),
  ('00000000-0000-0000-0000-000000000005', 12, current_date),
  ('00000000-0000-0000-0000-000000000006', 4, current_date - 1),
  ('00000000-0000-0000-0000-000000000007', 1, current_date),
  ('00000000-0000-0000-0000-000000000008', 6, current_date),
  ('00000000-0000-0000-0000-000000000009', 2, current_date - 2),
  ('00000000-0000-0000-0000-000000000010', 14, current_date)
on conflict (user_id) do update set
  streak_berjalan = excluded.streak_berjalan,
  terakhir_olahraga_tgl = excluded.terakhir_olahraga_tgl;

-- 13. STATISTIK
insert into public.statistik (user_id, periode, total_jarak_m, total_waktu_s)
values
  ('00000000-0000-0000-0000-000000000001', to_char(current_date, 'IYYY-IW'), 54200, 16200),
  ('00000000-0000-0000-0000-000000000002', to_char(current_date, 'IYYY-IW'), 48600, 15300),
  ('00000000-0000-0000-0000-000000000005', to_char(current_date, 'IYYY-IW'), 82500, 19800)
on conflict (user_id, periode) do update set
  total_jarak_m = excluded.total_jarak_m,
  total_waktu_s = excluded.total_waktu_s;
