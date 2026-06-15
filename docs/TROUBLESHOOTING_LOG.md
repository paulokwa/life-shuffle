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
