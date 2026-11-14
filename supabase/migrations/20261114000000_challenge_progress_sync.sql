-- Challenge progress rollup: automatically recompute partisipasi_challenge
-- (progress_nilai & berhasil) from finished workouts in public.aktivitas.
-- Mirrors Dart evaluateChallengeProgress / challengeActivityDelta rules.

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
     and (c.waktu_mulai is null or coalesce(a.mulai_at, a.selesai_at) >= c.waktu_mulai)
     and (c.waktu_selesai is null or coalesce(a.mulai_at, a.selesai_at) < c.waktu_selesai)
     and (p.created_at is null or a.selesai_at >= p.created_at)
    where p.user_id = p_user_id
    group by p.id, c.target_nilai
  )
  update public.partisipasi_challenge p
     set progress_nilai = computed.progress_val,
         berhasil = (computed.target_nilai > 0 and computed.progress_val >= computed.target_nilai)
    from computed
   where p.id = computed.participation_id;
$$;

create or replace function public.aktivitas_challenge_progress_trigger()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := coalesce(new.user_id, old.user_id);
begin
  if tg_op = 'INSERT' and new.selesai_at is null then
    return new;
  end if;
  if tg_op = 'UPDATE' and new.selesai_at is null and old.selesai_at is null then
    return new;
  end if;

  if v_uid is not null then
    perform public.recompute_user_challenge_progress(v_uid);
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists aktivitas_challenge_progress_trigger on public.aktivitas;
create trigger aktivitas_challenge_progress_trigger
  after insert or update of selesai_at, jarak_m, durasi_s, jenis, mulai_at or delete
  on public.aktivitas
  for each row execute function public.aktivitas_challenge_progress_trigger();

create or replace function public.sync_recompute_challenge_progress()
returns setof public.partisipasi_challenge
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  perform public.recompute_user_challenge_progress(v_uid);

  return query
    select p.*
    from public.partisipasi_challenge p
    where p.user_id = v_uid
    order by p.created_at desc;
end;
$$;

revoke all on function public.aktivitas_challenge_progress_trigger() from public, anon, authenticated;
revoke all on function public.recompute_user_challenge_progress(uuid) from public, anon;
grant execute on function public.recompute_user_challenge_progress(uuid) to authenticated;
revoke all on function public.sync_recompute_challenge_progress() from public, anon;
grant execute on function public.sync_recompute_challenge_progress() to authenticated;
