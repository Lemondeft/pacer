-- Team-Scoped Coach Roles & 7-Day Auto-Expiration for Abandoned Empty Teams.
--
-- Goals:
-- 1. Any authenticated user can create a team and automatically becomes
--    'coach' for THAT team only (public.team_members.peran = 'coach').
-- 2. Global public.users.peran = 'coach' no longer grants cross-team bypasses;
--    only platform 'admin' retains global moderation authority.
-- 3. Every newly created team starts with expires_at = now() + interval '7 days'.
--    The moment a second user joins (member count >= 2), a trigger flips
--    expires_at to NULL, permanently graduating the team into an active state.
-- 4. Expired teams (expires_at <= now()) are immediately hidden by RLS and
--    rejected by join/read RPCs, and permanently deleted daily by pg_cron.
-- 5. Coaches may only read workout metrics (aktivitas, statistik, streak) of
--    athletes sharing an active team where the caller has peran = 'coach'.
--    GPS route points (rute_points) remain strictly owner-only.

-- ---------------------------------------------------------------------------
-- 1. Schema additions & role check constraint update
-- ---------------------------------------------------------------------------
alter table public.teams
  add column if not exists expires_at timestamptz;

create index if not exists teams_expires_at_idx
  on public.teams (expires_at)
  where expires_at is not null;

-- Update team_members.peran CHECK constraint to allow ('anggota', 'ketua', 'coach').
do $$
declare
  v_conname text;
begin
  for v_conname in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'team_members'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%peran%'
  loop
    execute format('alter table public.team_members drop constraint %I', v_conname);
  end loop;
end $$;

alter table public.team_members
  add constraint team_members_peran_check
  check (peran in ('anggota', 'ketua', 'coach'));

-- ---------------------------------------------------------------------------
-- 2. Team-scoped security helper functions (SECURITY DEFINER + locked search_path
--    to prevent RLS infinite recursion between public.teams and public.team_members)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.peran = 'admin'
    );
$$;

