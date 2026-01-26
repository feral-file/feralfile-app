# Feral File mobile app

The Feral File mobile app is the controller for the **FF1 art computer**. It helps you discover **channels, playlists, and works**, then **play** them on FF1 using the **DP-1 open display protocol**.

This repo is the Flutter codebase for the mobile app.

- FF1: https://feralfile.com/install
- DP-1: https://github.com/display-protocol/dp1

---

## What the app does (today)

### Pair and control FF1
- Pair your phone to an FF1 on your network (QR-based setup flow).
- Choose where art plays (device selection) and control playback.

### Browse and play DP-1 playlists
- Browse **Channels**, **Playlists**, and **Works**.
- Play a playlist or work on FF1 (“Play on FF1 now”).

### Keep a personal collection
- Save channels/playlists/works to **My Collection**.
- Optional: add wallet addresses to index on-chain collections into My Collection.


---

## Current focus

We prioritize **Gold Path reliability**: setup → pairing → playback should feel boring and repeatable. If you’re working on a new feature, first check whether it risks pairing/playback regressions.

---

## Repo layout (high level)

- `lib/` — Flutter app code (UI + state + API clients)
- `scripts/` — local helper scripts (coverage, fonts)
- `assets/` — app assets (git submodule)
- `auto-test/` — automation tests (optional git submodule)
- `.env*` — environment config (local dev)

---

## Getting started (dev)

### Prereqs
1. Install Flutter: https://flutter.dev
2. Install Android SDK + Xcode (run `flutter doctor` and resolve all warnings)

### Setup
1. Clone the repo
2. Initialize submodules:

   ```bash
   git submodule update --init --recursive
   ```

   If you want to skip an optional submodule:

   ```bash
   git -c submodule.auto-test.update=none submodule update --init --recursive
   ```

3. Create your local env files:

   ```bash
   cp .env.example .env
   cp .env.secret.example .env.secret
   ```

   ` .env.secret` contains credentials. For local dev you can either:
   - provide your own credentials, or
   - request access to a team dev environment.

### Run
```bash
flutter run --flavor inhouse
```

---

## Releases

- iPhone: https://apps.apple.com/us/app/feral-file-controller/id6755812386
- Android: https://play.google.com/store/apps/details?id=com.feralfile.app


---

## Contributing

We accept PRs for fixes and documentation improvements.

- For substantial changes, open an issue first so we can agree on scope and testing.
- For small changes (typos, lint fixes, small bug fixes), feel free to open a PR directly.


---

## License

```text
SPDX-License-Identifier: BSD-2-Clause-Patent
Copyright © 2026 Feral File Inc. All rights reserved.

UI/UX: CC BY-NC 4.0
Source: BSD-2-Clause Plus Patent (see LICENSE)
```
