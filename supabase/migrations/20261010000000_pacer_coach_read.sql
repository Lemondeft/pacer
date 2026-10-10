-- Coach read access for PE grading (guru workflow).
--
-- Problem: aktivitas / rute_points / statistik / streak are owner-only, so a
-- coach cannot see a single student workout. challenge / leaderboard /
-- peringkat / teams / team_members already grant coach/admin full reads.
-- This migration adds coach/admin SELECT policies to the four remaining
-- tables. Students keep full privacy from each other (owner policies
-- untouched); writes stay exactly as before (this file adds SELECT only).
--
-- NOTE: SELECT policies use USING only. This Supabase/Postgres build rejects
-- WITH CHECK outside INSERT (see initial migration header).

-- aktivitas: coach/admin read all rows (owner policy untouched).
create policy aktivitas_coach_select on public.aktivitas
  for select to authenticated
  using (public.is_coach_or_admin());

-- rute_points: coach/admin read all rows (owner-via-parent policy untouched).
create policy rute_coach_select on public.rute_points
  for select to authenticated
  using (public.is_coach_or_admin());

-- statistik: coach/admin read all rows (owner policy untouched).
create policy statistik_coach_select on public.statistik
  for select to authenticated
  using (public.is_coach_or_admin());

-- streak: coach/admin read all rows (owner policy untouched).
create policy streak_coach_select on public.streak
  for select to authenticated
  using (public.is_coach_or_admin());

comment on policy aktivitas_coach_select on public.aktivitas is
  'PE grading: coaches read student workouts; students still see only their own rows.';
comment on policy rute_coach_select on public.rute_points is
  'PE grading: coaches read student GPS tracks; students still see only their own rows.';
comment on policy statistik_coach_select on public.statistik is
  'PE grading: coaches read student totals; students still see only their own rows.';
comment on policy streak_coach_select on public.streak is
  'PE grading: coaches read student streaks; students still see only their own rows.';
