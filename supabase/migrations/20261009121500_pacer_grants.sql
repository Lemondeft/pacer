-- Pacer RLS companion grants. RLS policies alone do not grant table access;
-- the Data API roles still need privileges. Backend uses the authenticated
-- role only (anon needs nothing: auth endpoints don't touch public tables).

grant usage on schema public to authenticated;

grant select, insert, update, delete on public.users to authenticated;
grant select, insert, update, delete on public.aktivitas to authenticated;
grant select, insert, update, delete on public.rute_points to authenticated;
grant select, insert, update, delete on public.statistik to authenticated;
grant select, insert, update, delete on public.streak to authenticated;
grant select, insert, update, delete on public.challenge to authenticated;
grant select, insert, update, delete on public.partisipasi_challenge to authenticated;
grant select, insert, update, delete on public.leaderboard to authenticated;
grant select, insert, update, delete on public.peringkat to authenticated;
grant select, insert, update, delete on public.teams to authenticated;
grant select, insert, update, delete on public.team_members to authenticated;

-- Future tables created via SQL editor/CLI get the same privileges automatically.
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
