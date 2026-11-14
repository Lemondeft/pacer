-- Scope 'coach' visibility and team challenge management strictly to teams
-- the coach belongs to or created, separating 'admin' (platform-wide) from 'coach'.

-- ---------------------------------------------------------------------------
-- 1. Platform-wide admin helper (peran = 'admin' ONLY)
-- ---------------------------------------------------------------------------
create or replace function public.is_admin()
returns boolean
language sql
security invoker
set search_path = public
stable
as $$
  select auth.uid() is not null
    and exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.peran = 'admin'
    );
$$;

revoke all on function public.is_admin() from public, anon;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Private teams visibility: ONLY members, creator, or admin (never non-member coach)
-- ---------------------------------------------------------------------------
drop policy if exists teams_select on public.teams;
create policy teams_select on public.teams for select to authenticated
  using (
    not is_private
    or public.is_admin()
    or dibuat_oleh = auth.uid()
    or public.is_team_member_strict(id)
  );

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
    where (
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
    raise exception 'sign-in required (RLS 42501)';
  end if;

  if not exists (
    select 1 from public.teams t
    where t.id = p_team_id
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
    raise exception 'not allowed (RLS 42501)';
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
      case when m.peran = 'ketua' then 0 else 1 end,
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
    raise exception 'sign-in required (RLS 42501)';
  end if;

  select t.is_private, t.dibuat_oleh
  into v_is_private, v_creator
  from public.teams t
  where t.id = p_team_id;

  if v_is_private is null then
    raise exception 'team not found (RLS 42501)';
  end if;

  select exists (
    select 1 from public.team_members me
    where me.team_id = p_team_id and me.user_id = v_uid
  ) into v_is_member;

  if v_is_private
     and v_creator is distinct from v_uid
     and not v_is_member
     and not public.is_admin() then
    raise exception 'not allowed (RLS 42501)';
  end if;

  if v_is_private then
    v_can_view_code := v_is_member or (v_creator = v_uid);
    v_can_manage_code := (v_creator = v_uid)
      or exists (
        select 1 from public.team_members m
        where m.team_id = p_team_id
          and m.user_id = v_uid
          and m.peran = 'ketua'
      );
  else
    v_can_view_code := v_is_member or public.can_manage_team(p_team_id);
    v_can_manage_code := public.can_manage_team(p_team_id);
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

-- ---------------------------------------------------------------------------
-- 3. Scope team challenge management & policies to joined/created teams
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
      public.is_admin()
      or exists (
        select 1 from public.teams t
        where t.id = p_team_id and t.dibuat_oleh = auth.uid()
      )
      or exists (
        select 1
        from public.team_members m
        join public.users u on u.id = m.user_id
        where m.team_id = p_team_id
          and m.user_id = auth.uid()
          and (m.peran = 'ketua' or u.peran in ('coach', 'admin'))
      )
    );
$$;

alter policy challenge_select on public.challenge
  using (
    team_id is null
    or public.is_admin()
    or public.is_team_member_strict(team_id)
    or exists (
      select 1 from public.teams t
      where t.id = challenge.team_id
        and (not t.is_private or t.dibuat_oleh = auth.uid())
    )
  );

alter policy challenge_write on public.challenge
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

alter policy partisipasi_select on public.partisipasi_challenge
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

alter policy partisipasi_insert on public.partisipasi_challenge
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
     and not public.is_admin()
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
  if v_uid is null or not (
    public.is_admin()
    or (
      exists (select 1 from public.users u where u.id = v_uid and u.peran = 'coach')
      and (
        exists (select 1 from public.teams t where t.id = p_team_id and t.dibuat_oleh = v_uid)
        or public.is_team_member_strict(p_team_id)
      )
    )
  ) then
    raise exception 'not allowed: team coach or admin required (RLS 42501)' using errcode = '42501';
  end if;

  if p_peran not in ('anggota', 'ketua') then
    raise exception 'invalid peran: %', p_peran using errcode = '22023';
  end if;

  select peran into v_old_role
  from public.team_members
  where team_id = p_team_id and user_id = p_user_id;

  if not found then
    raise exception 'member not found in team' using errcode = 'P0002';
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
        when p_peran = 'ketua' then 'Anda ditunjuk menjadi Ketua Tim.'
        else 'Peran Anda di tim diperbarui menjadi Anggota.'
      end,
      p_team_id
    );
  end if;
end;
$$;
