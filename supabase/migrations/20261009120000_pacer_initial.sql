-- Pacer initial schema — faithful to manual.drawio.xml (DFD L1 processes 1.0-5.0 stores).
-- Manual books become tables; frontend untouched.
-- SECURITY: RLS deny-by-default on all tables. Backend-only auth via Supabase Auth
-- (auth.uid()). service_role NEVER ships in the app — server-side only. Anon key
-- only. Supabase Auth rate limits apply; set statement_timeout per-role if needed.
-- Coach/admin writes go through is_coach_or_admin() helper, not via app-held secrets.

create extension if not exists "pgcrypto";

-- 1.0 LOGIN/KELOLA USER
create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  nama text,
  peran text not null default 'user' check (peran in ('user', 'coach', 'admin')),
  created_at timestamptz not null default now()
);

-- 2.0 AKTIVITAS & STATISTIK (tracking + GPS rute)
create table public.aktivitas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  jenis text not null check (jenis in ('lari', 'joging', 'bersepeda', 'berjalan')),
  mulai_at timestamptz,
  selesai_at timestamptz,
  durasi_s integer check (durasi_s is null or durasi_s >= 0),
  jarak_m numeric check (jarak_m is null or jarak_m >= 0),
  created_at timestamptz not null default now()
);
create index aktivitas_user_mulai_idx on public.aktivitas (user_id, mulai_at desc);

create table public.rute_points (
  id uuid primary key default gen_random_uuid(),
  aktivitas_id uuid not null references public.aktivitas (id) on delete cascade,
  urutan integer not null,
  lat double precision not null,
  lng double precision not null,
  elevasi_m numeric,
  kecepatan_ms numeric,
  direkam_at timestamptz,
  unique (aktivitas_id, urutan)
);
create index rute_points_aktivitas_idx on public.rute_points (aktivitas_id);

-- Riwayat ringkasan mingguan/bulanan + streak kalender
create table public.statistik (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  periode text not null,
  total_jarak_m numeric not null default 0,
  total_waktu_s integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (user_id, periode)
);
create index statistik_user_idx on public.statistik (user_id);

create table public.streak (
  user_id uuid primary key references public.users (id) on delete cascade,
  streak_berjalan integer not null default 0,
  terakhir_olahraga_tgl date,
  updated_at timestamptz not null default now()
);

-- 3.0 CHALLENGE (guru tentukan jenis/target/waktu, umumkan, ikuti, catat)
create table public.challenge (
  id uuid primary key default gen_random_uuid(),
  dibuat_oleh uuid references public.users (id),
  jenis text not null,
  target_nilai numeric not null check (target_nilai > 0),
  target_satuan text not null check (target_satuan in ('jarak_m', 'waktu_s')),
  waktu_mulai timestamptz,
  waktu_selesai timestamptz,
  diumumkan boolean not null default false,
  created_at timestamptz not null default now()
);
create index challenge_dibuat_idx on public.challenge (dibuat_oleh);

create table public.partisipasi_challenge (
  id uuid primary key default gen_random_uuid(),
  challenge_id uuid not null references public.challenge (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  progress_nilai numeric not null default 0,
  berhasil boolean not null default false,
  created_at timestamptz not null default now(),
  unique (challenge_id, user_id)
);
create index partisipasi_challenge_idx on public.partisipasi_challenge (challenge_id);
create index partisipasi_user_idx on public.partisipasi_challenge (user_id);

-- 4.0 LEADERBOARD & PERINGKAT (catat, bandingkan, urutkan, tulis, umumkan)
create table public.leaderboard (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  periode text not null,
  kriteria text not null,
  created_at timestamptz not null default now(),
  unique (nama, periode)
);

create table public.peringkat (
  id uuid primary key default gen_random_uuid(),
  leaderboard_id uuid not null references public.leaderboard (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  nilai numeric not null,
  posisi integer,
  updated_at timestamptz not null default now(),
  unique (leaderboard_id, user_id)
);
create index peringkat_lb_idx on public.peringkat (leaderboard_id);

-- 5.0 PACER TEAM (anggota, target team, pantau, gabung hasil)
create table public.teams (
  id uuid primary key default gen_random_uuid(),
  nama text not null,
  target_nilai numeric,
  dibuat_oleh uuid references public.users (id),
  created_at timestamptz not null default now()
);

create table public.team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  peran text not null default 'anggota',
  created_at timestamptz not null default now(),
  unique (team_id, user_id)
);
create index team_members_team_idx on public.team_members (team_id);
create index team_members_user_idx on public.team_members (user_id);

-- Helper: coach/admin check (security definer, fixed search_path)
create or replace function public.is_coach_or_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.peran in ('coach', 'admin')
  );
