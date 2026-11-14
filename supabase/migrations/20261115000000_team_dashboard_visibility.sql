-- Teams Dashboard, member counts, member rosters, and strict invite-code privacy.
--
-- Goals:
-- 1. Let authenticated users see member counts for all visible teams
--    (open public teams + teams they joined/created/coach) without exposing
--    individual team_members rows of unjoined teams.
-- 2. Let joined team members (not just coaches/admins) and viewers of open
--    public teams fetch the full member roster with display names, roles,
--    and join dates via a SECURITY DEFINER RPC.
-- 3. Provide aggregate-only weekly/total team activity stats for the Teams
--    Dashboard without exposing individual student workout rows.
-- 4. Tighten private team invite code access: NO ONE other than a private
--    team's creator (dibuat_oleh) or promoted captain (ketua) can read or
--    regenerate its secret invite code.

-- ---------------------------------------------------------------------------
-- 1. Member counts across visible teams
-- ---------------------------------------------------------------------------
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
      or public.is_coach_or_admin()
      or exists (
        select 1 from public.team_members me
        where me.team_id = t.id and me.user_id = auth.uid()
      )
    )
    group by t.id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Team roster RPC (accessible to joined members, managers, and public team viewers)
-- ---------------------------------------------------------------------------
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
        or public.is_coach_or_admin()
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

-- ---------------------------------------------------------------------------
-- 3. Aggregate-only Teams Dashboard stats (preserves individual aktivitas RLS)
-- ---------------------------------------------------------------------------
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
     and not public.is_coach_or_admin() then
    raise exception 'not allowed (RLS 42501)';
  end if;

  -- Strict private invite code gate:
  -- - View: NO ONE can see a private team's invite code unless given or unless
  --   they are in the team (joined member or creator).
  -- - Regenerate: creator, promoted 'ketua', or public team manager.
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
-- 4. Private team invite code RPCs:
--    - get_team_invite_code: private teams -> members/creator ONLY; public -> member/manager
--    - regenerate_team_invite_code: private teams -> creator/ketua ONLY; public -> manager
-- ---------------------------------------------------------------------------
create or replace function public.can_view_private_invite_code(p_team_id uuid)
returns boolean
language sql
security invoker
set search_path = public
stable
as $$
  select exists (
    select 1 from public.teams t
    where t.id = p_team_id
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
            public.can_manage_team(p_team_id)
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
security invoker
set search_path = public
stable
as $$
  select exists (
    select 1 from public.teams t
    where t.id = p_team_id
      and (
        (
          t.is_private
          and (
            t.dibuat_oleh = auth.uid()
            or exists (
              select 1 from public.team_members m
              where m.team_id = p_team_id
                and m.user_id = auth.uid()
                and m.peran = 'ketua'
            )
          )
        )
        or (not t.is_private and public.can_manage_team(p_team_id))
      )
  );
$$;

create or replace function public.get_team_invite_code(p_team_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if auth.uid() is null or not public.can_view_private_invite_code(p_team_id) then
    raise exception 'not allowed (RLS 42501)';
  end if;
  select invite_code into v_code from public.team_secrets where team_id = p_team_id;
  return v_code;
end;
$$;

create or replace function public.regenerate_team_invite_code(p_team_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text := upper(substr(md5(gen_random_uuid()::text), 1, 8));
begin
  if auth.uid() is null or not public.can_manage_private_invite_code(p_team_id) then
    raise exception 'not allowed (RLS 42501)';
  end if;
  update public.team_secrets set invite_code = v_code where team_id = p_team_id;
  return v_code;
end;
$$;

-- Helper strictly internal to Postgres/service_role (matches security remediation)
revoke all on function public.can_view_private_invite_code(uuid) from public, anon, authenticated;
grant execute on function public.can_view_private_invite_code(uuid) to postgres, service_role;

revoke all on function public.can_manage_private_invite_code(uuid) from public, anon, authenticated;
grant execute on function public.can_manage_private_invite_code(uuid) to postgres, service_role;

-- Client-callable RPCs: revoke anon, allow authenticated only
revoke all on function public.get_team_member_counts() from public, anon;
grant execute on function public.get_team_member_counts() to authenticated;

revoke all on function public.get_team_roster(uuid) from public, anon;
grant execute on function public.get_team_roster(uuid) to authenticated;

revoke all on function public.get_team_dashboard_stats(uuid) from public, anon;
grant execute on function public.get_team_dashboard_stats(uuid) to authenticated;

revoke all on function public.get_team_invite_code(uuid) from public, anon;
grant execute on function public.get_team_invite_code(uuid) to authenticated;

revoke all on function public.regenerate_team_invite_code(uuid) from public, anon;
grant execute on function public.regenerate_team_invite_code(uuid) to authenticated;
