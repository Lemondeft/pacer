-- Hardening migration for DFD process 5.0 PACER TEAM (process 5.0 security).
-- Ground truth: supabase/migrations/20261009120000_pacer_initial.sql
-- Adds: (1) users peran immutability trigger, (2) team_members peran CHECK + trigger.

-- ------------------------------------------------------------
-- Fix 1: Prevent self-promote on public.users peran UPDATE
-- ------------------------------------------------------------
-- BEFORE UPDATE trigger that raises an exception when NEW.peran
-- is DISTINCT FROM OLD.peran and the caller is NOT coach/admin.
-- A bootstrap exception allows the change when no coach/admin row
-- exists yet (first-admin setup).
create or replace function public.users_peran_immutability_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  -- Bootstrap exception: if no coach/admin row exists in the system yet,
  -- allow the peran change so the first admin can be created.
  if not exists (
    select 1 from public.users u where u.peran in ('coach', 'admin')
  ) then
    -- Allow the update to proceed so an initial admin can be set up.
    return new;
  end if;

  -- If the peran value is changing and the caller is not coach/admin,
  -- reject the update with a clear error.
  if new.peran <> old.peran then
    if not exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.peran in ('coach', 'admin')
    ) then
      raise exception 'self-promotion denied: peran may only be changed by coach or admin (RLS 42501)';
    end if;
  end if;

  return new;
  end;
$$;

-- Apply the trigger to public.users
drop trigger if exists users_peran_immutability_trigger on public.users;
create trigger users_peran_immutability_trigger
  before update of peran on public.users
  for each row
  execute function public.users_peran_immutability_trigger();

-- Comment explaining the bootstrap exception
comment on trigger users_peran_immutability_trigger on public.users is
  'Prevents regular users from self-promoting by changing peran.
   Bootstrap exception: allows the change when no coach/admin row exists
   yet (first-admin setup). All other peran changes require coach/admin.';

-- ------------------------------------------------------------
-- Fix 2: team_members.peran CHECK constraint + UPDATE guard
-- ------------------------------------------------------------
-- CHECK constraint limiting peran to the documented values:
--   'anggota' — regular member (default)
--   'ketua'   — team lead/coach role
alter table public.team_members
  add constraint team_members_peran_check
  check (peran in ('anggota', 'ketua'));

-- BEFORE UPDATE trigger that guards peran changes on team_members:
-- peran may only be changed by coach/admin. Regular users who join/leave
-- (insert/delete own rows) continue to work unchanged.
create or replace function public.team_members_peran_guard_trigger()
returns trigger
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  -- If peran is being changed, enforce coach/admin only.
  if new.peran <> old.peran then
    if not exists (
      select 1 from public.users u
      where u.id = auth.uid() and u.peran in ('coach', 'admin')
    ) then
      raise exception 'peran change denied: only coach or admin may update peran (RLS 42501)';
    end if;
  end if;

  return new;
  end;
$$;

-- Apply the trigger to public.team_members
drop trigger if exists team_members_peran_guard_trigger on public.team_members;
create trigger team_members_peran_guard_trigger
  before update of peran on public.team_members
  for each row
  execute function public.team_members_peran_guard_trigger();

-- Comment explaining the guard
comment on trigger team_members_peran_guard_trigger on public.team_members is
  'Guards peran changes on team_members: only coach/admin may change peran.
   Insert (join) and delete (leave) own rows continue to work with the
   default ''anggota'' and the CHECK constraint.';

-- ------------------------------------------------------------
-- Verification / smoke: confirm constraint values
-- ------------------------------------------------------------
-- The following comments document the intended peran values:
--   'anggota' — default, regular member (matches migration default)
--   'ketua'   — team lead role, allowed by the CHECK constraint
-- Do not add additional peran values without updating both the CHECK
-- constraint and the is_coach_or_admin() convention.