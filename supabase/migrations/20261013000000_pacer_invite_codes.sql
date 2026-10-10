-- Team invite codes: joining requires the team's code, verified server-side.
--
-- Design: teams.invite_code (8-char uppercase, unique, DB-generated) is shown
-- to coaches/members to share aloud. Joining goes through join_team(), a
-- SECURITY DEFINER rpc that checks the code and inserts the caller's own
-- membership row — so the code cannot be bypassed by direct API inserts:
-- members_insert is tightened to coach/admin only (join_team() itself runs
-- as owner and re-checks auth.uid() = user).
-- Client-side code checks alone would be cosmetic; this migration is what
-- makes the code meaningful. Existing memberships are unaffected.

alter table public.teams
  add column if not exists invite_code text not null
  default upper(substr(md5(gen_random_uuid()::text), 1, 8));

alter table public.teams
  add constraint teams_invite_code_check
  check (invite_code ~ '^[A-Z0-9]{8}$');

alter table public.teams
  add constraint teams_invite_code_unique unique (invite_code);

-- Tighten direct inserts to coach/admin; members join via join_team() below.
drop policy if exists members_insert on public.team_members;
create policy members_insert on public.team_members for insert to authenticated
  with check (public.is_coach_or_admin());

-- SECURITY DEFINER join gate: correct code + self-insert, nothing else.
create or replace function public.join_team(p_team_id uuid, p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'sign-in required (RLS 42501)';
  end if;
  if not exists (
    select 1 from public.teams t
    where t.id = p_team_id and t.invite_code = upper(trim(p_code))
  ) then
    raise exception 'wrong team code (RLS 42501)';
  end if;
  insert into public.team_members (team_id, user_id)
  values (p_team_id, auth.uid())
  on conflict (team_id, user_id) do nothing
  returning id into v_id;
  -- Idempotent: already-joined returns the existing row id.
  if v_id is null then
    select id into v_id from public.team_members
    where team_id = p_team_id and user_id = auth.uid();
  end if;
  return v_id;
end;
$$;

comment on function public.join_team(uuid, text) is
  'Code-gated team join: verifies invite_code, inserts caller membership idempotently. EXECUTE for authenticated (revoked for anon below).';

-- Join gate callable by sign-in users, not anon.
revoke execute on function public.join_team(uuid, text) from public;
grant execute on function public.join_team(uuid, text) to authenticated;
