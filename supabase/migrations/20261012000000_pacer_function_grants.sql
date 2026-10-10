-- Function-exposure hardening (advisor: callable SECURITY DEFINER functions).
--
-- What stays executable and why:
--   * is_coach_or_admin() / is_team_member(uuid): every coach-scoped RLS
--     policy calls these AS the querying user, so `authenticated` MUST keep
--     EXECUTE (revoking it silently breaks all coach reads). Only `anon` is
--     revoked: anonymous callers have no policies and no legitimate use.
--   * users_peran_immutability_trigger() / team_members_peran_guard_trigger():
--     trigger functions. Postgres checks EXECUTE only at CREATE TRIGGER time
--     (by the owner), never at fire time — revoking EXECUTE from everyone is
--     safe and only removes the direct-call (rpc) attack surface.
-- NOT touched: rls_auto_enable() is pre-existing project setup, not ours —
--   inspect its definition in the dashboard before changing its grants.
-- Durability: default privileges are tightened so FUTURE functions are not
--   publicly executable by default; grant EXECUTE explicitly per function
--   (as done above for the two helpers) in later migrations.

-- Helpers: EXECUTE for authenticated ONLY. (Revoking from anon alone would
-- be dead letters: the default PUBLIC grant still covers anon. So revoke
-- from PUBLIC, then grant back explicitly to authenticated.)
revoke execute on function public.is_coach_or_admin() from public;
revoke execute on function public.is_team_member(uuid) from public;
grant execute on function public.is_coach_or_admin() to authenticated;
grant execute on function public.is_team_member(uuid) to authenticated;

-- Trigger functions: nobody needs direct EXECUTE (fire-time needs none).
revoke execute on function public.users_peran_immutability_trigger() from public;
revoke execute on function public.team_members_peran_guard_trigger() from public;

-- Future functions in this schema default to non-public EXECUTE.
alter default privileges for role postgres in schema public
  revoke execute on functions from public;

comment on function public.is_coach_or_admin() is
  'RLS helper: EXECUTE for authenticated (policies depend on it), revoked for anon.';
comment on function public.is_team_member(uuid) is
  'RLS helper: EXECUTE for authenticated (chat policies depend on it), revoked for anon.';