$$;

-- RLS deny-by-default
alter table public.users enable row level security;
alter table public.aktivitas enable row level security;
alter table public.rute_points enable row level security;
alter table public.statistik enable row level security;
alter table public.streak enable row level security;
alter table public.challenge enable row level security;
alter table public.partisipasi_challenge enable row level security;
alter table public.leaderboard enable row level security;
alter table public.peringkat enable row level security;
alter table public.teams enable row level security;
alter table public.team_members enable row level security;

-- users: read authenticated, update own (UPDATE uses USING only;
-- this Supabase/Postgres build rejects WITH CHECK outside INSERT)
create policy users_select on public.users for select to authenticated using (true);
create policy users_update_own on public.users for update to authenticated
  using (id = auth.uid());
create policy users_insert_own on public.users for insert to authenticated
  with check (id = auth.uid());

-- aktivitas / statistik / streak: owner-only (FOR ALL takes USING only;
-- WITH CHECK is rejected on FOR ALL, so INSERT gets its own policy)
create policy aktivitas_owner on public.aktivitas for all to authenticated
  using (user_id = auth.uid());
create policy aktivitas_insert_own on public.aktivitas for insert to authenticated
  with check (user_id = auth.uid());
create policy statistik_owner on public.statistik for all to authenticated
  using (user_id = auth.uid());
create policy statistik_insert_own on public.statistik for insert to authenticated
  with check (user_id = auth.uid());
create policy streak_owner on public.streak for all to authenticated
  using (user_id = auth.uid());
create policy streak_insert_own on public.streak for insert to authenticated
  with check (user_id = auth.uid());

-- rute_points: owner via parent aktivitas
create policy rute_owner on public.rute_points for all to authenticated
  using (exists (
    select 1 from public.aktivitas a
    where a.id = rute_points.aktivitas_id and a.user_id = auth.uid()
  ));
create policy rute_insert_owner on public.rute_points for insert to authenticated
  with check (exists (
    select 1 from public.aktivitas a
    where a.id = rute_points.aktivitas_id and a.user_id = auth.uid()
  ));

-- challenge / leaderboard / peringkat / teams: read all, write coach/admin
create policy challenge_select on public.challenge for select to authenticated using (true);
create policy challenge_write on public.challenge for all to authenticated
  using (public.is_coach_or_admin());
create policy challenge_insert on public.challenge for insert to authenticated
  with check (public.is_coach_or_admin());

create policy leaderboard_select on public.leaderboard for select to authenticated using (true);
create policy leaderboard_write on public.leaderboard for all to authenticated
  using (public.is_coach_or_admin());
create policy leaderboard_insert on public.leaderboard for insert to authenticated
  with check (public.is_coach_or_admin());

create policy peringkat_select on public.peringkat for select to authenticated using (true);
create policy peringkat_write on public.peringkat for all to authenticated
  using (public.is_coach_or_admin());
create policy peringkat_insert on public.peringkat for insert to authenticated
  with check (public.is_coach_or_admin());

create policy teams_select on public.teams for select to authenticated using (true);
create policy teams_write on public.teams for all to authenticated
  using (public.is_coach_or_admin());
create policy teams_insert on public.teams for insert to authenticated
  with check (public.is_coach_or_admin());

-- partisipasi / team_members: own rows + coach/admin full
create policy partisipasi_select on public.partisipasi_challenge for select to authenticated
  using (user_id = auth.uid() or public.is_coach_or_admin());
create policy partisipasi_insert on public.partisipasi_challenge for insert to authenticated
  with check (user_id = auth.uid() or public.is_coach_or_admin());
create policy partisipasi_update on public.partisipasi_challenge for update to authenticated
  using (user_id = auth.uid() or public.is_coach_or_admin());
create policy partisipasi_delete on public.partisipasi_challenge for delete to authenticated
  using (user_id = auth.uid() or public.is_coach_or_admin());

create policy members_select on public.team_members for select to authenticated
  using (user_id = auth.uid() or public.is_coach_or_admin());
create policy members_insert on public.team_members for insert to authenticated
  with check (user_id = auth.uid() or public.is_coach_or_admin());
create policy members_update on public.team_members for update to authenticated
  using (user_id = auth.uid() or public.is_coach_or_admin());
create policy members_delete on public.team_members for delete to authenticated
  using (user_id = auth.uid() or public.is_coach_or_admin());
