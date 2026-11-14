-- Team Challenges (Coach/Ketua assigned + Solo), 1-Coach + 1-Solo active slot,
-- per-activity challenge selection (challenge_ids), Coach Ketua promotion RPC,
-- and real Member Notifications (user_notifications).

-- ---------------------------------------------------------------------------
-- 1. Schema additions
-- ---------------------------------------------------------------------------
alter table public.challenge
  add column if not exists team_id uuid references public.teams (id) on delete cascade,
  add column if not exists judul text;

create index if not exists challenge_team_idx
  on public.challenge (team_id)
  where team_id is not null;

alter table public.partisipasi_challenge
  add column if not exists is_active boolean not null default true;

alter table public.aktivitas
  add column if not exists challenge_ids uuid[];

-- ---------------------------------------------------------------------------
-- 2. Access helper for Team Challenges (Coach / Admin / Creator / Team Ketua)
-- ---------------------------------------------------------------------------
create or replace function public.can_manage_team_challenge(p_team_id uuid)
returns boolean
language sql
security invoker
set search_path = public
stable
as $$
  select
    p_team_id is not null
    and auth.uid() is not null
    and (
      public.is_coach_or_admin()
      or exists (
        select 1 from public.teams t
        where t.id = p_team_id and t.dibuat_oleh = auth.uid()
      )
      or exists (
        select 1 from public.team_members m
        where m.team_id = p_team_id
          and m.user_id = auth.uid()
          and m.peran = 'ketua'
      )
    );
$$;

