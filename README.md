# Pacer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

An open-source sports tracking application built with **Flutter** and **Supabase Postgres**. Features GPS run tracking, team management, PE coach grading, leaderboards, and real-time chat.

## Features

- **GPS Tracking:** Foreground location recorder, OSM maps, offline mode, and desktop simulation.
- **Teams & Coaching:** Invite codes, coach grading dashboard, team management, and real-time chat.
- **Gamification:** Global/team leaderboards and community challenges.
- **Security:** Strict Supabase Row Level Security (RLS) and role escalation guards.
- **Customization:** Light/Dark themes and English/Indonesian support.

## Tech Stack

- **Frontend:** Flutter (Mobile, Desktop, Web)
- **Backend:** Supabase (Postgres, Auth, Realtime)
- **Mapping:** OpenStreetMap (OSM)

## Quick Start

### 1. Setup Environment
```bash
git clone https://github.com/Lemondeft/pacer.git
cd pacer
flutter pub get
cp .env.example .env
```

## License

This project is licensed under the terms of the [GNU General Public License v3.0](LICENSE).

