# pacer

Flutter sports-tracking app backed by Supabase Postgres. Built faithful to `manual.drawio.xml` (DFD processes 1.0–5.0).

## Setup

```sh
flutter pub get
cp .env.example .env   # fill SUPABASE_URL + SUPABASE_ANON_KEY, never commit .env
```

Apply migrations in order via the Supabase dashboard SQL editor:

1. `supabase/migrations/20261009120000_pacer_initial.sql` — 11 tables + RLS
2. `supabase/migrations/20261009121500_pacer_grants.sql` — API role grants
3. `supabase/migrations/20261009123000_pacer_hardening.sql` — `peran` escalation guards

```sh
flutter run -d linux   # or chrome
```

## Checks

```sh
flutter analyze
flutter test            # 54 green
```

## Structure

- `lib/main.dart` — entry, Supabase init with demo-mode fallback
- `lib/supabase.dart` — `supa` client accessor
- `lib/src/auth|aktivitas|challenge|leaderboard|teams` — models + repositories, no widgets
- `lib/src/ui` — screens (Figma-derived, demo data until wired)
- `supabase/migrations` — schema, grants, hardening
