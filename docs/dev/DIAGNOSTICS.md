# Diagnostics

These tools help check the Life Shuffle Firebase, Firestore, Netlify environment, and public ICS feed without guessing in dashboards.

## Setup

Install project dependencies:

```powershell
npm install
```

Install CLIs if they are missing:

```powershell
npm install -g firebase-tools
npm install -g netlify-cli
```

Login and link the local checkout:

```powershell
firebase login
netlify login
netlify link
```

Do not install or change Flutter versions for diagnostics.

## Local service account file

The Firestore calendar diagnostic needs Firebase Admin credentials. Use either:

- `FIREBASE_SERVICE_ACCOUNT_JSON` in your shell, or
- a local file at `tool/serviceAccountKey.json`.

Generate the JSON from Firebase Console > Project Settings > Service Accounts for project `life-shuffle-8d3bd`.

Never commit the service account JSON. `tool/serviceAccountKey.json` and `*firebase-adminsdk*.json` are gitignored.

## Scripts

Run from the repo root.

```powershell
powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_netlify_env.ps1
```

Checks Netlify login/link status and confirms whether `FIREBASE_WEB_API_KEY` and `FIREBASE_SERVICE_ACCOUNT_JSON` exist by name. It does not print values.

```powershell
powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_firebase_rules.ps1
```

Checks local Firestore rules deployment prerequisites. It does not deploy rules or contact the Firebase project.

The Firebase CLI available for this project does not provide a standalone local Firestore rules validation command. Rules deployment is intentionally split into a separate, explicit production deploy script:

```powershell
powershell -ExecutionPolicy Bypass -File tool/diagnostics/deploy_firebase_rules.ps1
```

This deploys production Firestore rules to project `life-shuffle-8d3bd`. Do not run it unless the rules change has been reviewed and approved for production.

```powershell
powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_firestore_calendar.ps1
```

Lists safe fields from documents in the `calendars` collection. It never prints private keys, full feed tokens, or cached ICS bodies.

```powershell
powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_ics_feed.ps1 "https://life-shuffle.netlify.app/.netlify/functions/calendar-feed?token=..."
```

Fetches a feed URL, prints HTTP status, content type, and whether the response contains `BEGIN:VCALENDAR` and `END:VCALENDAR`. For 404/500 responses, it prints the response body but never prints the token separately.

## Current issue to diagnose

If the deployed app says "Feed is live" but Firebase Console has no `calendars` collection and the ICS endpoint returns `{"error":"not_found"}`, the feed function is probably working but has no Firestore calendar document to serve.

Likely causes:

- The deployed Flutter app is local-only because `FIREBASE_WEB_API_KEY` is missing or stale in Netlify.
- Firebase client sync is failing in the browser.
- Firestore rules were not deployed or are blocking writes.
- The deployed site is stale and does not contain the latest Firestore publishing code.

Use the diagnostics in this order:

1. `check_netlify_env.ps1`
2. `check_firebase_rules.ps1`
3. If rules deployment has been explicitly approved, run `deploy_firebase_rules.ps1`.
4. Sign in to the deployed app and make a small calendar change.
5. `check_firestore_calendar.ps1`
6. `check_ics_feed.ps1` with the copied feed URL.
