---
description: Launch the Life Shuffle Flutter web app locally in Chrome for manual testing
---

# Run Life Shuffle locally

## Known issue: no hot reload on this machine

`flutter run -d chrome` fails on Windows with `Error: SDK root directory not found: /C:/...` — an unresolved upstream Flutter/Dart bug (see TROUBLESHOOTING_LOG.md, 2026-06-17 entry, matches [flutter/flutter#184233](https://github.com/flutter/flutter/issues/184233)). Confirmed unrelated to puro, symlinks, or Flutter version after extensive testing. Use the static build workflow below instead until upstream fixes it.

## How to launch (static build + serve)

```powershell
cd "c:\Coding\LifeShuffle\life-shuffle"
flutter build web --dart-define=FIREBASE_WEB_API_KEY=$env:FIREBASE_WEB_API_KEY
npx --yes serve build\web -p 8769
```

Then open **http://127.0.0.1:8769** in Chrome — any normal Chrome profile works, no special dev profile needed; you stay signed into your regular Google account. `serve` binds to `localhost:8769`, but navigating to `127.0.0.1:8769` still works and is required for the API key referrer allowlist (see below).

No hot reload: after any code change, re-run `flutter build web` (~60-90s) then refresh the browser tab (normal F5 is fine here since there's no Dart VM debug connection to drop).

## Why 127.0.0.1 and not localhost

The Firebase/Google Cloud API key has HTTP referrer restrictions. `localhost:*` is blocked; `127.0.0.1:8769` is in the allowlist. Always navigate to `127.0.0.1`, not `localhost`, even though the server itself binds to `localhost`.

## Prerequisites

- `FIREBASE_WEB_API_KEY` must be set as a system environment variable (the real Firebase web API key — never committed to source).
- Working directory must be `c:\Coding\LifeShuffle\life-shuffle`.
- Node/npx available for `npx serve` (or substitute any static file server bound to port 8769).

## Port conflict

If port 8769 is taken, check what's using it:

```powershell
$p = (Get-NetTCPConnection -LocalPort 8769 -ErrorAction SilentlyContinue).OwningProcess
if ($p) { Stop-Process -Id $p -Force }
```

A stale `serve` or `dart`/`node` process from a previous session is safe to kill. If something else owns the port, use 8770 instead — but you'll also need to add `127.0.0.1:8770` to the API key's HTTP referrer allowlist in Google Cloud Console (APIs & Services → Credentials).

## Local-only mode (no sign-in, no API key needed)

To skip Firebase Auth entirely and go straight into the app:

```powershell
flutter build web --dart-define=LS_LOCAL_ONLY=true
npx --yes serve build\web -p 8769
```

## If hot reload is ever revisited

`flutter run -d chrome --web-port 8769 --web-hostname 127.0.0.1 --dart-define=FIREBASE_WEB_API_KEY=$env:FIREBASE_WEB_API_KEY` is the command that *should* work once the upstream bug is fixed. Check flutter/flutter#184233's status before re-attempting; see TROUBLESHOOTING_LOG.md for everything already ruled out so you don't repeat the investigation.
