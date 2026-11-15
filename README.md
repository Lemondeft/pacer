<div align="center">
  <img src="web/icons/Icon-192.png" alt="Pacer Logo" width="96" height="96" />

  # Pacer

  **Modern, offline-first sports & running tracker built with Flutter and Supabase Postgres.**

  [![Release](https://img.shields.io/badge/version-v0.2.4-00CDFA.svg)](https://github.com/Lemondeft/pacer/releases)
  [![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
  [![Flutter](https://img.shields.io/badge/Flutter-Mobile%20%7C%20Desktop%20%7C%20Web-02569B?logo=flutter)](https://flutter.dev)
  [![Supabase](https://img.shields.io/badge/Supabase-Postgres%20%2B%20RLS-3ECF8E?logo=supabase)](https://supabase.com)
</div>

---

## Download

Pre-built release binaries (with the new Pacer speed-cut brand icon) are available on [**GitHub Releases**](https://github.com/Lemondeft/pacer/releases).

---

## Key Features

- **GPS Run & Multi-Sport Tracking (`Running`, `Jogging`, `Cycling`, `Walking`)**
  - Real-time pace, distance, duration, and calorie tracking with crash-safe local draft recovery.
  - Distraction-free **OpenFreeMap** vector basemaps (`Positron` in Light mode, `Dark` in Dark mode) with a one-tap street-label toggle and full-bleed finish route summary.
- **Offline-First SQLite Persistence & Outbox Sync Engine**
  - Local Single Source of Truth (`LocalStore` SQLite / FFI) with stale-while-revalidate caching and automatic background outbox synchronization when connectivity returns.
- **Rich Athletic Dashboard & Liquid Glass UI**
  - Quick-start sport grid, 7-day volume & pace overview, active/open challenges preview, personal leaderboard standing snapshot, recent workout history, and team club cards.
  - Impeller-accelerated **Liquid Glass** floating navigation pill (`liquid_glass_easy`) with optical edge-border refraction and chromatic dispersion.
- **Teams, Solo & Team Challenges, and Coach Grading**
  - Public and invite-code private running clubs with real-time team chat.
  - Solo and team-scoped challenges with automatic workout contribution and active challenge slot management.
  - Role-aware management (`Admin` / `Coach`, team `Captain` / `Ketua`, and `Member` / `Anggota`) with PE coach grading boards and member notifications.
- **Themes & Localization**
  - **Dark**, **Light**, and **System** modes.
  - **Classic Linux Desktop Themes:** Switchable palettes for **Pacer Argon** (default), **KDE Breeze**, **Mint-Y Cinnamon**, **GNOME Adwaita**, **Ubuntu Yaru**, and **Arch Nord** across both Dark and Light modes.
  - Full **Indonesian (`ID`)** and **English (`EN`)** localization.

---

## Tech Stack

- **Frontend:** Flutter (`Android`, `iOS`, `Linux`, `Windows`, `macOS`, `Web`)
- **Backend:** Supabase (`PostgreSQL`, `Auth`, `Realtime`, strict `Row Level Security`)
- **Local Storage:** `sqflite` & `sqflite_common_ffi` + `shared_preferences`
- **Maps:** `flutter_map` + `flutter_map_vector_tiles` (OpenFreeMap / OpenStreetMap)
- **Shaders & UI:** `liquid_glass_easy` (Impeller optical lens shaders) + `google_fonts`

---

## Quick Start

### 1. Clone & Configure Environment

```bash
git clone https://github.com/Lemondeft/pacer.git
cd pacer
flutter pub get
cp .env.example .env
```

Fill in `.env` with your Supabase project credentials (`SUPABASE_URL` and `SUPABASE_ANON_KEY`), or use the in-app **Demo Account** on the login screen to explore all features offline.

### 2. Run in Development

```bash
# Run on connected device or desktop
flutter run

# Static analysis & unit/widget test suite
flutter analyze
flutter test
```

### 3. Build Release Artifacts

```bash
# Android release APK (output: build/app/outputs/flutter-apk/app-release.apk)
flutter build apk --release

# Linux desktop release bundle (output: build/linux/x64/release/bundle/)
flutter build linux --release
```

---

## License

This project is licensed under the terms of the [GNU General Public License v3.0](LICENSE).
