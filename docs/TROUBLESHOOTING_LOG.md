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

## 2026-06-17 — `flutter run -d chrome` fails with "SDK root directory not found: /C:/..." on Windows (unresolved upstream bug — use static build workflow instead)

- **Context**: Setting up a new dev machine with puro-managed Flutter. `flutter build web` works fine but `flutter run -d chrome` (debug/hot-reload mode) always fails to compile.
- **Symptoms**: `Error: SDK root directory not found: /C:/Users/mwake/.puro/envs/stable/flutter/bin/cache/flutter_web_sdk/.` — the path begins with `/C:/` (a POSIX-style path) instead of `C:\`, so Windows can't find the directory even though it physically exists.
- **What was ruled out** (each tested directly, error was byte-for-byte identical every time):
  - Flutter version: reproduced on both 3.44.2 (Dart 3.12.2) and 3.41.9 (Dart 3.11.5) after creating a fresh puro env (`puro create v3-41 3.41.9`).
  - puro's symlinked cache: manually replaced every symlink in `bin\cache\` (`artifacts`, `dart-sdk`, `downloads`, `flutter_web_sdk`, `pkg`) with real directory copies, and ran via `puro --skip-cache-sync flutter run ...` to stop puro re-linking them. Same error.
  - Calling `flutter.bat` directly instead of through PATH/puro's stub: same error.
  - Note: puro's per-env `bin\flutter.bat` is itself a generated stub (`"%PURO_BIN%\puro" flutter %*`) that re-syncs (re-symlinks) the cache on every invocation unless `--skip-cache-sync` is passed — this caused early false negatives when testing the "real copy" fix.
- **Likely real cause**: Matches upstream [flutter/flutter#184233](https://github.com/flutter/flutter/issues/184233) ("Flutter run web doesn't work with symlinks(?)", open, unfixed as of report date 2026-03-27). The `/C:/` leading-slash pattern is consistent with code that uses a `file:///C:/...` URI's `.path` property directly as a filesystem path instead of calling `.toFilePath()` — on Windows `Uri.path` legitimately returns `/C:/...` per spec, which is correct URI behavior but invalid as a raw Windows path. This points to a genuine Flutter/Dart tooling bug in the DDC/frontend_server pipeline on Windows, not anything specific to puro, symlinks, or this project's dependencies. `flutter build web` is unaffected because it uses dart2js, not DDC.
- **Fix**: None found. This is an open upstream bug.
- **Workaround (what we actually use)**: Static build + serve instead of `flutter run -d chrome`:
  ```powershell
  flutter build web --dart-define=FIREBASE_WEB_API_KEY=$env:FIREBASE_WEB_API_KEY
  npx --yes serve build\web -p 8769
  ```
  Then open `http://127.0.0.1:8769` in Chrome (any normal profile — no special dev profile needed). No hot reload; each code change requires re-running `flutter build web` (~60-90s) then refreshing the browser. `serve` binds to `localhost:8769` but the address `127.0.0.1:8769` still works and satisfies the API key referrer allowlist (see the two-layer auth note below) since the allowlist check is based on the browser's address bar URL, not the bind address.
- **Files affected**: None — this is an environment/tooling limitation, not a code fix.
- **Prevention / future note**: Don't re-attempt fixing this without checking whether flutter/flutter#184233 has been closed upstream first. If revisiting, the next untested step would be a vanilla (non-puro) Flutter SDK install to a clean path, to confirm whether puro's installation method (not just its symlinks) is implicated at all, or whether this reproduces on any Windows Flutter install.

---

## 2026-06-20 - Netlify tried to deploy a function test file

- **Context**: Production Netlify deploy after adding the public ICS feed function.
- **Symptoms**: Flutter web build succeeded, functions bundling succeeded, secrets scan passed, but deploy failed with: `The following serverless functions failed to deploy: calendar-feed.test`. Netlify said function names can contain only alphanumeric characters, hyphens, or underscores.
- **Cause**: `calendar-feed.test.js` lived under `netlify/functions`. Netlify treats every `.js` file in the configured functions directory as a deployable function, so it attempted to deploy the test file as a function named `calendar-feed.test`, and the dot made that function name invalid.
- **Fix**: Move function tests out of the deployable directory to `netlify/tests/calendar-feed.test.js`, update `npm test` to run `node --test "netlify/tests/**/*.test.js"`, and keep `netlify/functions` for real serverless functions only.
- **Files affected**:
  - `package.json`
  - `netlify/functions/calendar-feed.js`
  - `netlify/tests/calendar-feed.test.js`
  - `README.md`
  - `docs/ICS_FEED_ENDPOINT_PLAN.md`
- **Prevention / future note**: Do not place `.test.js`, fixtures, helpers, or non-function scripts directly under `netlify/functions`. Put tests under `netlify/tests` or another non-deploy directory and import the function module from there.

---

## 2026-06-20 - Deployed sync diagnostic shows `Firestore permission denied`

- **Context**: The deployed app showed the temporary Settings sync diagnostics card with `Firestore permission denied`, and the admin calendar diagnostic still found zero documents in the top-level `calendars` collection.
- **Symptoms**:
  - Settings > Account displayed `Sync diagnostics` with `Firestore permission denied`.
  - `powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_firestore_calendar.ps1` authenticated with Admin credentials but reported `No calendars found`.
