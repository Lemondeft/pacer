-- Super Admin ('admin') Governance, Coach Invite Codes, Role Promotion RPCs,
-- Team-Scoped Privacy Hardening, Anti-Cheat Review Queue, and Audit Logging.

-- ---------------------------------------------------------------------------
-- 1. Harden users.peran immutability: only 'admin' (or service_role / initial
--    bootstrap before any admin exists) may modify public.users.peran.
-- ---------------------------------------------------------------------------
create or replace function public.users_peran_immutability_trigger()
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

  if current_setting('request.jwt.claim.role', true) = 'service_role' then
    return new;
  end if;

  -- Direct Postgres DBA / Supabase Dashboard SQL Editor sessions connect as
  -- postgres or supabase_admin without a PostgREST JWT role claim.
  if session_user in ('postgres', 'supabase_admin')
     and coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), '') = ''
     and coalesce(nullif(current_setting('role', true), ''), 'none') in ('none', 'postgres', 'supabase_admin') then
    return new;
  end if;

  if not exists (
    select 1 from public.users u where u.peran = 'admin'
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.users u
    where u.id = auth.uid() and u.peran = 'admin'
  ) then
    return new;
  end if;

  raise exception 'self-promotion denied: peran may only be changed by admin (RLS 42501)'
    using errcode = '42501';
end;
$$;

drop trigger if exists users_peran_immutability_trigger on public.users;
create trigger users_peran_immutability_trigger
  before update of peran on public.users
  for each row
  execute function public.users_peran_immutability_trigger();

-- ---------------------------------------------------------------------------
-- 1b. Scope coach read policies strictly to shared teams & keep GPS routes
--     strictly owner-only (prevents global stalking of arbitrary users' routes).
-- ---------------------------------------------------------------------------
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
      or (
        exists (
          select 1 from public.users u
          where u.id = auth.uid() and u.peran = 'coach'
        )
        and exists (
          select 1
          from public.team_members student_m
          join public.teams t on t.id = student_m.team_id
          where student_m.user_id = p_target_user_id
            and (
              t.dibuat_oleh = auth.uid()
              or exists (
                select 1 from public.team_members coach_m
                where coach_m.team_id = t.id and coach_m.user_id = auth.uid()
              )
            )
        )
      )
    );
$$;

revoke all on function public.can_coach_read_user(uuid) from public, anon;
grant execute on function public.can_coach_read_user(uuid) to authenticated;

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

-- Raw GPS coordinates (rute_points) stay strictly owner-only.
drop policy if exists rute_coach_select on public.rute_points;

-- ---------------------------------------------------------------------------
-- 2. Immutable Admin Audit Log & Coach Invite Codes tables
-- ---------------------------------------------------------------------------
create table if not exists public.admin_audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.users (id) on delete cascade,
  action text not null,
  target_type text not null,
  target_id text,
  reason text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_logs_created_idx
  on public.admin_audit_logs (created_at desc);

alter table public.admin_audit_logs enable row level security;

drop policy if exists admin_audit_logs_select_admin on public.admin_audit_logs;
create policy admin_audit_logs_select_admin
  on public.admin_audit_logs
  for select
  to authenticated
  using (public.is_admin());

create table if not exists public.coach_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  created_by uuid not null references public.users (id) on delete cascade,
  note text,
  max_uses integer not null default 1 check (max_uses > 0),
  uses_count integer not null default 0 check (uses_count >= 0),
  expires_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists coach_invites_created_idx
  on public.coach_invites (created_at desc);

alter table public.coach_invites enable row level security;

drop policy if exists coach_invites_select_admin on public.coach_invites;
create policy coach_invites_select_admin
  on public.coach_invites
  for select
  to authenticated
  using (public.is_admin());

-- Allow 'account_notice' in user_notifications without dropping prior types.
do $$
declare
  v_constraint_name text;
begin
  select c.conname
    into v_constraint_name
  from pg_constraint c
  join pg_class t on t.oid = c.conrelid
  join pg_namespace n on n.oid = t.relnamespace
  where n.nspname = 'public'
    and t.relname = 'user_notifications'
    and c.contype = 'c'
    and pg_get_constraintdef(c.oid) ilike '%type%';

  if v_constraint_name is not null then
    execute format(
      'alter table public.user_notifications drop constraint %I',
      v_constraint_name
    );
  end if;
end $$;

alter table public.user_notifications
  add constraint user_notifications_type_check check (
    type in (
      'team_challenge_assigned',
      'challenge_completed',
      'team_role_changed',
      'sport_reclassification_suggested',
      'vehicle_activity_flagged',
      'account_notice'
    )
  );

