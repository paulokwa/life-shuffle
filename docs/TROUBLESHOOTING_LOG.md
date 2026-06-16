# Troubleshooting Log

This file records technical problems, confusing fixes, failed approaches, and useful debugging notes.

Use it so future AI agents do not repeat the same mistakes.

## Format

### YYYY-MM-DD — Issue title

- **Context**:
- **Symptoms**:
- **Cause**:
- **Fix**:
- **Files affected**:
- **Prevention / future note**:

---

## 2026-06-10 — GitHub connector search lag on new repo

- **Context**: The Life Shuffle repository was newly created and docs were added quickly.
- **Symptoms**: GitHub UI showed files existed, but connector search returned no results.
- **Cause**: GitHub/code search indexing appeared to lag behind the repository state.
- **Fix**: Fetch files directly by exact path instead of relying on search.
- **Files affected**: None.
- **Prevention / future note**: When a repo is new, ask for exact file paths or screenshots and use direct file fetch. Do not assume missing search results mean missing files.

---

## 2026-06-15 - Firebase rules dry-run created Firestore database

- **Context**: Ran `firebase deploy --only firestore:rules --dry-run --project life-shuffle-8d3bd` to validate new Firestore security rules.
- **Symptoms**: The command exited successfully and compiled the rules, but also enabled the Firestore API and created the default Firestore database because it did not exist yet. The CLI also warned that `firebase.json` has an unknown top-level `flutter` property, which comes from FlutterFire config and did not block validation.
- **Cause**: Firebase CLI deploy dry-run still performs project/API/database checks and setup before testing rules compilation.
- **Fix**: No code fix needed. The rules compiled successfully.
- **Files affected**:
  - `firestore.rules`
  - `firebase.json`
- **Prevention / future note**: Treat Firebase CLI dry-run as a remote validation command, not a purely local parser. For future rules work, expect it may touch Firebase project setup if required services/databases are missing.

---

## 2026-06-15 - Browser smoke check blocked by tooling and auth gate

- **Context**: Tried to manually smoke-check the add/edit activity form in a browser after `flutter build web`.
- **Symptoms**: Python was not installed, so `python -m http.server` could not serve `build/web`. Flutter's `web-server` device served the app but the page stayed blank because the injected debug `client.js` hit a DWDS `_JsonMap` type error. A static `npx http-server` serve of `build/web` loaded the release app, but Playwright could not proceed past the Google sign-in auth gate to reach the Activities screen.
- **Cause**: Local environment/tooling limitations, plus the app currently requires Google sign-in whenever Firebase initializes successfully.
- **Fix**: Added a dev-only `LS_LOCAL_ONLY` dart define in `main.dart` so local/manual builds can skip Firebase Auth when testing app screens. Used `flutter test` with a focused AppState test to verify add, edit, disable, regenerate exclusion, and local persistence behavior. `flutter build web` also passed.
- **Files affected**:
  - `lib/main.dart`
  - `test/widget_test.dart`
- **Prevention / future note**: For browser automation before sharing/auth work matures, add a deliberate test/local-only auth bypass or a widget/integration-test harness that can reach authenticated app screens without Google OAuth.

---

## 2026-06-15 - Google sign-in blocked: two separate authorization layers

- **Context**: Google sign-in stopped working after a new Firebase API key was created following a GitHub secret scanning alert. The app showed "this app domain is not authorized in Firebase Auth."
- **Symptoms**:
  - First error (port 8080): `FirebaseAuthException code=requests-from-referer-http://127.0.0.1:8080-are-blocked` + HTTP 403 on `identitytoolkit.googleapis.com`. The 403 fires before Firebase Auth even checks its own domain list.
  - Second error (port 8769): `FirebaseAuthException code=unauthorized-domain message=This domain is not authorized for OAuth operations...`
- **Cause**: Google sign-in has **two completely independent authorization layers** that both must pass:
  1. **Google Cloud Console — API key HTTP referrer restrictions** (`APIs & Services → Credentials → [API key] → Application restrictions → HTTP referrers`). Controls which browser origins can call Google APIs using the key. Violation returns HTTP 403 with error code `requests-from-referer-{origin}-are-blocked`. Scoped per API key.
  2. **Firebase Console — Auth authorized domains** (`Authentication → Settings → Authorized domains`). Controls which domains can initiate OAuth sign-in flows. Violation returns `unauthorized-domain`. Scoped per Firebase project, not per API key.
  - The first layer was failing because the local server was running on port 8080, which was not in the API key's allowed referrers (port 8769 was). After switching back to 8769, the second layer failed because `127.0.0.1` was missing from Firebase Auth's authorized domains.