revoke all on function public.can_manage_team_challenge(uuid) from public, anon;
grant execute on function public.can_manage_team_challenge(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Notifications table (RLS: users read/mark-read/delete own rows only)
-- ---------------------------------------------------------------------------
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users (id) on delete cascade,
  type text not null check (type in (
    'team_challenge_assigned',
    'challenge_completed',
    'team_role_changed'
  )),
  title text not null,
  body text not null,
  challenge_id uuid references public.challenge (id) on delete cascade,
  team_id uuid references public.teams (id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists user_notifications_user_unread_idx
  on public.user_notifications (user_id, is_read, created_at desc);

alter table public.user_notifications enable row level security;
revoke all on table public.user_notifications from public, anon, authenticated;
grant select, delete on table public.user_notifications to authenticated;
grant update (is_read) on table public.user_notifications to authenticated;

create policy user_notifications_select on public.user_notifications
  for select to authenticated
  using (user_id = auth.uid());

create policy user_notifications_update on public.user_notifications
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy user_notifications_delete on public.user_notifications
  for delete to authenticated
  using (user_id = auth.uid());

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public'
         and tablename = 'user_notifications'
     ) then
    alter publication supabase_realtime add table public.user_notifications;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Updated RLS for public.challenge & public.partisipasi_challenge
-- ---------------------------------------------------------------------------
alter policy challenge_select on public.challenge
  using (
    team_id is null
    or public.is_coach_or_admin()
    or public.is_team_member_strict(team_id)
    or exists (
      select 1 from public.teams t
      where t.id = challenge.team_id
        and (not t.is_private or t.dibuat_oleh = auth.uid())
    )
  );

alter policy challenge_insert on public.challenge
  with check (
    auth.uid() is not null
    and (dibuat_oleh is null or dibuat_oleh = auth.uid())
    and (
      team_id is null
      or public.can_manage_team_challenge(team_id)
    )
  );

alter policy challenge_write on public.challenge
  using (
    (team_id is null and dibuat_oleh = auth.uid())
    or (team_id is not null and public.can_manage_team_challenge(team_id))
    or public.is_coach_or_admin()
  )
  with check (
    (team_id is null and (dibuat_oleh is null or dibuat_oleh = auth.uid()))
    or (team_id is not null and public.can_manage_team_challenge(team_id))
    or public.is_coach_or_admin()
  );

alter policy partisipasi_select on public.partisipasi_challenge
  using (
    user_id = auth.uid()
    or public.is_coach_or_admin()
    or exists (
      select 1 from public.challenge c
      where c.id = partisipasi_challenge.challenge_id
        and c.team_id is not null
        and (
          public.is_team_member_strict(c.team_id)
          or public.can_manage_team_challenge(c.team_id)
        )
    )
  );

alter policy partisipasi_insert on public.partisipasi_challenge
  with check (
    public.is_coach_or_admin()
    or (
      user_id = auth.uid()
      and exists (
        select 1 from public.challenge c
        where c.id = challenge_id
          and (
            c.team_id is null
            or public.is_team_member_strict(c.team_id)
            or public.can_manage_team_challenge(c.team_id)
          )
      )
    )
  );

-- ---------------------------------------------------------------------------
-- 5. Active slot enforcement (max 1 incomplete Coach + 1 incomplete Solo)
-- ---------------------------------------------------------------------------
create or replace function public.partisipasi_enforce_active_slot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_team boolean;
begin
  if coalesce(new.berhasil, false) then
    new.is_active := false;
    return new;
  end if;

  if current_setting('pacer.deactivating_slots', true) = '1'
     or not coalesce(new.is_active, false) then
    return new;
  end if;

  select (c.team_id is not null)
  into v_is_team
  from public.challenge c
  where c.id = new.challenge_id;

  if v_is_team is null then
    return new;
  end if;

  perform set_config('pacer.deactivating_slots', '1', true);
  update public.partisipasi_challenge p
     set is_active = false
    from public.challenge c
   where c.id = p.challenge_id
     and p.user_id = new.user_id
     and p.challenge_id <> new.challenge_id
     and coalesce(p.berhasil, false) = false
     and p.is_active = true
     and ((c.team_id is not null) = v_is_team);
  perform set_config('pacer.deactivating_slots', '0', true);

  return new;
end;
$$;

create or replace trigger partisipasi_enforce_active_slot
  before insert or update of is_active, berhasil
  on public.partisipasi_challenge
  for each row
  execute function public.partisipasi_enforce_active_slot();

revoke all on function public.partisipasi_enforce_active_slot() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Team challenge assignment & notification helper + triggers
-- ---------------------------------------------------------------------------
create or replace function public._format_challenge_summary(
  p_judul text,
  p_jenis text,
  p_target_nilai numeric,
  p_target_satuan text
)
returns text
language sql
immutable
set search_path = public
as $$
  select coalesce(
    nullif(trim(p_judul), ''),
    case p_jenis
      when 'lari' then 'Lari'
      when 'joging' then 'Joging'
      when 'bersepeda' then 'Bersepeda'
      else 'Berjalan'
    end
    || ' · '
    || case
      when p_target_satuan = 'waktu_s'
        then greatest(1, round(coalesce(p_target_nilai, 0) / 60.0))::int || ' mnt'
      else to_char(coalesce(p_target_nilai, 0) / 1000.0, 'FM999990.##') || ' km'
    end
  );
$$;

revoke all on function public._format_challenge_summary(text, text, numeric, text) from public, anon, authenticated;

create or replace function public.challenge_team_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_name text;
  v_summary text;
  v_member record;
  v_has_active boolean;
begin
  if new.team_id is null then
    return new;
  end if;

  select nama into v_team_name from public.teams where id = new.team_id;
  v_summary := public._format_challenge_summary(
    new.judul,
    new.jenis,
    new.target_nilai,
    new.target_satuan
  );

  for v_member in
    select m.user_id
    from public.team_members m
    where m.team_id = new.team_id
  loop
    select exists (
      select 1
      from public.partisipasi_challenge p
      join public.challenge c on c.id = p.challenge_id
      where p.user_id = v_member.user_id
        and c.team_id is not null
        and coalesce(p.berhasil, false) = false
        and p.is_active = true
    ) into v_has_active;

    insert into public.partisipasi_challenge (
      challenge_id,
      user_id,
      progress_nilai,
      berhasil,
      is_active
    )
    values (
      new.id,
      v_member.user_id,
      0,
      false,
      not v_has_active
    )
    on conflict (challenge_id, user_id) do nothing;

    if v_member.user_id <> coalesce(new.dibuat_oleh, '00000000-0000-0000-0000-000000000000'::uuid) then
      insert into public.user_notifications (
        user_id,
        type,
        title,
        body,
        challenge_id,
        team_id
      )
      values (
        v_member.user_id,
        'team_challenge_assigned',
        'Challenge Tim · ' || coalesce(nullif(trim(v_team_name), ''), 'Tim'),
        v_summary || case
          when v_has_active then ' (Menunggu — ketuk untuk pilih aktif)'
          else ' (Aktif untuk aktivitas berikutnya)'
        end,
        new.id,
        new.team_id
      );
    end if;
  end loop;

  return new;
end;
$$;

create or replace trigger challenge_team_after_insert
  after insert on public.challenge
  for each row
  when (new.team_id is not null)
  execute function public.challenge_team_after_insert();

revoke all on function public.challenge_team_after_insert() from public, anon, authenticated;

-- Also enroll new team members into any currently open Team Challenges
create or replace function public.team_member_assign_open_challenges()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team_name text;
  v_ch record;
  v_has_active boolean;
  v_summary text;
begin
  select nama into v_team_name from public.teams where id = new.team_id;

  for v_ch in
    select c.*
    from public.challenge c
    where c.team_id = new.team_id
      and (c.waktu_selesai is null or c.waktu_selesai > now())
    order by c.created_at desc
  loop
    select exists (
      select 1
      from public.partisipasi_challenge p
      join public.challenge c2 on c2.id = p.challenge_id
      where p.user_id = new.user_id
        and c2.team_id is not null
        and coalesce(p.berhasil, false) = false
        and p.is_active = true
    ) into v_has_active;

    insert into public.partisipasi_challenge (
      challenge_id,
      user_id,
      progress_nilai,
      berhasil,
      is_active
    )
    values (
      v_ch.id,
      new.user_id,
      0,
      false,
      not v_has_active
    )
    on conflict (challenge_id, user_id) do nothing;

    if new.user_id <> coalesce(v_ch.dibuat_oleh, '00000000-0000-0000-0000-000000000000'::uuid) then
      v_summary := public._format_challenge_summary(
        v_ch.judul,
        v_ch.jenis,
        v_ch.target_nilai,
        v_ch.target_satuan
      );
      insert into public.user_notifications (
        user_id,
        type,
        title,
        body,
        challenge_id,
        team_id
      )
      select
        new.user_id,
        'team_challenge_assigned',
        'Challenge Tim · ' || coalesce(nullif(trim(v_team_name), ''), 'Tim'),
        v_summary || case
          when v_has_active then ' (Menunggu — ketuk untuk pilih aktif)'
          else ' (Aktif untuk aktivitas berikutnya)'
        end,
        v_ch.id,
        new.team_id
      where not exists (
        select 1 from public.user_notifications un
        where un.user_id = new.user_id
          and un.challenge_id = v_ch.id
          and un.type = 'team_challenge_assigned'
      );
    end if;
  end loop;

  return new;
end;
$$;

create or replace trigger team_member_assign_open_challenges
  after insert on public.team_members
  for each row
  execute function public.team_member_assign_open_challenges();

revoke all on function public.team_member_assign_open_challenges() from public, anon, authenticated;

-- Notification when a challenge is completed
create or replace function public.partisipasi_completion_notify()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ch record;
  v_summary text;
begin
  if not coalesce(new.berhasil, false) then
    return new;
  end if;
  if tg_op = 'UPDATE' and coalesce(old.berhasil, false) then
    return new;
  end if;

  select c.*, t.nama as team_nama
  into v_ch
  from public.challenge c
  left join public.teams t on t.id = c.team_id
  where c.id = new.challenge_id;

  if not found then
    return new;
  end if;

  v_summary := public._format_challenge_summary(
    v_ch.judul,
    v_ch.jenis,
    v_ch.target_nilai,
    v_ch.target_satuan
  );

  insert into public.user_notifications (
    user_id,
    type,
    title,
    body,
    challenge_id,
    team_id
  )
  select
    new.user_id,
    'challenge_completed',
    'Challenge Selesai!',
    case
      when v_ch.team_nama is not null then '[' || v_ch.team_nama || '] ' || v_summary
      else v_summary
    end,
    new.challenge_id,
    v_ch.team_id
  where not exists (
    select 1 from public.user_notifications un
    where un.user_id = new.user_id
      and un.challenge_id = new.challenge_id
      and un.type = 'challenge_completed'
  );

  return new;
end;
$$;

create or replace trigger partisipasi_completion_notify
  after insert or update of berhasil
  on public.partisipasi_challenge
  for each row
  execute function public.partisipasi_completion_notify();

revoke all on function public.partisipasi_completion_notify() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 7. Challenge progress recompute honoring per-activity challenge_ids
-- ---------------------------------------------------------------------------
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

create or replace trigger aktivitas_challenge_progress_trigger
  after insert or update of selesai_at, jarak_m, durasi_s, jenis, mulai_at, challenge_ids or delete
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

-- ---------------------------------------------------------------------------
-- 8. Client RPCs: activate/switch active challenge & Coach Ketua promotion
-- ---------------------------------------------------------------------------
create or replace function public.activate_challenge(p_challenge_id uuid)
returns setof public.partisipasi_challenge
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_team_id uuid;
begin
  if v_uid is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select team_id into v_team_id
  from public.challenge
  where id = p_challenge_id;

  if not found then
    raise exception 'Challenge not found' using errcode = 'P0002';
  end if;

  if v_team_id is not null
     and not public.is_coach_or_admin()
     and not public.is_team_member_strict(v_team_id)
     and not public.can_manage_team_challenge(v_team_id) then
    raise exception 'not a member of this team (RLS 42501)' using errcode = '42501';
  end if;

  insert into public.partisipasi_challenge (
    challenge_id,
    user_id,
    progress_nilai,
    berhasil,
    is_active
  )
  values (p_challenge_id, v_uid, 0, false, true)
  on conflict (challenge_id, user_id) do update
    set is_active = case
      when public.partisipasi_challenge.berhasil then false
      else true
    end;

  perform public.recompute_user_challenge_progress(v_uid);

  return query
    select p.*
    from public.partisipasi_challenge p
    where p.user_id = v_uid
    order by p.created_at desc;
end;
$$;

revoke all on function public.activate_challenge(uuid) from public, anon;
grant execute on function public.activate_challenge(uuid) to authenticated;

create or replace function public.set_team_member_role(
  p_team_id uuid,
  p_user_id uuid,
  p_peran text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_team_name text;
  v_old_role text;
begin
  if v_uid is null or not public.is_coach_or_admin() then
    raise exception 'not allowed: coach or admin required (RLS 42501)' using errcode = '42501';
  end if;

  if p_peran not in ('anggota', 'ketua') then
    raise exception 'invalid peran: %', p_peran using errcode = '22023';
  end if;

  select peran into v_old_role
  from public.team_members
  where team_id = p_team_id and user_id = p_user_id;

  if v_old_role is null then
    raise exception 'member not found in team' using errcode = 'P0002';
  end if;

  update public.team_members
     set peran = p_peran
   where team_id = p_team_id and user_id = p_user_id;

  if v_old_role <> p_peran then
    select nama into v_team_name from public.teams where id = p_team_id;
    insert into public.user_notifications (
      user_id,
      type,
      title,
      body,
      team_id
    )
    values (
      p_user_id,
      'team_role_changed',
      'Peran Tim Diperbarui',
      case
        when p_peran = 'ketua'
          then 'Kamu ditunjuk sebagai Ketua di tim ' || coalesce(nullif(trim(v_team_name), ''), 'Tim') || ' dan dapat membuat challenge tim.'
        else 'Peran kamu di tim ' || coalesce(nullif(trim(v_team_name), ''), 'Tim') || ' kini menjadi Anggota.'
      end,
      p_team_id
    );
  end if;
end;
$$;

revoke all on function public.set_team_member_role(uuid, uuid, text) from public, anon;
grant execute on function public.set_team_member_role(uuid, uuid, text) to authenticated;

-- Normalize pre-existing participations so each user holds at most
-- 1 active incomplete Solo and 1 active incomplete Team challenge.
with ranked as (
  select
    p.id,
    p.berhasil,
    row_number() over (
      partition by p.user_id, (c.team_id is not null)
      order by p.created_at desc nulls last, p.id
    ) as rn
  from public.partisipasi_challenge p
  join public.challenge c on c.id = p.challenge_id
  where coalesce(p.berhasil, false) = false
)
update public.partisipasi_challenge p
   set is_active = (r.rn = 1)
  from ranked r
 where p.id = r.id;

update public.partisipasi_challenge
   set is_active = false
 where coalesce(berhasil, false) = true and is_active = true;
