# life-shuffle
Mobile-first Flutter application for planning personal activities, generating rule-based calendars, and helping users get unstuck.

## Local dev setup

The Firebase web API key is not committed to the repo (GitHub secret scanning flags committed Google API keys). It's passed in at build time via `--dart-define`:

```
flutter run -d chrome --web-port 8769 --dart-define=FIREBASE_WEB_API_KEY=your-key-here
flutter build web --dart-define=FIREBASE_WEB_API_KEY=your-key-here
```

Without the key, the app falls back to local-only mode (no sign-in, full local planner still works). Get the key from Firebase Console → Project settings → General → Web app, or ask whoever holds the project credentials.

To avoid retyping the key, copy `tool/local_run.ps1.example` to `tool/local_run.ps1` (gitignored) and fill in your key there.

## Netlify

Netlify build reads the key from a `FIREBASE_WEB_API_KEY` environment variable (Site settings → Environment variables) and passes it through in `netlify.toml`. Never put the real key in `netlify.toml` itself.

## Calendar feed (Netlify Function)

`netlify/functions/calendar-feed.js` serves the read-only `.ics` subscription feed for a published calendar at:

```
/.netlify/functions/calendar-feed?token=<feedToken>
```

It looks up the calendar by `feedToken` in Firestore and returns the `cachedIcsText` the Flutter app already generated and saved (see `docs/ICS_FEED_ENDPOINT_PLAN.md` for the full design). It needs one more environment variable beyond `FIREBASE_WEB_API_KEY`:

| Var | Where to get it |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase Console → Project Settings → Service Accounts → "Generate new private key" for project `life-shuffle-8d3bd`. Paste the entire downloaded JSON file as one Netlify dashboard environment variable value. Never commit the key file itself — `tool/serviceAccountKey.json` is gitignored for local use. |

This repo also has a small root-level `package.json` (Node, not Dart) just for this function. To work on it locally:

```
npm install
npm test
```

`npm test` runs `netlify/tests/calendar-feed.test.js` with Node's built-in test runner — no credentials needed, since it only exercises the pure decision logic and the no-credentials/wrong-method/missing-token error paths. Tests intentionally live outside `netlify/functions` so Netlify does not deploy them as serverless functions. Testing against a real calendar requires `netlify dev` plus a real `FIREBASE_SERVICE_ACCOUNT_JSON` — see `docs/ICS_FEED_ENDPOINT_PLAN.md` section 8.

## Outside events spike

The Outside Events browser loads curated RSS/Atom feeds through:

```
/.netlify/functions/outside-events-rss?source=<curatedSourceId>
```

The function only accepts source IDs defined in `netlify/functions/outside-events-rss.js`; it does not proxy arbitrary user-provided URLs. The Flutter adapter keeps a matching curated registry in `lib/services/curated_rss_feed_registry.dart` and falls back to direct fetch only when the proxy is unavailable, which is mainly useful for tests/native contexts.

API-backed adapters remain present but are not live unless credentials and backend calls are added:

| Source | Environment variable | Current state |
|---|---|---|
| Ticketmaster | `TICKETMASTER_API_KEY` | Adapter reports not configured. Live Flutter web use should go through a Netlify Function so the key is not exposed. |
| Eventbrite | `EVENTBRITE_API_TOKEN` | Adapter reports not configured. API/token shape still needs verification before live calls. |
| Bandsintown | `BANDSINTOWN_APP_ID` | Adapter reports not configured. Artist/search strategy still needs a product decision. |

## Diagnostics

Local deployment diagnostics live in `docs/dev/DIAGNOSTICS.md` and `tool/diagnostics/`.

Start with:

```
powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_netlify_env.ps1
powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_firebase_rules.ps1
powershell -ExecutionPolicy Bypass -File tool/diagnostics/check_firestore_calendar.ps1
```

The scripts check Netlify env var names, check local Firestore rules deployment prerequisites without deploying, and inspect safe Firestore calendar fields. They must not print secret values, full feed tokens, private keys, or cached ICS bodies.

Production Firestore rules deployment is intentionally separate:

```
powershell -ExecutionPolicy Bypass -File tool/diagnostics/deploy_firebase_rules.ps1
```

Only run the deploy script after the rules change has been reviewed and approved for production.  