- **Likely cause**: The first browser write flow reached Firestore but was denied before any document was created. `FirestoreSyncService.saveState` reads `calendars/{uid}_default` to check whether the document exists before it writes. With zero documents present, the original read rule only allowed owners/members based on `resource.data`, so the initial existence check for the signed-in user's own default calendar path was denied. The rules also used `request.auth.uid in memberUserIds`; this was changed to the explicit list helper form `memberUserIds.hasAny([request.auth.uid])`.
- **Fix applied**:
  ```powershell
  powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_firebase_rules.ps1
  ```
  The rules compiled and deployed successfully to `life-shuffle-8d3bd`. A second rules deploy added `isOwnDefaultCalendarPath(calendarId)` and allows reads of only `request.auth.uid + '_default'` for the signed-in user, so the first-save existence check can complete without broadening access to other calendars.
- **Files affected**:
  - `firestore.rules`
  - `docs/SESSION_LOG.md`
  - `docs/TROUBLESHOOTING_LOG.md`
- **Follow-up**: Refresh the deployed app, make a fresh signed-in state change, then rerun the Firestore calendar diagnostic. If it still reports permission denied, add a temporary local rules unit test or emulator repro for the exact initial calendar payload and first `get()` call.

---

## 2026-06-20 - Onboarding screens could route before initial Firestore sync

- **Context**: After browser/client data was cleared but Firestore data remained, signing back in showed the display-name prompt and mini onboarding, while the calendar-name prompt was skipped.
- **Symptoms**: Firestore diagnostic showed the remote calendar already had `displayNameConfirmed: true`, a display name present, and `calendarNameConfirmed: true`, so both name prompts should have been skipped after remote state loaded.
- **Cause**: `AuthGate` made onboarding routing decisions immediately from local/default `AppState` before `syncWithFirestore()` completed. It also did not listen to `AppState` changes, so remote sync could update `displayNameConfirmed` and `calendarNameConfirmed` without rebuilding the route until another UI action happened.
- **Fix**: Added signed-in initial-sync flags to `AppState`, made `AuthGate` show the existing splash state while the first remote sync is pending, and registered `AuthGate` as an `AppState` listener so remote state changes rebuild the routing decision.
- **Files affected**:
  - `lib/state/app_state.dart`
  - `lib/widgets/auth_gate.dart`
  - `test/widget_test.dart`
  - `tool/diagnostics/check_firestore_calendar.js`
- **Prevention / future note**: Any future signed-in routing gate should wait for initial remote restore before deciding setup/onboarding steps. Local-only mode should continue without waiting because it has no signed-in user ID.

---

## 2026-06-20 - Mini onboarding completion was widget-local only

- **Context**: The mini onboarding intro appeared again after login/reload even though display-name and calendar-name setup were already persisted.
- **Symptoms**: `AuthGate` held completion in `_onboardingDone`, so recreating the widget reset the intro state. Firestore diagnostic showed no remote `introOnboardingCompleted` flag yet.
- **Cause**: Mini onboarding completion had not been included in `SavedState`, SharedPreferences, or the flat Firestore calendar document.
- **Fix**: Added `introOnboardingCompleted` to `SavedState`, local persistence, Firestore mapping, and `AppState.completeIntroOnboarding()`. `AuthGate` now routes from `appState.introOnboardingCompleted`, and Settings > Privacy/help can replay the intro without resetting the stored flag.
- **Files affected**:
  - `lib/services/persistence_service.dart`
  - `lib/state/app_state.dart`
  - `lib/widgets/auth_gate.dart`
  - `lib/screens/settings_screen.dart`
  - `test/widget_test.dart`
  - `tool/diagnostics/check_firestore_calendar.js`
- **Prevention / future note**: Setup flow gates should be stored in `SavedState` when they should survive reload, sign-out/sign-in, or cleared browser storage for signed-in users.

---

## 2026-06-20 - Settings/Activities toggles flashed and bounced to Today (signed-in only)

- **Context**: After `AuthGate` was made an `AppState` listener (the initial-sync fix above), every Settings/Activities control that mutates `AppState` — Plan style, Difficulty/Energy/Social toggles, the Publishing toggle, Activities page toggles — started briefly flashing and returning the signed-in user to the Today tab. Did not reproduce in local-only mode or in widget tests, only on the deployed Netlify build while signed in.
- **Symptoms**: No console errors, no full-page network reload (ruled out a stale service-worker/page reload). Reproduced consistently across every toggle, not just the one being actively tested, since they all funnel through the same `AppState.notifyListeners()`.
- **Cause**: `AuthGate.build()` called `FirebaseAuth.instance.authStateChanges()` fresh inside `build()`, creating a new `Stream<User?>` instance every rebuild. Once `AuthGate` rebuilt on every `AppState` change (not just real auth changes), `StreamBuilder` saw a "new" stream each time and resubscribed, briefly dropping to `ConnectionState.waiting` (showing `_SplashScreen`) before Firebase immediately re-emitted the current user to the new subscription. That `BottomNavShell` -> `_SplashScreen` -> `BottomNavShell` swap unmounted and remounted `BottomNavShell`, resetting its selected tab index back to 0 (Today). Only manifests when `AuthService.isReady` is true (real Firebase signed-in session), which is why local-only mode and widget tests (no real Firebase init) never hit the buggy branch.
- **Fix**: Cache `FirebaseAuth.instance.authStateChanges()` once per `_AuthGateState` (a `final` field set at construction) instead of calling it inside `build()`, so `StreamBuilder` always receives the same stream identity across rebuilds.
- **Files affected**:
  - `lib/widgets/auth_gate.dart`
- **Prevention / future note**: Any `Stream`/`Future` passed to a `StreamBuilder`/`FutureBuilder` must be created once (field/`initState`), never inline in `build()`, especially on a widget that rebuilds in response to a broad listener like a whole-app `ChangeNotifier`. Diagnosing this took longer than necessary because of a missing `netlify.toml` Flutter version pin (separate, real issue, but not the actual cause) — when local repro fails but production repro is consistent, check what code paths are gated behind environment flags like `AuthService.isReady` before assuming an infra/version mismatch.

---
