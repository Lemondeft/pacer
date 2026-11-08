-- Team privacy, public/private teams, and leaderboard scopes.
--
-- 1. teams.is_private: private teams are hidden from the directory and join
--    only by secret code; public teams can be joined directly.
-- 2. invite_code moves OUT of the world-readable teams row into team_secrets
--    (RLS on, no policies, no grants => unreadable via the API). Only the
--    SECURITY DEFINER rpcs below can read it, and only for team managers:
--    admin, the creator, a 'ketua', or a coach who is a member of that team.
--    A coach of a different team gets nothing.
-- 3. users.region + leaderboard_scope_user_ids(): lets the leaderboard filter
--    to "my team(s)", "my region", or global without exposing rosters
--    (team_members is RLS-limited to own rows for regular users).

alter table public.teams
  add column if not exists is_private boolean not null default true;

alter table public.users
  add column if not exists region text;

-- ---------------------------------------------------------------------------
-- Secrets table (invite codes)
-- ---------------------------------------------------------------------------
create table if not exists public.team_secrets (
  team_id uuid primary key references public.teams (id) on delete cascade,
  invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{8}$')
);
alter table public.team_secrets enable row level security;
revoke all on public.team_secrets from anon, authenticated;

-- Carry existing codes over, then drop the readable column.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'teams'
      and column_name = 'invite_code'
  ) then
    insert into public.team_secrets (team_id, invite_code)
    select id, invite_code from public.teams
    on conflict (team_id) do nothing;
    alter table public.teams drop column invite_code;
  end if;
end $$;

-- Every new team gets a secret code; the creator becomes its ketua.
create or replace function public.teams_after_insert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.team_secrets (team_id, invite_code)
  values (new.id, upper(substr(md5(gen_random_uuid()::text), 1, 8)));
  if new.dibuat_oleh is not null then
    insert into public.team_members (team_id, user_id, peran)
    values (new.id, new.dibuat_oleh, 'ketua')
    on conflict (team_id, user_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists teams_after_insert on public.teams;
create trigger teams_after_insert
  after insert on public.teams
  for each row execute function public.teams_after_insert();

-- Teams created before this migration: make sure every team has a secret.
insert into public.team_secrets (team_id, invite_code)
select t.id, upper(substr(md5(gen_random_uuid()::text), 1, 8))
from public.teams t
where not exists (select 1 from public.team_secrets s where s.team_id = t.id);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.is_team_member_strict(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.team_members m
    where m.team_id = p_team_id and m.user_id = auth.uid()
  );
$$;

create or replace function public.can_manage_team(p_team_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    exists (select 1 from public.users u
            where u.id = auth.uid() and u.peran = 'admin')
    or exists (select 1 from public.teams t
               where t.id = p_team_id and t.dibuat_oleh = auth.uid())
    or exists (select 1
               from public.team_members m
               join public.users u on u.id = m.user_id
               where m.team_id = p_team_id
                 and m.user_id = auth.uid()
                 and (m.peran = 'ketua' or u.peran in ('coach', 'admin')));
$$;

-- ---------------------------------------------------------------------------
-- Visibility: private teams only for members / their creator / coach / admin.
-- (Coaches keep read access for the PE class board; they still cannot read
-- codes — those live in team_secrets.)
-- ---------------------------------------------------------------------------
drop policy if exists teams_select on public.teams;
create policy teams_select on public.teams for select to authenticated
  using (
    not is_private
    or public.is_coach_or_admin()
    or dibuat_oleh = auth.uid()
    or public.is_team_member_strict(id)
  );

-- ---------------------------------------------------------------------------
-- RPCs
-- ---------------------------------------------------------------------------
create or replace function public.get_team_invite_code(p_team_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
begin
  if auth.uid() is null or not public.can_manage_team(p_team_id) then
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
  if auth.uid() is null or not public.can_manage_team(p_team_id) then
    raise exception 'not allowed (RLS 42501)';
  end if;
  update public.team_secrets set invite_code = v_code where team_id = p_team_id;
  return v_code;
end;
$$;

-- Public teams join directly (code ignored); private teams need the code.
create or replace function public.join_team(p_team_id uuid, p_code text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_private boolean;
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'sign-in required (RLS 42501)';
  end if;
  select is_private into v_private from public.teams where id = p_team_id;
  if v_private is null then
    raise exception 'team not found (RLS 42501)';
  end if;
  if v_private and not exists (
    select 1 from public.team_secrets s
    where s.team_id = p_team_id and s.invite_code = upper(trim(coalesce(p_code, '')))
  ) then
    raise exception 'wrong team code (RLS 42501)';
  end if;
  insert into public.team_members (team_id, user_id)
  values (p_team_id, auth.uid())
  on conflict (team_id, user_id) do nothing
  returning id into v_id;
  if v_id is null then
    select id into v_id from public.team_members
    where team_id = p_team_id and user_id = auth.uid();
  end if;
  return v_id;
end;
$$;

-- Join a (typically private) team knowing only its code; returns the team id.
create or replace function public.join_team_by_code(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_team uuid;
begin
  if auth.uid() is null then
    raise exception 'sign-in required (RLS 42501)';
  end if;
  select team_id into v_team from public.team_secrets
  where invite_code = upper(trim(coalesce(p_code, '')));
  if v_team is null then
    raise exception 'wrong team code (RLS 42501)';
  end if;
  insert into public.team_members (team_id, user_id)
  values (v_team, auth.uid())
  on conflict (team_id, user_id) do nothing;
  return v_team;
end;
$$;

-- Leaderboard scope: p_scope in ('team', 'region', 'global').
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
      join public.team_members m2 on m2.team_id = m1.team_id
      where m1.user_id = auth.uid();
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

-- Lock function execution to signed-in users.
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.get_team_invite_code(uuid)',
    'public.regenerate_team_invite_code(uuid)',
    'public.join_team(uuid, text)',
    'public.join_team_by_code(text)',
    'public.leaderboard_scope_user_ids(text)',
    'public.can_manage_team(uuid)',
    'public.is_team_member_strict(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
