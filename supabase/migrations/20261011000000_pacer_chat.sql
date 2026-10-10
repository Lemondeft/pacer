-- Team chat (IN DEVELOPMENT — beyond the class manual, which specifies no
-- chat entity, flow, or store). One channel per team; RLS scopes reads to
-- team members (+ coach/admin) and writes to the caller's own rows.
--
-- Realtime: the last statement publishes the table for postgres_changes.
-- If the dashboard project lacks the publication, enable Realtime for
-- public.chat_messages in Dashboard → Database → Replication instead.

create table public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.teams (id) on delete cascade,
  user_id uuid not null references public.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index chat_messages_team_idx on public.chat_messages (team_id, created_at desc);

alter table public.chat_messages enable row level security;

-- Helper: team membership (or coach/admin) for the RLS policies below.
create or replace function public.is_team_member(uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.team_members m
    where m.team_id = $1
      and (m.user_id = auth.uid() or public.is_coach_or_admin())
  );
$$;

-- Members (+ coach/admin) read their team's channel.
create policy chat_select on public.chat_messages
  for select to authenticated
  using (public.is_team_member(team_id));

-- Members send as themselves (coach/admin may also post into any channel).
create policy chat_insert on public.chat_messages
  for insert to authenticated
  with check (
    user_id = auth.uid() and public.is_team_member(team_id)
  );

comment on table public.chat_messages is
  'IN DEVELOPMENT: per-team channel. No update/delete policies yet — messages are append-only by design.';

alter publication supabase_realtime add table public.chat_messages;
