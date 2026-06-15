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
