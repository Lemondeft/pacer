-- Demo seed for Pacer (NOT a migration — run manually, once, AFTER all migrations).
--
-- Steps:
--   1. In the app, sign up 2 dummy users (e.g. budi@demo.id, siti@demo.id).
--   2. Dashboard → Authentication → copy each user's UUID.
--   3. Replace <BUDI_UUID> and <SITI_UUID> below, then run this whole file
--      in the SQL editor. Rerunning duplicates rows (no cleanup included).
--   4. To make Budi a coach afterwards:
--      update public.users set peran = 'coach'
--      where id = '<BUDI_UUID>';

-- Profiles for the two auth users (id must match auth.users).
insert into public.users (id, nama) values
  ('<BUDI_UUID>', 'Budi Santoso'),
  ('<SITI_UUID>', 'Siti Rahma');

-- Teams + memberships.
insert into public.teams (id, nama, target_nilai) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'XI IPA 1', 100000),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'JakBar Pacer', 50000);

insert into public.team_members (team_id, user_id, peran) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '<BUDI_UUID>', 'ketua'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '<SITI_UUID>', 'anggota'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '<BUDI_UUID>', 'anggota');

-- Challenge (open-ended 5K run) + participations.
insert into public.challenge (id, jenis, target_nilai, target_satuan, diumumkan) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'lari', 5000, 'jarak_m', true);

insert into public.partisipasi_challenge (challenge_id, user_id, progress_nilai, berhasil) values
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '<BUDI_UUID>', 5200, true),
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', '<SITI_UUID>', 3100, false);

-- Leaderboard board + standings.
insert into public.leaderboard (id, nama, periode, kriteria) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'Oktober 2026', '2026-10', 'jarak_m');

insert into public.peringkat (leaderboard_id, user_id, nilai, posisi) values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '<BUDI_UUID>', 5200, 1),
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '<SITI_UUID>', 3100, 2);

-- Activities + a tiny route + streak/statistik for Budi.
insert into public.aktivitas (id, user_id, jenis, mulai_at, selesai_at, durasi_s, jarak_m) values
  ('e0000000-0000-0000-0000-000000000001', '<BUDI_UUID>', 'lari',
   now() - interval '2 days', (now() - interval '2 days') + interval '30 minutes', 1800, 5200),
  ('e0000000-0000-0000-0000-000000000002', '<SITI_UUID>', 'joging',
   now() - interval '1 day', (now() - interval '1 day') + interval '25 minutes', 1500, 3100);

insert into public.rute_points (aktivitas_id, urutan, lat, lng, kecepatan_ms) values
  ('e0000000-0000-0000-0000-000000000001', 0, -6.2296, 106.8294, 2.8),
  ('e0000000-0000-0000-0000-000000000001', 1, -6.2286, 106.8301, 2.9),
  ('e0000000-0000-0000-0000-000000000001', 2, -6.2276, 106.8308, 2.7);

insert into public.streak (user_id, streak_berjalan, terakhir_olahraga_tgl) values
  ('<BUDI_UUID>', 3, current_date - 1),
  ('<SITI_UUID>', 1, current_date - 1);

-- Team chat sample (requires the chat migration applied).
insert into public.chat_messages (team_id, user_id, body) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '<BUDI_UUID>', 'Besok lari pagi GBK jam 6, yang ikut absen di sini.'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '<SITI_UUID>', 'Siap ikut Sabtu ini!');
