-- Forward migration:
-- 1. Tighten pending single-member team expiration window from 7 days to 72 hours.
-- 2. Fix account deletion FKs (teams.dibuat_oleh, challenge.dibuat_oleh) with ON DELETE SET NULL.
-- 3. Ensure user-cascade deletion cleans up orphaned empty teams or promotes a successor coach
--    if a sole coach deletes their account, without leaving active teams coachless.
-- 4. Prevent a demoted creator from deleting an active graduated team via teams_delete RLS.

begin;

-- ---------------------------------------------------------------------------
-- 1. 72-hour pending team expiration in teams_before_insert()
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

    -- Server-authoritative 72-hour graduation deadline (clients cannot forge NULL).
    new.expires_at := now() + interval '72 hours';
  elsif new.expires_at is null and current_setting('pacer.skip_team_expiry', true) <> '1' then
    new.expires_at := now() + interval '72 hours';
  end if;

  return new;
end;
$$;

-- Cap any currently pending single-member teams to at most 72 hours from creation.
select set_config('pacer.graduating_team', '1', true);
update public.teams
   set expires_at = least(expires_at, coalesce(created_at, now()) + interval '72 hours')
 where expires_at is not null
   and expires_at > coalesce(created_at, now()) + interval '72 hours';
select set_config('pacer.graduating_team', '0', true);

-- ---------------------------------------------------------------------------
-- 2. Account deletion FK fixes (ON DELETE SET NULL for creator audit FKs)
-- ---------------------------------------------------------------------------
alter table public.teams
  drop constraint if exists teams_dibuat_oleh_fkey;

alter table public.teams
  add constraint teams_dibuat_oleh_fkey
  foreign key (dibuat_oleh) references public.users(id) on delete set null;

alter table public.challenge
  drop constraint if exists challenge_dibuat_oleh_fkey;

alter table public.challenge
  add constraint challenge_dibuat_oleh_fkey
  foreign key (dibuat_oleh) references public.users(id) on delete set null;

-- ---------------------------------------------------------------------------
-- 3. Sole-coach guard + orphaned/coachless team cleanup on account deletion
-- ---------------------------------------------------------------------------
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
       session_user in ('postgres', 'supabase_admin', 'supabase_auth_admin')
       and coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '') = ''
       and coalesce(nullif(current_setting('role', true), ''), 'none') in ('none', 'postgres', 'supabase_admin', 'supabase_auth_admin')
     )
     or public.is_admin()
     or not exists (select 1 from public.teams t where t.id = old.team_id)
     or not exists (select 1 from public.users u where u.id = old.user_id)
     or not exists (select 1 from auth.users au where au.id = old.user_id) then
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

create or replace function public.team_members_after_delete_cleanup()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_member_id uuid;
begin
  -- Skip if the team itself is already gone or mid-delete.
  if current_setting('pacer.deleting_team_id', true) = old.team_id::text
     or not exists (select 1 from public.teams t where t.id = old.team_id) then
    return old;
  end if;

  -- If zero members remain (e.g. solo creator deleted their account), remove the empty team.
  if not exists (
    select 1 from public.team_members m where m.team_id = old.team_id
  ) then
    perform set_config('pacer.deleting_team_id', old.team_id::text, true);
    delete from public.teams where id = old.team_id;
    perform set_config('pacer.deleting_team_id', '', true);
    return old;
  end if;

  -- If the deleted member was the last coach (e.g. account deletion / admin removal),
  -- promote the earliest ketua or member so the team never becomes unmanageable.
  if old.peran = 'coach'
     and not exists (
       select 1 from public.team_members m
       where m.team_id = old.team_id and m.peran = 'coach'
     ) then
    select m.id
      into v_next_member_id
    from public.team_members m
    where m.team_id = old.team_id
    order by
      case m.peran when 'ketua' then 0 else 1 end,
      m.created_at asc,
      m.id asc
    limit 1;

    if v_next_member_id is not null then
      perform set_config('pacer.migrating_roles', '1', true);
      update public.team_members
         set peran = 'coach'
       where id = v_next_member_id;
      perform set_config('pacer.migrating_roles', '0', true);
    end if;
  end if;

  return old;
end;
$$;

drop trigger if exists team_members_after_delete_cleanup on public.team_members;
create trigger team_members_after_delete_cleanup
  after delete on public.team_members
  for each row execute function public.team_members_after_delete_cleanup();

-- ---------------------------------------------------------------------------
-- 4. Prevent demoted creator from deleting an active graduated team
-- ---------------------------------------------------------------------------
drop policy if exists teams_delete on public.teams;
create policy teams_delete on public.teams
  for delete
  using (
    public.is_admin()
    or public.is_team_coach(id)
    or (
      dibuat_oleh = (select auth.uid())
      and expires_at is not null
    )
  );

commit;
