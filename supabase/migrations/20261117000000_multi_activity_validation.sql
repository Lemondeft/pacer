-- Multi-Activity Classification & Anti-Cheat Validation schema & rollup exclusion.
-- Implements Layer 5 server-side validation columns, notification types, and
-- exclusion of flagged activities from challenge progress & vehicle-flagged stats.

-- 1. Extend public.aktivitas with validation metadata and hardware cadence.
alter table public.aktivitas
  add column if not exists validation_status text default 'unverified'
    check (validation_status in (
      'unverified',
      'pending',
      'verified',
      'flagged_ride',
      'flagged_mismatch',
      'flagged_vehicle',
      'reclassified'
    )),
  add column if not exists validation_score numeric,
  add column if not exists validation_reasons jsonb default '[]'::jsonb,
  add column if not exists suggested_sport text
    check (
      suggested_sport is null
      or suggested_sport in ('lari', 'joging', 'bersepeda', 'berjalan')
    ),
  add column if not exists os_motion_summary jsonb,
  add column if not exists cadence_spm integer
    check (cadence_spm is null or (cadence_spm >= 20 and cadence_spm <= 260)),
  add column if not exists validated_at timestamptz;

create index if not exists aktivitas_user_validation_idx
  on public.aktivitas (user_id, validation_status);

-- 2. Extend public.user_notifications type constraint cleanly.
do $$
declare
  v_constraint_name text;
begin
  select c.conname
    into v_constraint_name
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'user_notifications'
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) ilike '%type%';

  if v_constraint_name is not null then
    execute format(
      'alter table public.user_notifications drop constraint %I',
      v_constraint_name
    );
  end if;
end $$;

alter table public.user_notifications
  add constraint user_notifications_type_check check (
    type in (
      'team_challenge_assigned',
      'challenge_completed',
      'team_role_changed',
      'sport_reclassification_suggested',
      'vehicle_activity_flagged'
    )
  );

-- 3. Exclude flagged activities from challenge progress rollup while keeping
-- explicit challenge_ids opt-in and active-slot promotion intact.
create or replace function public.recompute_user_challenge_progress(p_user_id uuid)
returns void
language sql
security invoker
set search_path = public
as $$
  with computed as (
    select
      p.id as participation_id,
      coalesce(sum(
        case
          when c.target_satuan = 'waktu_s' then coalesce(a.durasi_s, 0)::numeric
          else coalesce(a.jarak_m, 0)
        end
      ), 0) as progress_val,
      c.target_nilai
    from public.partisipasi_challenge p
    join public.challenge c on c.id = p.challenge_id
    left join public.aktivitas a
      on a.user_id = p.user_id
     and a.selesai_at is not null
     and a.jenis = c.jenis
     and coalesce(a.validation_status, 'unverified') not in (
       'flagged_ride',
       'flagged_mismatch',
       'flagged_vehicle'
     )
     and (c.waktu_mulai is null or coalesce(a.mulai_at, a.selesai_at) >= c.waktu_mulai)
     and (c.waktu_selesai is null or coalesce(a.mulai_at, a.selesai_at) < c.waktu_selesai)
     and (
       (a.challenge_ids is null and (p.created_at is null or a.selesai_at >= p.created_at))
       or (a.challenge_ids is not null and c.id = any(a.challenge_ids))
     )
    where p.user_id = p_user_id
    group by p.id, c.target_nilai
  )
  update public.partisipasi_challenge p
     set progress_nilai = computed.progress_val,
         berhasil = (computed.target_nilai > 0 and computed.progress_val >= computed.target_nilai),
         is_active = case
           when (computed.target_nilai > 0 and computed.progress_val >= computed.target_nilai) then false
           else p.is_active
         end
    from computed
   where p.id = computed.participation_id;
$$;

revoke all on function public.recompute_user_challenge_progress(uuid) from public, anon;
grant execute on function public.recompute_user_challenge_progress(uuid) to authenticated;

drop trigger if exists aktivitas_challenge_progress_trigger on public.aktivitas;
create trigger aktivitas_challenge_progress_trigger
  after insert or update of selesai_at, jarak_m, durasi_s, jenis, mulai_at, challenge_ids, validation_status or delete
  on public.aktivitas
  for each row execute function public.aktivitas_challenge_progress_trigger();

-- 4. Exclude motorized-vehicle flagged trips from weekly statistik rollup.
create or replace function public.sync_recompute_user_stats(
  p_periode text,
  p_week_start timestamptz,
  p_week_end timestamptz,
  p_activity_day date
)
returns table (
  total_jarak_m numeric,
  total_waktu_s integer,
  streak_berjalan integer,
  terakhir_olahraga_tgl date
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_jarak numeric := 0;
  v_waktu integer := 0;
  v_cur_streak integer := 0;
  v_last_day date := null;
  v_next_streak integer := 0;
  v_next_day date := null;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  if p_periode is null or length(trim(p_periode)) = 0 then
    raise exception 'p_periode must not be empty' using errcode = '22023';
  end if;

  -- Sum all non-vehicle finished activities within the ISO week bounds.
  select
    coalesce(sum(coalesce(a.jarak_m, 0)), 0),
    coalesce(sum(coalesce(a.durasi_s, 0)), 0)::integer
  into v_jarak, v_waktu
  from public.aktivitas a
  where a.user_id = v_uid
    and a.selesai_at is not null
    and coalesce(a.validation_status, 'unverified') <> 'flagged_vehicle'
    and a.mulai_at >= p_week_start
    and a.mulai_at < p_week_end;

  insert into public.statistik (
    user_id,
    periode,
    total_jarak_m,
    total_waktu_s,
    updated_at
  )
  values (v_uid, p_periode, v_jarak, v_waktu, now())
  on conflict (user_id, periode) do update
    set total_jarak_m = excluded.total_jarak_m,
        total_waktu_s = excluded.total_waktu_s,
        updated_at = now();

  select s.streak_berjalan, s.terakhir_olahraga_tgl
  into v_cur_streak, v_last_day
  from public.streak s
  where s.user_id = v_uid;

  if v_last_day is null then
    v_next_streak := 1;
    v_next_day := p_activity_day;
  elsif p_activity_day <= v_last_day then
    v_next_streak := coalesce(v_cur_streak, 1);
    v_next_day := v_last_day;
  elsif p_activity_day = (v_last_day + 1) then
    v_next_streak := coalesce(v_cur_streak, 0) + 1;
    v_next_day := p_activity_day;
  else
    v_next_streak := 1;
    v_next_day := p_activity_day;
  end if;

  insert into public.streak (
    user_id,
    streak_berjalan,
    terakhir_olahraga_tgl,
    updated_at
  )
  values (v_uid, v_next_streak, v_next_day, now())
  on conflict (user_id) do update
    set streak_berjalan = excluded.streak_berjalan,
        terakhir_olahraga_tgl = excluded.terakhir_olahraga_tgl,
        updated_at = now();

  return query select v_jarak, v_waktu, v_next_streak, v_next_day;
end;
$$;