- **Fix**:
  - Layer 1: Ensure the local port in use matches an entry in the API key's HTTP referrers list in Google Cloud Console. Current allowed referrers: `127.0.0.1:8769`, `127.0.0.1:8769/*`, `localhost:8769`, `localhost:8769/*`, plus production domains.
  - Layer 2: Added `127.0.0.1` (no port, no protocol) to Firebase Console → Authentication → Settings → Authorized domains.
- **Files affected**:
  - `lib/screens/sign_in_screen.dart` — added `[AuthDebug]` console logging of `error.code`, `error.message`, and `Uri.base.origin`; updated `_friendlyAuthError` to show the origin in the error message and handle the dynamic `requests-from-referer-*-are-blocked` code with a readable explanation.
- **Prevention / future note**:
  - If sign-in breaks after rotating an API key, check both layers independently — they are in different consoles and have nothing to do with each other.
  - The API key HTTP referrer error surfaces as a **403 on identitytoolkit** and a long dynamic error code. The Firebase Auth authorized-domain error surfaces as `unauthorized-domain` with no 403.
  - When changing the local serving port, update the API key referrer list first (takes up to 5 min to propagate). Firebase Auth authorized domains propagate nearly instantly.
  - `localhost` and `127.0.0.1` are separate entries in both systems — add both explicitly.
  - The `127.0.0.1:*` wildcard entry in the API key referrer list does **not** reliably match all ports. Use explicit port entries (`127.0.0.1:8769`, `127.0.0.1:8769/*`).
  - Do not revoke an old leaked API key until sign-in is confirmed working with the new key.

---

## 2026-06-16 — GitHub secret scanning kept re-flagging rotated Firebase web keys

- **Context**: After the 2026-06-15 key rotation, the new key was committed straight into `lib/firebase_options.dart` (same pattern as before). GitHub secret scanning flagged a second key shortly after.
- **Symptoms**: Each time a new Firebase web API key was generated to replace a flagged one, it was pasted back into committed source (and once into `docs/SESSION_LOG.md` as plain text), so the very next push re-triggered the same alert on the new key.
- **Cause**: Rotating the key doesn't change where it lives. GitHub's scanner matches the `AIza...` pattern in any committed file/diff, including markdown logs, regardless of whether the key is a server secret or a client-restricted Firebase web key. As long as a real key is ever committed, scanning will flag it — rotation only resets which specific key is "current" without breaking the loop.
- **Fix**: Stopped committing the key entirely. `lib/firebase_options.dart` now reads `apiKey` from `String.fromEnvironment('FIREBASE_WEB_API_KEY')`, supplied via `--dart-define` locally and via a Netlify environment variable in CI. The literal key previously pasted into `docs/SESSION_LOG.md` was redacted. Non-secret identifiers (appId, projectId, authDomain, etc.) stayed in source since they aren't matched by secret scanning and are safe to keep public for a Firebase web app.
- **Files affected**:
  - `lib/firebase_options.dart`
  - `lib/main.dart`
  - `netlify.toml`
  - `.gitignore`
  - `docs/SESSION_LOG.md`
- **Prevention / future note**: Never paste a real Firebase/Google API key into any committed file, including session/troubleshooting logs — write "the new key" or a redacted placeholder instead. When a key needs documenting for a human, share it out-of-band (chat, password manager), not in a tracked file. If scanning flags a key again in the future, check first whether it landed in a doc/log file, not just the config file.

---

## 2026-06-16 — Setting up the Firebase key on a new machine

