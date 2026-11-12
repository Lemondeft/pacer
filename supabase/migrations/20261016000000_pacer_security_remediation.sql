-- Security advisor remediation:
-- 1. Create explicit deny policy on public.team_secrets to satisfy rls_enabled_no_policy
-- 2. Revoke execute privileges on trigger functions from public/anon/authenticated
-- 3. Switch internal RLS helper functions from SECURITY DEFINER to SECURITY INVOKER
-- 4. Restrict execution grants on public functions to prevent unauthenticated access

-- 1. team_secrets isolation policy
DROP POLICY IF EXISTS team_secrets_isolation ON public.team_secrets;
CREATE POLICY team_secrets_isolation ON public.team_secrets
  FOR ALL TO public
  USING (false);

-- 2. Trigger functions: revoke execute from public, anon, and authenticated
-- Triggers are executed by Postgres engine under owner context and do not require client EXECUTE grants.
REVOKE ALL ON FUNCTION public.rls_auto_enable() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.team_members_peran_guard_trigger() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.teams_after_insert() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.users_peran_immutability_trigger() FROM PUBLIC, anon, authenticated;

-- 3. Internal helper functions: switch to SECURITY INVOKER and revoke from unauthenticated roles
ALTER FUNCTION public.is_coach_or_admin() SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.is_coach_or_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_coach_or_admin() TO authenticated;

ALTER FUNCTION public.is_team_member(uuid) SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.is_team_member(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_team_member(uuid) TO authenticated;

ALTER FUNCTION public.is_team_member_strict(p_team_id uuid) SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.is_team_member_strict(p_team_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_team_member_strict(p_team_id uuid) TO authenticated;

-- can_manage_team is only called internally by get_team_invite_code / regenerate_team_invite_code
ALTER FUNCTION public.can_manage_team(p_team_id uuid) SECURITY INVOKER;
REVOKE ALL ON FUNCTION public.can_manage_team(p_team_id uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.can_manage_team(p_team_id uuid) TO postgres, service_role;

-- 4. Client RPC functions: revoke anon execution, explicitly grant to authenticated
REVOKE ALL ON FUNCTION public.get_team_invite_code(p_team_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_team_invite_code(p_team_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.regenerate_team_invite_code(p_team_id uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.regenerate_team_invite_code(p_team_id uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.join_team(p_team_id uuid, p_code text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_team(p_team_id uuid, p_code text) TO authenticated;

REVOKE ALL ON FUNCTION public.join_team_by_code(p_code text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_team_by_code(p_code text) TO authenticated;

REVOKE ALL ON FUNCTION public.leaderboard_scope_user_ids(p_scope text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leaderboard_scope_user_ids(p_scope text) TO authenticated;
