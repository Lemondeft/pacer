# pacer

Flutter sports-tracking app backed by Supabase Postgres. Built faithful to
`manual.drawio.xml` (DFD processes 1.0–5.0), plus documented extras below.

## Features

- Auth (email/password, session persistence, email-confirmation aware)
- GPS run tracking (foreground recorder, OSM tiles + offline minimal mode,
  desktop simulation mode, pause-safe duration, batch route upload)
- History, statistics, streaks (flowchart-correct transitions)
- Challenges (join/leave, progress), leaderboards, teams (invite-code join,
  coach CRUD), team chat (in development, beta badge), coach class board
- Light + dark themes (dark default, Account → Tema to switch)
- English/Indonesian toggle (persisted per user)

## Setup

```sh
flutter pub get
cp .env.example .env   # fill SUPABASE_URL + SUPABASE_ANON_KEY, never commit .env
```

Apply migrations in order via the Supabase dashboard SQL editor
(run each once; reruns error harmlessly on duplicate names):

1. `20261009120000_pacer_initial.sql` — 11 tables + RLS
2. `20261009121500_pacer_grants.sql` — API role grants
3. `20261009123000_pacer_hardening.sql` — `peran` escalation guards
4. `20261009230000_users_language.sql` — `users.language` preference
5. `20261010000000_pacer_coach_read.sql` — coach reads for grading
6. `20261011000000_pacer_chat.sql` — team chat (also enable Realtime for
   `chat_messages` under Database → Replication if its last line errors)
7. `20261012000000_pacer_function_grants.sql` — function EXECUTE lockdown
8. `20261013000000_pacer_invite_codes.sql` — code-gated team join

Optional demo data (after sign-ups; UUIDs from Authentication):
`supabase/seed_demo.sql` — replace `<BUDI_UUID>`/`<SITI_UUID>`, run once.

```sh
flutter run -d linux   # or chrome; Android via `flutter run`
```

GPS tracking needs a phone (or the tracker's Simulasi mode on desktop):
`ACCESS_FINE_LOCATION` (Android manifest) and
`NSLocationWhenInUseUsageDescription` (iOS plist) are configured.

## Security model

- Anon key only in the app; `service_role` never ships.
- RLS deny-by-default: owner-only workouts/stats/streaks, coach reads for
  grading, member-scoped teams/chat, coach-gated writes.
- `peran` cannot self-escalate (trigger + bootstrap exception for the first
  admin); team `peran` locked to anggota/ketua; functions revoked for anon.
- First coach: sign up, then as long as no coach exists —
  `update public.users set peran = 'coach' where id = '<uuid>'`.

## Checks

```sh
flutter analyze
flutter test            # 80 green
```

## Structure

- `lib/main.dart` — entry, Supabase init with demo-mode fallback
- `lib/supabase.dart` — `supa` client accessor
- `lib/src/auth|aktivitas|challenge|leaderboard|teams|chat` — models +
  repositories (no widgets); `lib/src/tracking` — recorder + route map
- `lib/src/ui` — screens, widgets, theme, strings, formatters, coach board
- `lib/src/ui/coach_board.dart` — PE grading table (coach/admin only)
- `supabase/migrations` — schema, grants, hardening, features