- **Context**: After switching to environment-variable-based key injection (2026-06-16), future development on other machines requires the `FIREBASE_WEB_API_KEY` env var to be set locally so `flutter run` can inject it at build time.
- **Setup steps for any new machine**:
  1. Clone/pull the repo as normal (no API key in source).
  2. Get the current Firebase web API key from a human source (chat, password manager, Firebase Console) — never from git.
  3. **Set the system environment variable** (one-time per machine):
     - **Windows**: Open System Properties → Environment Variables → New (User variables) → `FIREBASE_WEB_API_KEY` = your key → OK → restart VS Code / PowerShell.
     - **Mac/Linux**: Add `export FIREBASE_WEB_API_KEY="your-key-here"` to `~/.zshrc` or `~/.bashrc` → `source ~/.zshrc` or restart shell.
  4. **Test locally**: `flutter run -d chrome --web-port 8769` should start the app on http://127.0.0.1:8769/ with sign-in enabled (you'll see the "Sign in with Google" button, not local-only mode).
  5. **Optional: create a local runner script** (already gitignored):
     - Copy `tool/local_run.ps1.example` to `tool/local_run.ps1` (or `.sh` on Mac/Linux).
     - Replace `YOUR_KEY_HERE` with your actual key.
     - Run it instead of typing the full command each time. The file is gitignored so your key stays local.
- **Symptoms of missing env var**: `flutter run` launches the app, but you see "local-only mode" (no sign-in button, no Firebase features). Check `flutter run` console output for `[WARNING] FIREBASE_WEB_API_KEY was not provided...`.
- **Do not do**: Do not create a `firebase_options.dart` with a literal key. Do not add the key to `.env.local` and commit it. Do not hardcode it in a build script that's tracked.
- **Files affected**: None — this is purely an environment setup task.
- **Prevention / future note**: Always distribute the key securely (password manager, 1Password, LastPass, team chat with autodeleting messages) rather than in any file. The env-var approach means each machine must fetch the key once and set it locally; this is intentional — it prevents accidental commits.

---

## 2026-06-16 — Sign-in broken after rotating to a new API key (referrer restrictions not set)

- **Context**: After rotating the Firebase web API key and setting the new key in the Netlify env var and local env var, both local and Netlify sign-in stopped working.
- **Symptoms**:
  - Local: "Sign-in failed (requests-from-referer-http://127.0.0.1:8769-are-blocked.): Error" on the sign-in page.
  - Netlify: Spinning wheel on the "Continue with Google" button, never resolves.
- **Cause**: A brand new API key has no HTTP referrer restrictions configured. The old key had them set up; the new key starts blank (or blocks everything by default). Google Cloud Console's key referrer restrictions and Firebase Auth authorized domains are independent — rotating the key loses all the referrer config on the old key.
- **Fix**: Go to **Google Cloud Console → APIs & Services → Credentials → [new key] → Application restrictions → HTTP referrers** and add:
  ```
  *.firebaseapp.com
  *.firebaseapp.com/*
  127.0.0.1:*
  127.0.0.1:8769
  127.0.0.1:8769/*
  life-shuffle-8d3bd.firebaseapp.com/*
  life-shuffle.netlify.app
  life-shuffle.netlify.app/*
  localhost:*
  localhost:8769
  ```
  Wait 2-3 minutes for propagation. Netlify recovers without a rebuild; local just needs a browser refresh.
- **Files affected**: None — this is a Google Cloud Console configuration task.
- **Prevention / future note**: Every time you rotate to a new API key, immediately go to Google Cloud Console and copy the referrer restrictions from the old key to the new one before testing sign-in. Keep a copy of the required referrer list somewhere handy (e.g. this file) so you're not rebuilding it from scratch each time.

---

## 2026-06-16 — `flutter run` fails with "Failed to bind web development server" on port 8769

- **Context**: Tried to restart the local dev server by running `./tool/local_run.ps1` after the previous server process went stale/silent.
- **Symptoms**: `SocketException: Failed to create server socket ... port = 8769` — Flutter refuses to start because the port is already occupied by a zombie process from the previous session.
- **Cause**: The old `flutter run` process didn't exit cleanly, leaving port 8769 bound even though it was no longer serving the app correctly.
- **Fix**: Kill the process holding the port, then re-run the script:
  ```powershell
  # In PowerShell (VS Code terminal)
  $p = (Get-NetTCPConnection -LocalPort 8769 -ErrorAction SilentlyContinue).OwningProcess
  if ($p) { Stop-Process -Id $p -Force }
  ./tool/local_run.ps1
  ```
- **Files affected**: None.
- **Prevention / future note**: If `./tool/local_run.ps1` gives a port binding error, always run the kill command above first. Do not use `$pid` as a variable name in PowerShell — it is a reserved read-only variable; use `$p` or similar instead.

---
