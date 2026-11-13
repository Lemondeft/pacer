-- Offline-first idempotent rollup RPC for statistik & streak synchronization.
-- Ensures retried outbox operations cannot double-count weekly totals or
-- misorder multi-day offline workouts.

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

  -- Sum all finished activities within the ISO week bounds idempotently.
  select
    coalesce(sum(coalesce(a.jarak_m, 0)), 0),
    coalesce(sum(coalesce(a.durasi_s, 0)), 0)::integer
  into v_jarak, v_waktu
  from public.aktivitas a
  where a.user_id = v_uid
    and a.selesai_at is not null
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

  -- Advance streak only when p_activity_day is strictly newer than the last
  -- recorded day, keeping retries and same-day multiple runs idempotent.
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

revoke all on function public.sync_recompute_user_stats(text, timestamptz, timestamptz, date)
  from public, anon;
grant execute on function public.sync_recompute_user_stats(text, timestamptz, timestamptz, date)
  to authenticated;
