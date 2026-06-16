---
description: Launch the Life Shuffle Flutter web app locally in Chrome for manual testing
---

# Run Life Shuffle locally

## How to launch

Run directly in the VS Code terminal (keeps the process attached so you can press `r` to hot reload):

```powershell
./tool/local_run.ps1
```

Or manually:

```powershell
cd "c:\Coding\New folder\life-shuffle"
flutter run -d chrome --web-port 8769 --web-hostname 127.0.0.1 --dart-define=FIREBASE_WEB_API_KEY=$env:FIREBASE_WEB_API_KEY
```

Chrome opens automatically at **http://127.0.0.1:8769**. Google sign-in works at this URL.

## Hot reload

With the terminal attached, press **`r`** to hot reload (picks up code changes instantly) or **`R`** for a full restart. Do **not** use browser F5 — that drops the Dart VM connection and causes a blank page.

## Why 127.0.0.1 and not localhost

The Firebase/Google Cloud API key has HTTP referrer restrictions. `localhost:*` is blocked; `127.0.0.1:8769` is in the allowlist. Always use `--web-hostname 127.0.0.1` — omitting it makes Flutter open Chrome at `localhost:PORT` which triggers a "requests-from-referer-are-blocked" sign-in error.

## Prerequisites

- `FIREBASE_WEB_API_KEY` must be set as a system environment variable (the real Firebase web API key — never committed to source).
- Working directory must be `c:\Coding\New folder\life-shuffle`.

## Port conflict

If port 8769 is taken, check what's using it:

```powershell
netstat -ano | findstr ":8769 "
(Get-CimInstance Win32_Process -Filter "ProcessId=<PID>").CommandLine
```

A stale `serve build\web` process is safe to kill (`Stop-Process -Id <PID> -Force`). If something else owns the port, use 8770 instead — but you'll also need to add `127.0.0.1:8770` to the API key's HTTP referrer allowlist in Google Cloud Console (APIs & Services → Credentials).

## Local-only mode (no sign-in, no API key needed)

To skip Firebase Auth entirely and go straight into the app:

```powershell
Start-Process -NoNewWindow -FilePath "flutter" -ArgumentList "run", "-d", "chrome", "--web-port", "8769", "--web-hostname", "127.0.0.1", "--dart-define=LS_LOCAL_ONLY=true"
```

## Notes

- Hot reload is available while the flutter process runs (press `r` in the terminal).
- If Chrome didn't open automatically, navigate to http://127.0.0.1:8769 manually.