create or replace function public.is_team_active(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select p_team_id is not null
    and exists (
      select 1 from public.teams t
      where t.id = p_team_id
        and (t.expires_at is null or t.expires_at > now())
    );
$$;

create or replace function public.is_team_member_strict(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and public.is_team_active(p_team_id)
    and exists (
      select 1 from public.team_members m
      where m.team_id = p_team_id
        and m.user_id = auth.uid()
    );
$$;

-- Used by chat_messages RLS: strictly active team members or platform admin.
create or replace function public.is_team_member(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and (
      public.is_admin()
      or public.is_team_member_strict(p_team_id)
    );
$$;

create or replace function public.is_team_coach(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and public.is_team_active(p_team_id)
    and exists (
      select 1 from public.team_members m
      where m.team_id = p_team_id
        and m.user_id = auth.uid()
        and m.peran = 'coach'
    );
$$;

create or replace function public.is_team_leader_or_coach(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and public.is_team_active(p_team_id)
    and exists (
      select 1 from public.team_members m
      where m.team_id = p_team_id
        and m.user_id = auth.uid()
        and m.peran in ('coach', 'ketua')
    );
$$;

create or replace function public.can_manage_team(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and (
      public.is_admin()
      or public.is_team_coach(p_team_id)
    );
$$;

create or replace function public.can_manage_team_challenge(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select p_team_id is not null
    and auth.uid() is not null
    and (
      public.is_admin()
      or public.is_team_leader_or_coach(p_team_id)
    );
$$;

-- Strictly team-scoped coach read check for aktivitas / statistik / streak.
-- A coach can read metrics ONLY for athletes in an active team where the caller
-- holds team_members.peran = 'coach'. Leaving the team revokes access immediately.
create or replace function public.can_coach_read_user(p_target_user_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select auth.uid() is not null
    and (
      auth.uid() = p_target_user_id
      or public.is_admin()
      or exists (
        select 1
        from public.team_members student_m
        join public.teams t on t.id = student_m.team_id
        join public.team_members coach_m on coach_m.team_id = t.id
        where student_m.user_id = p_target_user_id
          and coach_m.user_id = auth.uid()
          and coach_m.peran = 'coach'
          and (t.expires_at is null or t.expires_at > now())
      )
    );
$$;

-- ---------------------------------------------------------------------------
-- 3. Team lifecycle triggers (server-enforced 7-day expiry, pending cap,
--    creator -> 'coach', graduation on 2nd member, role & sole-coach guards)
-- ---------------------------------------------------------------------------
create or replace function public.teams_before_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_pending_count bigint;
begin
  if v_uid is not null then
    new.dibuat_oleh := v_uid;

    -- Cap unactivated pending teams per non-admin user to prevent spam clutter.
    if not public.is_admin() then
      select count(*)::bigint
        into v_pending_count
      from public.teams t
      where t.dibuat_oleh = v_uid
        and t.expires_at is not null
        and t.expires_at > now();

      if v_pending_count >= 3 then
        raise exception 'pending team limit reached: invite a member to an existing pending team first'
          using errcode = 'P0001';
      end if;
    end if;

    -- Server-authoritative 7-day graduation deadline (clients cannot forge NULL).
    new.expires_at := now() + interval '7 days';
  elsif new.expires_at is null and current_setting('pacer.skip_team_expiry', true) <> '1' then
    new.expires_at := now() + interval '7 days';
  end if;

  return new;
end;
$$;

drop trigger if exists teams_before_insert on public.teams;
create trigger teams_before_insert
  before insert on public.teams
  for each row
  execute function public.teams_before_insert();

-- Prevent client tampering with expires_at or dibuat_oleh on UPDATE.
create or replace function public.teams_before_update_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if current_setting('pacer.graduating_team', true) = '1'
     or current_setting('request.jwt.claim.role', true) = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin')
       and coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '') = ''
       and coalesce(nullif(current_setting('role', true), ''), 'none') in ('none', 'postgres', 'supabase_admin')
     )
     or public.is_admin() then
    return new;
  end if;

  if new.expires_at is distinct from old.expires_at then
    raise exception 'expires_at is managed automatically (RLS 42501)'
      using errcode = '42501';
  end if;

  if new.dibuat_oleh is distinct from old.dibuat_oleh then
    raise exception 'dibuat_oleh is immutable (RLS 42501)'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

drop trigger if exists teams_before_update_guard on public.teams;
create trigger teams_before_update_guard
  before update on public.teams
  for each row
  execute function public.teams_before_update_guard();

-- Mark parent team delete so sole-coach trigger allows cascade cleanup.
create or replace function public.teams_before_delete_flag()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform set_config('pacer.deleting_team_id', old.id::text, true);
  return old;
end;
$$;

drop trigger if exists teams_before_delete_flag on public.teams;
create trigger teams_before_delete_flag
  before delete on public.teams
  for each row
  execute function public.teams_before_delete_flag();

-- Every new team gets an 8-char secret invite code; creator becomes its 'coach'.
create or replace function public.teams_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.team_secrets (team_id, invite_code)
  values (new.id, upper(substr(md5(gen_random_uuid()::text), 1, 8)))
  on conflict (team_id) do nothing;

  if new.dibuat_oleh is not null then
    insert into public.team_members (team_id, user_id, peran)
    values (new.id, new.dibuat_oleh, 'coach')
    on conflict (team_id, user_id) do update
      set peran = 'coach';
  end if;

  return new;
end;
$$;

drop trigger if exists teams_after_insert on public.teams;
create trigger teams_after_insert
  after insert on public.teams
  for each row
  execute function public.teams_after_insert();

-- Graduate pending team permanently the moment a 2nd member joins.
create or replace function public.team_members_after_insert_graduate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_count bigint;
begin
  select count(*)::bigint
    into v_count
  from public.team_members m
  where m.team_id = new.team_id;

  if v_count >= 2 then
    perform set_config('pacer.graduating_team', '1', true);
    update public.teams
       set expires_at = null
     where id = new.team_id
       and expires_at is not null
       and expires_at > now();
    perform set_config('pacer.graduating_team', '0', true);
  end if;

  return new;
end;
$$;

drop trigger if exists team_members_after_insert_graduate on public.team_members;
create trigger team_members_after_insert_graduate
  after insert on public.team_members
  for each row
  execute function public.team_members_after_insert_graduate();

-- Guard team_members.peran updates: only that team's coach or platform admin.
create or replace function public.team_members_peran_guard_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if new.peran is not distinct from old.peran then
    return new;
  end if;

  if current_setting('pacer.migrating_roles', true) = '1'
     or current_setting('request.jwt.claim.role', true) = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin')
       and coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '') = ''
       and coalesce(nullif(current_setting('role', true), ''), 'none') in ('none', 'postgres', 'supabase_admin')
     ) then
    return new;
  end if;

  if public.is_admin() or public.is_team_coach(old.team_id) then
    return new;
  end if;

  raise exception 'peran change denied: only team coach or admin may update peran (RLS 42501)'
    using errcode = '42501';
end;
$$;

drop trigger if exists team_members_peran_guard_trigger on public.team_members;
create trigger team_members_peran_guard_trigger
  before update of peran on public.team_members
  for each row
  execute function public.team_members_peran_guard_trigger();

-- Backfill existing team creators and existing team-joined global coaches
-- now that the updated team_members_peran_guard_trigger is in place.
do $$
begin
  perform set_config('pacer.migrating_roles', '1', true);

  insert into public.team_members (team_id, user_id, peran)
  select t.id, t.dibuat_oleh, 'coach'
  from public.teams t
  where t.dibuat_oleh is not null
  on conflict (team_id, user_id) do update
    set peran = 'coach';

  update public.team_members m
     set peran = 'coach'
    from public.users u
   where u.id = m.user_id
     and u.peran = 'coach'
     and m.peran <> 'coach';

  perform set_config('pacer.migrating_roles', '0', true);
end $$;

-- Prevent sole coach from leaving a team (must promote a co-coach or delete team),
-- while never blocking ON DELETE CASCADE from team deletion, user deletion, or admin.
create or replace function public.team_members_before_delete_sole_coach()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_other_coaches bigint;
begin
  if old.peran <> 'coach' then
    return old;
  end if;

  if current_setting('pacer.deleting_team_id', true) = old.team_id::text
     or current_setting('request.jwt.claim.role', true) = 'service_role'
     or (
       session_user in ('postgres', 'supabase_admin')
       and coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '') = ''
       and coalesce(nullif(current_setting('role', true), ''), 'none') in ('none', 'postgres', 'supabase_admin')
     )
     or public.is_admin()
     or not exists (select 1 from public.teams t where t.id = old.team_id)
     or not exists (select 1 from public.users u where u.id = old.user_id) then
    return old;
  end if;

  select count(*)::bigint
    into v_other_coaches
  from public.team_members m
  where m.team_id = old.team_id
    and m.user_id <> old.user_id
    and m.peran = 'coach';

  if v_other_coaches = 0 then
    raise exception 'sole team coach cannot leave: promote another coach or delete the team'
      using errcode = 'P0001';
  end if;

  return old;
end;
$$;

drop trigger if exists team_members_before_delete_sole_coach on public.team_members;
create trigger team_members_before_delete_sole_coach
  before delete on public.team_members
  for each row
  execute function public.team_members_before_delete_sole_coach();

-- ---------------------------------------------------------------------------
-- 4. RLS Policy Updates (open team creation + team-scoped coach + expiry gate)
-- ---------------------------------------------------------------------------

-- public.teams: explicit per-command policies (no ambiguous FOR ALL).
drop policy if exists teams_select on public.teams;
drop policy if exists teams_write on public.teams;
drop policy if exists teams_insert on public.teams;
drop policy if exists teams_update on public.teams;
drop policy if exists teams_delete on public.teams;

create policy teams_select on public.teams
  for select to authenticated
  using (
    (expires_at is null or expires_at > now())
    and (
      not is_private
      or public.is_admin()
      or dibuat_oleh = auth.uid()
      or public.is_team_member_strict(id)
    )
  );

create policy teams_insert on public.teams
  for insert to authenticated
  with check (
    auth.uid() is not null
    and (dibuat_oleh is null or dibuat_oleh = auth.uid())
  );

create policy teams_update on public.teams
  for update to authenticated
  using (
    public.is_admin()
    or public.is_team_coach(id)
  )
  with check (
    public.is_admin()
    or public.is_team_coach(id)
  );

create policy teams_delete on public.teams
  for delete to authenticated
  using (
    public.is_admin()
    or public.is_team_coach(id)
    or dibuat_oleh = auth.uid()
  );

-- public.team_members: own rows, team's coach, or platform admin.
drop policy if exists members_select on public.team_members;
drop policy if exists members_insert on public.team_members;
drop policy if exists members_update on public.team_members;
drop policy if exists members_delete on public.team_members;

create policy members_select on public.team_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or public.is_team_coach(team_id)
  );

-- Regular joins always go through SECURITY DEFINER join_team / join_team_by_code.
create policy members_insert on public.team_members
  for insert to authenticated
  with check (public.is_admin());

create policy members_update on public.team_members
  for update to authenticated
  using (
    public.is_admin()
    or public.is_team_coach(team_id)
  )
  with check (
    public.is_admin()
    or public.is_team_coach(team_id)
  );

create policy members_delete on public.team_members
  for delete to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or public.is_team_coach(team_id)
  );

-- public.challenge & public.partisipasi_challenge: active team gate + team-scoped coach.
drop policy if exists challenge_select on public.challenge;
create policy challenge_select on public.challenge
  for select to authenticated
  using (
    team_id is null
    or public.is_admin()
    or public.is_team_member_strict(team_id)
    or exists (
      select 1 from public.teams t
      where t.id = challenge.team_id
        and (t.expires_at is null or t.expires_at > now())
        and (not t.is_private or t.dibuat_oleh = auth.uid())
    )
  );

drop policy if exists challenge_write on public.challenge;
create policy challenge_write on public.challenge
  for all to authenticated
  using (
    (team_id is null and dibuat_oleh = auth.uid())
    or (team_id is not null and public.can_manage_team_challenge(team_id))
    or public.is_admin()
  )
  with check (
    (team_id is null and (dibuat_oleh is null or dibuat_oleh = auth.uid()))
    or (team_id is not null and public.can_manage_team_challenge(team_id))
    or public.is_admin()
  );

drop policy if exists partisipasi_select on public.partisipasi_challenge;
create policy partisipasi_select on public.partisipasi_challenge
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
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

drop policy if exists partisipasi_insert on public.partisipasi_challenge;
create policy partisipasi_insert on public.partisipasi_challenge
  for insert to authenticated
  with check (
    public.is_admin()
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

drop policy if exists partisipasi_update on public.partisipasi_challenge;
create policy partisipasi_update on public.partisipasi_challenge
  for update to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.challenge c
      where c.id = partisipasi_challenge.challenge_id
        and c.team_id is not null
        and public.is_team_coach(c.team_id)
    )
  );

