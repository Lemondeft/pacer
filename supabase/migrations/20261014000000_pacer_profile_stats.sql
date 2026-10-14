-- Profile enrichment: optional physical stats + required display name.
--
-- Matches the deferred ERD columns (tanggal_lahir, jenis_kelamin,
-- tinggi_badan, berat_badan) with app-friendly names. All nullable except
-- nama: signup and profile-edit flows require a non-empty name, and the
-- backfill below guarantees no NULLs before the constraint lands.
-- RLS unchanged (owner-only + coach writes via existing users policies;
-- new columns inherit them).

-- Backfill first so SET NOT NULL never fails on existing rows.
update public.users set nama = '' where nama is null;

alter table public.users
  alter column nama set not null;

alter table public.users
  add column if not exists lahir date,
  add column if not exists jenis_kelamin text
    check (jenis_kelamin in ('Laki-laki', 'Perempuan')),
  add column if not exists tinggi_cm numeric
    check (tinggi_cm is null or (tinggi_cm > 0 and tinggi_cm < 300)),
  add column if not exists berat_kg numeric
    check (berat_kg is null or (berat_kg > 0 and berat_kg < 1000));

comment on column public.users.lahir is
  'Optional birth date (ERD tanggal_lahir). Null = not provided.';
comment on column public.users.jenis_kelamin is
  'Optional gender (ERD jenis_kelamin). Null = not provided.';
comment on column public.users.tinggi_cm is
  'Optional height in cm (ERD tinggi_badan). Null = not provided.';
comment on column public.users.berat_kg is
  'Optional weight in kg (ERD berat_badan). Null = not provided.';
