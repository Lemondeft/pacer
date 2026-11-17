# AGENTS.md — Pacer Engineering Reference

Pacer is an offline-first multi-sport tracker built with Flutter (`lib/`) and Supabase Postgres (`supabase/`).

## Build & Verify Commands
- Static analysis: `flutter analyze` (use `--no-pub` when offline)
- Full test suite: `flutter test` (use `--no-pub` when offline)
- Release builds: `flutter build apk --release` and `flutter build linux --release`

## Core Architecture & Domain Constants
- **Supported Sports (`aktivitasJenis` in `lib/src/aktivitas/activity_model.dart`)**: `'lari'` (Outdoor Run), `'joging'` (Jogging), `'bersepeda'` (Cycling), `'berjalan'` (Walk).
- **Offline-First SSOT (`lib/src/local/`)**: All writes commit locally to `LocalStore` (`SqliteLocalStore` on IO, `MemoryLocalStore` fallback/tests) and queue mutations into `sync_outbox` drained by `SyncEngine` (`lib/src/sync/sync_engine.dart`).
- **UI & Liquid Glass Design**: Follow [`GLASSMORPHISM_SPEC.md`](GLASSMORPHISM_SPEC.md) — **one surface, one blur**; Trackside `PacerSurface` panels are opaque/tinted without redundant `BackdropFilter` passes; the navbar (`BottomNavPill` + `PacerScrubberDroplet`) keeps a single fixed icon row with `assets/shaders/pacer_selection_mask.frag`.
- **Supabase Changes**: Add idempotent forward SQL migrations in `supabase/migrations/` and keep RLS deny-by-default with explicit `security invoker` / permission grants.

## Multi-Activity Classification & Anti-Cheat Pipeline
Tracking (`RunRecorder` in `lib/src/tracking/recorder.dart`) enforces a five-layer pipeline across all four sports plus motor-vehicle cheat detection:
1. **L1 (`GpsSanitizer`)**: Accuracy `<= 20 m`, monotonic timestamps, `4.0 m/s²` multipath accel filter, `110 km/h` teleport ceiling, 30 s sliding median/p85/grade window.
2. **L2 (`MotionSensorProvider`)**: Platform channel `com.example.pacer/motion` streaming OS activity (`0..100`) and step deltas; gracefully degrades to `NoopMotionSensorProvider` on Linux/Web/tests.
3. **L3 (Targeted `25 Hz` Accel Bursts)**: 5 s (`125`-sample) bursts via `sensors_plus` once per 30 s only inside sport ambiguity bands or low sensor confidence.
4. **L4 (`evaluateActivityWindow`, `ActivityMismatchMonitor`)**: Bidirectional sport scoring with biomechanics guardrails and `2–4` window hysteresis (`60–120 s`) driving non-blocking banners in `RunTrackerScreen`.
5. **L5 (`supabase/functions/validate-activity/index.ts`)**: Post-upload 120 s grade-adjusted audit + optional OSRM/Valhalla map-matching excluding flagged sessions from `recompute_user_challenge_progress` and offering one-tap Reclassify/Delete in `RunFinishScreen` & `HistoryScreen`.

See [`docs/activity_classification_spec.md`](docs/activity_classification_spec.md) for exact thresholds, math, and mandatory verification scenarios.