drop policy if exists partisipasi_delete on public.partisipasi_challenge;
create policy partisipasi_delete on public.partisipasi_challenge
  for delete to authenticated
  using (
    user_id = auth.uid()
    or public.is_admin()
    or exists (
      select 1 from public.challenge c
      where c.id = partisipasi_challenge.challenge_id
        and c.team_id is not null
        and public.is_team_coach(c.team_id)
    )
  );

-- Workout metrics: team-scoped coach read; GPS routes strictly owner-only.
drop policy if exists aktivitas_coach_select on public.aktivitas;
create policy aktivitas_coach_select on public.aktivitas
  for select to authenticated
  using (public.can_coach_read_user(user_id));

drop policy if exists statistik_coach_select on public.statistik;
create policy statistik_coach_select on public.statistik
  for select to authenticated
  using (public.can_coach_read_user(user_id));

drop policy if exists streak_coach_select on public.streak;
create policy streak_coach_select on public.streak
  for select to authenticated
  using (public.can_coach_read_user(user_id));

drop policy if exists rute_coach_select on public.rute_points;

-- Platform leaderboards / peringkat writes restricted to platform admin.
drop policy if exists leaderboard_write on public.leaderboard;
drop policy if exists leaderboard_insert on public.leaderboard;
create policy leaderboard_write on public.leaderboard
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists peringkat_write on public.peringkat;
drop policy if exists peringkat_insert on public.peringkat;
create policy peringkat_write on public.peringkat
  for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- 5. Updated RPCs (expiry checks + team-scoped roles + co-coach promotion)