-- ---------------------------------------------------------------------------
-- 3. Super Admin KPI Overview RPC
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_overview_stats()
returns table (
  total_users bigint,
  user_count bigint,
  coach_count bigint,
  admin_count bigint,
  total_teams bigint,
  total_activities bigint,
  flagged_activities bigint,
  verified_activities bigint,
  total_km numeric
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  return query
    select
      (select count(*)::bigint from public.users),
      (select count(*)::bigint from public.users where peran = 'user'),
      (select count(*)::bigint from public.users where peran = 'coach'),
      (select count(*)::bigint from public.users where peran = 'admin'),
      (select count(*)::bigint from public.teams),
      (select count(*)::bigint from public.aktivitas where selesai_at is not null),
      (
        select count(*)::bigint
        from public.aktivitas
        where validation_status in ('flagged_vehicle', 'flagged_ride', 'flagged_mismatch')
      ),
      (
        select count(*)::bigint
        from public.aktivitas
        where validation_status in ('verified', 'reclassified')
      ),
      (
        select coalesce(sum(jarak_m), 0) / 1000.0
        from public.aktivitas
        where selesai_at is not null
          and coalesce(validation_status, 'unverified') <> 'flagged_vehicle'
      );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. User Directory & Role Promotion RPCs
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_users(
  p_query text default null,
  p_role text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns table (
  id uuid,
  nama text,
  peran text,
  region text,
  created_at timestamptz,
  total_runs bigint,
  total_km numeric
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_q text := lower(nullif(trim(coalesce(p_query, '')), ''));
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  if p_role is not null and p_role <> '' and p_role not in ('user', 'coach', 'admin') then
    raise exception 'invalid role filter: %', p_role using errcode = '22023';
  end if;

  return query
    select
      u.id,
      coalesce(nullif(trim(u.nama), ''), left(u.id::text, 8) || '…') as nama,
      u.peran,
      u.region,
      u.created_at,
      coalesce(count(a.id), 0)::bigint as total_runs,
      coalesce(sum(a.jarak_m), 0) / 1000.0 as total_km
    from public.users u
    left join public.aktivitas a
      on a.user_id = u.id
     and a.selesai_at is not null
     and coalesce(a.validation_status, 'unverified') <> 'flagged_vehicle'
    where (p_role is null or p_role = '' or u.peran = p_role)
      and (
        v_q is null
        or strpos(lower(coalesce(u.nama, '')), v_q) > 0
        or strpos(lower(u.id::text), v_q) > 0
        or strpos(lower(coalesce(u.region, '')), v_q) > 0
      )
    group by u.id, u.nama, u.peran, u.region, u.created_at
    order by
      case u.peran when 'admin' then 0 when 'coach' then 1 else 2 end,
      u.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 200))
    offset greatest(0, coalesce(p_offset, 0));
end;
$$;

create or replace function public.admin_set_user_role(
  p_target_user_id uuid,
  p_new_role text,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_old_role text;
  v_admin_count bigint;
begin
  if v_uid is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  if p_new_role not in ('user', 'coach', 'admin') then
    raise exception 'invalid peran: %', p_new_role using errcode = '22023';
  end if;

  select peran into v_old_role
  from public.users
  where id = p_target_user_id
  for update;

  if not found then
    raise exception 'User not found' using errcode = 'P0002';
  end if;

  if v_old_role = p_new_role then
    return;
  end if;

  if p_target_user_id = v_uid and p_new_role <> 'admin' then
    raise exception 'Self-demotion is blocked' using errcode = '42501';
  end if;

  if v_old_role = 'admin' and p_new_role <> 'admin' then
    select count(*)::bigint into v_admin_count
    from public.users
    where peran = 'admin';
    if v_admin_count <= 1 then
      raise exception 'Cannot demote the last active admin' using errcode = '42501';
    end if;
  end if;

  update public.users
     set peran = p_new_role
   where id = p_target_user_id;

  insert into public.admin_audit_logs (
    actor_id,
    action,
    target_type,
    target_id,
    reason,
    metadata
  ) values (
    v_uid,
    'set_user_role',
    'user',
    p_target_user_id::text,
    nullif(trim(coalesce(p_reason, '')), ''),
    jsonb_build_object('old_role', v_old_role, 'new_role', p_new_role)
  );

  insert into public.user_notifications (
    user_id,
    type,
    title,
    body
  ) values (
    p_target_user_id,
    'account_notice',
    'Peran Akun Diperbarui',
    'Peran akun Anda sekarang: ' || upper(p_new_role) || '.'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Coach Invite Codes RPCs (Generate, List, Revoke, Claim)
-- ---------------------------------------------------------------------------
create or replace function public.admin_create_coach_invite(
  p_note text default null,
  p_max_uses integer default 1,
  p_expires_days integer default 14
)
returns public.coach_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_expires timestamptz;
  v_row public.coach_invites;
begin
  if v_uid is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  if coalesce(p_max_uses, 1) < 1 then
    raise exception 'max_uses must be >= 1' using errcode = '22023';
  end if;

  v_code := 'COACH-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  if p_expires_days is not null and p_expires_days > 0 then
    v_expires := now() + make_interval(days => p_expires_days);
  end if;

  insert into public.coach_invites (
    code,
    created_by,
    note,
    max_uses,
    expires_at
  ) values (
    v_code,
    v_uid,
    nullif(trim(coalesce(p_note, '')), ''),
    coalesce(p_max_uses, 1),
    v_expires
  )
  returning * into v_row;

  insert into public.admin_audit_logs (
    actor_id,
    action,
    target_type,
    target_id,
    reason,
    metadata
  ) values (
    v_uid,
    'create_coach_invite',
    'coach_invite',
    v_row.id::text,
    v_row.note,
    jsonb_build_object('code', v_row.code, 'max_uses', v_row.max_uses)
  );

  return v_row;
end;
$$;

create or replace function public.admin_list_coach_invites()
returns setof public.coach_invites
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  return query
    select * from public.coach_invites
    order by created_at desc
    limit 50;
end;
$$;

create or replace function public.admin_revoke_coach_invite(p_invite_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  update public.coach_invites
     set revoked_at = coalesce(revoked_at, now())
   where id = p_invite_id;

  insert into public.admin_audit_logs (
    actor_id,
    action,
    target_type,
    target_id
  ) values (
    v_uid,
    'revoke_coach_invite',
    'coach_invite',
    p_invite_id::text
  );
end;
$$;

create or replace function public.claim_coach_invite(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_code text := upper(trim(coalesce(p_code, '')));
  v_inv public.coach_invites;
  v_cur_role text;
begin
  if v_uid is null then
    raise exception 'Authentication required (RLS 42501)' using errcode = '42501';
  end if;

  if v_code = '' then
    raise exception 'Invite code is required' using errcode = '22023';
  end if;

  select peran into v_cur_role from public.users where id = v_uid;
  if v_cur_role = 'admin' then
    return 'admin';
  end if;
  if v_cur_role = 'coach' then
    return 'coach';
  end if;

  select * into v_inv
  from public.coach_invites
  where upper(code) = v_code
  for update;

  if not found then
    raise exception 'Invalid coach invite code' using errcode = 'P0002';
  end if;

  if v_inv.revoked_at is not null then
    raise exception 'Coach invite code was revoked' using errcode = '42501';
  end if;

  if v_inv.expires_at is not null and v_inv.expires_at <= now() then
    raise exception 'Coach invite code expired' using errcode = '42501';
  end if;

  if v_inv.uses_count >= v_inv.max_uses then
    raise exception 'Coach invite code already used' using errcode = '42501';
  end if;

  update public.users
     set peran = 'coach'
   where id = v_uid;

  update public.coach_invites
     set uses_count = uses_count + 1
   where id = v_inv.id;

  insert into public.admin_audit_logs (
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  ) values (
    v_uid,
    'claim_coach_invite',
    'user',
    v_uid::text,
    jsonb_build_object('invite_id', v_inv.id, 'code', v_inv.code)
  );

  return 'coach';
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Anti-Cheat Flagged Activity Moderation & Audit Log Reader
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_flagged_activities(
  p_limit integer default 50
)
returns table (
  id uuid,
  user_id uuid,
  user_nama text,
  jenis text,
  mulai_at timestamptz,
  durasi_s integer,
  jarak_m numeric,
  cadence_spm integer,
  suggested_sport text,
  validation_status text,
  validation_score numeric,
  validation_reasons jsonb
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  return query
    select
      a.id,
      a.user_id,
      coalesce(nullif(trim(u.nama), ''), left(a.user_id::text, 8) || '…') as user_nama,
      a.jenis,
      a.mulai_at,
      a.durasi_s,
      a.jarak_m,
      a.cadence_spm,
      a.suggested_sport,
      a.validation_status,
      a.validation_score,
      coalesce(a.validation_reasons, '[]'::jsonb) as validation_reasons
    from public.aktivitas a
    join public.users u on u.id = a.user_id
    where a.validation_status in ('flagged_vehicle', 'flagged_ride', 'flagged_mismatch')
    order by coalesce(a.selesai_at, a.created_at) desc
    limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

create or replace function public.admin_review_activity(
  p_aktivitas_id uuid,
  p_action text,
  p_new_jenis text default null,
  p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_old_jenis text;
  v_old_status text;
  v_next_jenis text;
  v_next_status text;
begin
  if v_uid is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  if p_action not in ('verify', 'reclassify', 'exclude') then
    raise exception 'invalid review action: %', p_action using errcode = '22023';
  end if;

  select user_id, jenis, validation_status
    into v_owner, v_old_jenis, v_old_status
  from public.aktivitas
  where id = p_aktivitas_id
  for update;

  if not found then
    raise exception 'Activity not found' using errcode = 'P0002';
  end if;

  if p_action = 'verify' then
    v_next_jenis := v_old_jenis;
    v_next_status := 'verified';
  elsif p_action = 'reclassify' then
    if p_new_jenis is null or p_new_jenis not in ('lari', 'joging', 'bersepeda', 'berjalan') then
      raise exception 'valid p_new_jenis required for reclassify' using errcode = '22023';
    end if;
    v_next_jenis := p_new_jenis;
    v_next_status := 'reclassified';
  else
    v_next_jenis := v_old_jenis;
    v_next_status := 'flagged_vehicle';
  end if;

  update public.aktivitas
     set jenis = v_next_jenis,
         validation_status = v_next_status,
         suggested_sport = null,
         validated_at = now()
   where id = p_aktivitas_id;

  perform public.recompute_user_challenge_progress(v_owner);

  insert into public.admin_audit_logs (
    actor_id,
    action,
    target_type,
    target_id,
    reason,
    metadata
  ) values (
    v_uid,
    'review_activity_' || p_action,
    'aktivitas',
    p_aktivitas_id::text,
    nullif(trim(coalesce(p_reason, '')), ''),
    jsonb_build_object(
      'old_status', v_old_status,
      'new_status', v_next_status,
      'old_jenis', v_old_jenis,
      'new_jenis', v_next_jenis
    )
  );
end;
$$;

create or replace function public.admin_list_audit_logs(
  p_limit integer default 50
)
returns table (
  id uuid,
  actor_id uuid,
  actor_nama text,
  action text,
  target_type text,
  target_id text,
  reason text,
  metadata jsonb,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if auth.uid() is null or not public.is_admin() then
    raise exception 'admin privilege required (RLS 42501)' using errcode = '42501';
  end if;

  return query
    select
      l.id,
      l.actor_id,
      coalesce(nullif(trim(u.nama), ''), left(l.actor_id::text, 8) || '…') as actor_nama,
      l.action,
      l.target_type,
      l.target_id,
      l.reason,
      l.metadata,
      l.created_at
    from public.admin_audit_logs l
    left join public.users u on u.id = l.actor_id
    order by l.created_at desc
    limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

revoke all on function public.admin_get_overview_stats() from public, anon;
grant execute on function public.admin_get_overview_stats() to authenticated;

revoke all on function public.admin_list_users(text, text, integer, integer) from public, anon;
grant execute on function public.admin_list_users(text, text, integer, integer) to authenticated;

revoke all on function public.admin_set_user_role(uuid, text, text) from public, anon;
grant execute on function public.admin_set_user_role(uuid, text, text) to authenticated;

revoke all on function public.admin_create_coach_invite(text, integer, integer) from public, anon;
grant execute on function public.admin_create_coach_invite(text, integer, integer) to authenticated;

revoke all on function public.admin_list_coach_invites() from public, anon;
grant execute on function public.admin_list_coach_invites() to authenticated;

revoke all on function public.admin_revoke_coach_invite(uuid) from public, anon;
grant execute on function public.admin_revoke_coach_invite(uuid) to authenticated;

revoke all on function public.claim_coach_invite(text) from public, anon;
grant execute on function public.claim_coach_invite(text) to authenticated;

revoke all on function public.admin_list_flagged_activities(integer) from public, anon;
grant execute on function public.admin_list_flagged_activities(integer) to authenticated;

revoke all on function public.admin_review_activity(uuid, text, text, text) from public, anon;
grant execute on function public.admin_review_activity(uuid, text, text, text) to authenticated;

revoke all on function public.admin_list_audit_logs(integer) from public, anon;
grant execute on function public.admin_list_audit_logs(integer) to authenticated;