-- ---------------------------------------------------------------------------
create or replace function public.join_team(p_team_id uuid, p_code text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_private boolean;
  v_expires_at timestamptz;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'sign-in required (RLS 42501)' using errcode = '42501';
  end if;

  select t.is_private, t.expires_at
    into v_private, v_expires_at
  from public.teams t
  where t.id = p_team_id;

  if v_private is null then
    raise exception 'team not found (RLS 42501)' using errcode = 'P0002';
  end if;

  if v_expires_at is not null and v_expires_at <= now() then
    raise exception 'team expired' using errcode = 'P0002';
  end if;

  if v_private and not exists (
    select 1 from public.team_secrets s
    where s.team_id = p_team_id
      and s.invite_code = upper(trim(coalesce(p_code, '')))
  ) then
    raise exception 'wrong team code (RLS 42501)' using errcode = '42501';
  end if;

  insert into public.team_members (team_id, user_id, peran)
  values (p_team_id, auth.uid(), 'anggota')
  on conflict (team_id, user_id) do nothing
  returning id into v_id;

  if v_id is null then
    select id into v_id from public.team_members
    where team_id = p_team_id and user_id = auth.uid();
  end if;

  return v_id;
end;
$$;

create or replace function public.join_team_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team uuid;
  v_expires_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'sign-in required (RLS 42501)' using errcode = '42501';
  end if;

  select s.team_id, t.expires_at
    into v_team, v_expires_at
  from public.team_secrets s
  join public.teams t on t.id = s.team_id
  where s.invite_code = upper(trim(coalesce(p_code, '')));

  if v_team is null then
    raise exception 'wrong team code (RLS 42501)' using errcode = '42501';
  end if;

  if v_expires_at is not null and v_expires_at <= now() then
    raise exception 'team expired' using errcode = 'P0002';
  end if;

  insert into public.team_members (team_id, user_id, peran)
  values (v_team, auth.uid(), 'anggota')
  on conflict (team_id, user_id) do nothing;

  return v_team;
end;
$$;

create or replace function public.get_team_member_counts()
returns table (
  team_id uuid,
  member_count bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  return query
    select
      t.id as team_id,
      count(m.id)::bigint as member_count
    from public.teams t
    left join public.team_members m on m.team_id = t.id
    where (t.expires_at is null or t.expires_at > now())
      and (
        not t.is_private
        or t.dibuat_oleh = auth.uid()
        or public.is_admin()
        or exists (
          select 1 from public.team_members me
          where me.team_id = t.id and me.user_id = auth.uid()
        )
      )
    group by t.id;
end;
$$;

create or replace function public.get_team_roster(p_team_id uuid)
returns table (
  user_id uuid,
  nama text,
  peran text,
  app_peran text,
  joined_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null then
    raise exception 'sign-in required (RLS 42501)' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.teams t
    where t.id = p_team_id
      and (t.expires_at is null or t.expires_at > now())
      and (
        not t.is_private
        or t.dibuat_oleh = auth.uid()
        or public.is_admin()
        or exists (
          select 1 from public.team_members me
          where me.team_id = t.id and me.user_id = auth.uid()
        )
      )
  ) then
    raise exception 'not allowed (RLS 42501)' using errcode = '42501';
  end if;

  return query
    select
      m.user_id,
      coalesce(nullif(trim(u.nama), ''), left(m.user_id::text, 8) || '…') as nama,
      m.peran,
      u.peran as app_peran,
      m.created_at as joined_at
    from public.team_members m
    join public.users u on u.id = m.user_id
    where m.team_id = p_team_id
    order by
      case m.peran when 'coach' then 0 when 'ketua' then 1 else 2 end,
      m.created_at asc,
      nama asc;
end;
$$;

create or replace function public.get_team_dashboard_stats(p_team_id uuid)
returns table (
  member_count bigint,
  active_members_week bigint,
  total_week_sessions bigint,
  total_week_km numeric,
  total_all_km numeric,
  is_member boolean,
  can_view_code boolean,
  can_manage_code boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_is_private boolean;
  v_creator uuid;
  v_expires_at timestamptz;
  v_week_start timestamptz := date_trunc('week', timezone('UTC', now()));
  v_is_member boolean := false;
  v_can_view_code boolean := false;
  v_can_manage_code boolean := false;
  v_member_count bigint := 0;
  v_active_members_week bigint := 0;
  v_total_week_sessions bigint := 0;
  v_total_week_km numeric := 0;
  v_total_all_km numeric := 0;
begin
  if v_uid is null then
    raise exception 'sign-in required (RLS 42501)' using errcode = '42501';
  end if;

  select t.is_private, t.dibuat_oleh, t.expires_at
    into v_is_private, v_creator, v_expires_at
  from public.teams t
  where t.id = p_team_id;

  if v_is_private is null or (v_expires_at is not null and v_expires_at <= now()) then
    raise exception 'team not found (RLS 42501)' using errcode = 'P0002';
  end if;

  select exists (
    select 1 from public.team_members me
    where me.team_id = p_team_id and me.user_id = v_uid
  ) into v_is_member;

  if v_is_private
     and v_creator is distinct from v_uid
     and not v_is_member
     and not public.is_admin() then
    raise exception 'not allowed (RLS 42501)' using errcode = '42501';
  end if;

  if v_is_private then
    v_can_view_code := v_is_member or (v_creator = v_uid);
    v_can_manage_code := (v_creator = v_uid)
      or public.is_team_leader_or_coach(p_team_id);
  else
    v_can_view_code := v_is_member or public.is_admin() or public.is_team_leader_or_coach(p_team_id);
    v_can_manage_code := public.is_admin() or public.is_team_leader_or_coach(p_team_id);
  end if;

  select count(*)::bigint
    into v_member_count
  from public.team_members tm
  where tm.team_id = p_team_id;

  select
    coalesce(count(distinct a.user_id) filter (
      where coalesce(a.mulai_at, a.created_at) >= v_week_start
    ), 0)::bigint,
    coalesce(count(a.id) filter (
      where coalesce(a.mulai_at, a.created_at) >= v_week_start
    ), 0)::bigint,
    coalesce(sum(a.jarak_m) filter (
      where coalesce(a.mulai_at, a.created_at) >= v_week_start
    ), 0) / 1000.0,
    coalesce(sum(a.jarak_m), 0) / 1000.0
  into
    v_active_members_week,
    v_total_week_sessions,
    v_total_week_km,
    v_total_all_km
  from public.team_members m
  join public.aktivitas a
    on a.user_id = m.user_id
   and a.durasi_s is not null
   and a.durasi_s > 0
  where m.team_id = p_team_id;

  return query
    select
      v_member_count,
      v_active_members_week,
      v_total_week_sessions,
      v_total_week_km,
      v_total_all_km,
      v_is_member,
      v_can_view_code,
      v_can_manage_code;
end;
$$;

create or replace function public.can_view_private_invite_code(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.teams t
    where t.id = p_team_id
      and (t.expires_at is null or t.expires_at > now())
      and (
        (
          t.is_private
          and (
            t.dibuat_oleh = auth.uid()
            or exists (
              select 1 from public.team_members m
              where m.team_id = p_team_id
                and m.user_id = auth.uid()
            )
          )
        )
        or (
          not t.is_private
          and (
            public.is_admin()
            or public.is_team_leader_or_coach(p_team_id)
            or exists (
              select 1 from public.team_members m
              where m.team_id = p_team_id
                and m.user_id = auth.uid()
            )
          )
        )
      )
  );
$$;

create or replace function public.can_manage_private_invite_code(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.teams t
    where t.id = p_team_id
      and (t.expires_at is null or t.expires_at > now())
      and (
        (
          t.is_private
          and (
            t.dibuat_oleh = auth.uid()
            or public.is_team_leader_or_coach(p_team_id)
          )
        )
        or (
          not t.is_private
          and (public.is_admin() or public.is_team_leader_or_coach(p_team_id))
        )
      )
  );
$$;

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
  v_other_coaches bigint;
begin
  if v_uid is null or not (
    public.is_admin()
    or public.is_team_coach(p_team_id)
  ) then
    raise exception 'not allowed: team coach or admin required (RLS 42501)'
      using errcode = '42501';
  end if;

  if not public.is_team_active(p_team_id) then
    raise exception 'team expired' using errcode = 'P0002';
  end if;

  if p_peran not in ('anggota', 'ketua', 'coach') then
    raise exception 'invalid peran: %', p_peran using errcode = '22023';
  end if;

  select peran into v_old_role
  from public.team_members
  where team_id = p_team_id and user_id = p_user_id
  for update;

  if not found then
    raise exception 'member not found in team' using errcode = 'P0002';
  end if;

  -- Never allow demoting the last remaining coach of a team.
  if v_old_role = 'coach' and p_peran <> 'coach' then
    select count(*)::bigint
      into v_other_coaches
    from public.team_members m
    where m.team_id = p_team_id
      and m.user_id <> p_user_id
      and m.peran = 'coach';

    if v_other_coaches = 0 then
      raise exception 'cannot demote the last remaining coach of this team'
        using errcode = 'P0001';
    end if;
  end if;

  update public.team_members
     set peran = p_peran
   where team_id = p_team_id and user_id = p_user_id;

  if v_old_role is distinct from p_peran then
    select nama into v_team_name from public.teams where id = p_team_id;
    insert into public.user_notifications (
      user_id,
      type,
      title,
      body,
      team_id
    ) values (
      p_user_id,
      'team_role_changed',
      coalesce(v_team_name, 'Tim Pacer'),
      case
        when p_peran = 'coach' then 'Anda ditunjuk menjadi Coach Tim.'
        when p_peran = 'ketua' then 'Anda ditunjuk menjadi Ketua Tim.'
        else 'Peran Anda di tim diperbarui menjadi Anggota.'
      end,
      p_team_id
    );
  end if;
end;
$$;

create or replace function public.leaderboard_scope_user_ids(p_scope text)
returns setof uuid
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null then
    return;
  end if;

  if p_scope = 'team' then
    return query
      select distinct m2.user_id
      from public.team_members m1
      join public.teams t on t.id = m1.team_id
      join public.team_members m2 on m2.team_id = m1.team_id
      where m1.user_id = auth.uid()
        and (t.expires_at is null or t.expires_at > now());
  elsif p_scope = 'region' then
    return query
      select u.id from public.users u
      where u.region is not null
        and u.region = (select region from public.users where id = auth.uid());
  else
    return query select u.id from public.users u;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Function permission grants
-- ---------------------------------------------------------------------------
revoke all on function public.teams_before_insert() from public, anon, authenticated;
revoke all on function public.teams_before_update_guard() from public, anon, authenticated;
revoke all on function public.teams_before_delete_flag() from public, anon, authenticated;
revoke all on function public.teams_after_insert() from public, anon, authenticated;
revoke all on function public.team_members_after_insert_graduate() from public, anon, authenticated;
revoke all on function public.team_members_peran_guard_trigger() from public, anon, authenticated;
revoke all on function public.team_members_before_delete_sole_coach() from public, anon, authenticated;

revoke all on function public.can_view_private_invite_code(uuid) from public, anon, authenticated;
grant execute on function public.can_view_private_invite_code(uuid) to postgres, service_role;

revoke all on function public.can_manage_private_invite_code(uuid) from public, anon, authenticated;
grant execute on function public.can_manage_private_invite_code(uuid) to postgres, service_role;

do $$
declare
  f text;
begin
  foreach f in array array[
    'public.is_admin()',
    'public.is_team_active(uuid)',
    'public.is_team_member_strict(uuid)',
    'public.is_team_member(uuid)',
    'public.is_team_coach(uuid)',
    'public.is_team_leader_or_coach(uuid)',
    'public.can_manage_team(uuid)',
    'public.can_manage_team_challenge(uuid)',
    'public.can_coach_read_user(uuid)',
    'public.join_team(uuid, text)',
    'public.join_team_by_code(text)',
    'public.get_team_member_counts()',
    'public.get_team_roster(uuid)',
    'public.get_team_dashboard_stats(uuid)',
    'public.set_team_member_role(uuid, uuid, text)',
    'public.leaderboard_scope_user_ids(text)'
  ] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 7. Daily pg_cron cleanup sweep for abandoned unactivated teams
-- ---------------------------------------------------------------------------
do $$
declare
  v_job_id bigint;
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron with schema pg_catalog;
  end if;

  if exists (select 1 from pg_namespace where nspname = 'cron') then
    for v_job_id in
      select jobid from cron.job where jobname = 'pacer_cleanup_expired_teams'
    loop
      perform cron.unschedule(v_job_id);
    end loop;

    perform cron.schedule(
      'pacer_cleanup_expired_teams',
      '17 3 * * *',
      $cron$delete from public.teams where expires_at is not null and expires_at <= now();$cron$
    );
  end if;
end $$;
