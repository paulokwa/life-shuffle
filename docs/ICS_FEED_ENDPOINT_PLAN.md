# Public ICS Feed Endpoint — Implementation Plan

Status: **Implemented and deployed-verified** (`netlify/functions/calendar-feed.js`, implemented 2026-06-18; deployed feed verified 2026-06-20 - see `docs/SESSION_LOG.md`). The sections below are kept as the design record; a few details were adjusted during implementation and are called out inline where they diverge from what was originally proposed.

This plan covers the smallest safe way to let Apple Calendar, Google Calendar, Outlook, and similar apps subscribe to a Life Shuffle calendar's read-only `.ics` feed, using the private feed-token metadata that already exists (`docs/SESSION_LOG.md`, 2026-06-18 — "Private feed token metadata and publishing toggle").

Scope guardrails (per MASTER_PLAN.md and this task's instructions):
- Read-only ICS only. No write-back, no Google Calendar API.
- Token-based access only. No auth/sign-in required to fetch the feed URL.
- No invite/member UI changes.
- No multiple-calendar work. Today there is exactly one calendar per user (`calendars/{userId}_default`), and this design does not need to change for that to stay true.

## 0. Key design decision that must be made before coding

This is the one architectural fork in the plan. Everything else follows from it.

**The problem:** `AppState._buildPlan()` (`lib/state/app_state.dart:564`) does not store a fixed list of future dated events. It recomputes "this calendar week" on every call from `PlannerService.mondayOf(DateTime.now())` plus the stored `seed`, then runs the full rule-based placement algorithm (enabled/disabled, `maxPerWeek`, `allowedWeekdays`, `noConsecutiveDays`, difficulty-aware spacing, time-slot assignment). Firestore only stores the *inputs* (`activities`, `seed`, `planStyle`, `difficultyEnabled`, `checkinMap`, `lockedMap`) — never the resolved `DayPlan` with real calendar dates.

A Netlify Function written in Node can't run this Dart logic. There are two ways to bridge that gap:

- **Option A (recommended) — cached ICS text, written by the Flutter client.**
  Whenever `AppState._persist()` runs and the feed is enabled, the client calls the existing `IcsCalendarService.generate()` (`lib/services/ics_calendar_service.dart`) against the current `_weekPlan` and writes the resulting ICS string into the calendar's Firestore document (`cachedIcsText` + `cachedIcsUpdatedAtMillis` — implemented as those names rather than the originally-sketched `icsFeed`/`icsFeedUpdatedAtMillis`). The Netlify Function becomes a dumb, stateless proxy: look up the doc by token, check `feedEnabled`, serve the cached text.
  - Pro: zero duplicated business logic. The function never needs to know about rules, difficulty spacing, or time slots.
  - Con: the cached text only refreshes when someone with the app open triggers a save. If nobody opens the app for a week, the feed keeps serving last week's dates until the next open.

- **Option B (rejected for MVP) — port the planner to JavaScript.**
  The function reads raw `activities`/`seed`/`planStyle` from Firestore and reimplements `PlannerService.generateWithDiagnostics` in JS so the feed is always "live."
  - Con: duplicates a non-trivial rule engine in a second language, which is exactly the kind of scope this task says to avoid ("no multiple calendars work unless absolutely required" / keep it MVP). Drift between the two implementations would be a real bug source.

**Recommendation: Option A.** The staleness tradeoff is already an accepted product limitation — MASTER_PLAN.md already says "External calendar apps may not refresh subscribed calendars immediately" and Settings already tells users feed refresh isn't instant. Extending that same accepted limitation to "the feed reflects the calendar as of the last time someone opened the app" is consistent with what's already shipped, and it's reversible later (swap what the function reads without changing the URL contract or token model).

The rest of this plan assumes Option A. Confirm this before the next coding session starts; if rejected, the endpoint shape/security/error sections below are unaffected, but step 1 in the implementation checklist changes substantially.

## 1. Endpoint shape

```
GET https://life-shuffle.netlify.app/.netlify/functions/calendar-feed?token=<feedToken>
```

- Single query param: `token`. No path segments, no calendar ID in the URL — the token alone is both the lookup key and the secret.
- `GET` only. Reject other methods with `405` + `Allow: GET`.
- This is the URL the Settings > Publishing screen will eventually show in `_FeedLinkPlaceholder` (`lib/screens/settings_screen.dart:402`) once it stops being a placeholder.

## 2. How the function finds a calendar by feedToken

- Calendars live in a single top-level collection: `calendars/{calendarId}` (today, `calendarId` is always `{userId}_default` — see `FirestoreSyncService.defaultCalendarId`).
- The function uses the **Firebase Admin SDK** (server-side, service-account credentials), which bypasses `firestore.rules` entirely. No client-facing security rule changes are needed.
- Lookup: `db.collection('calendars').where('feedToken', '==', token).limit(1).get()`.
- After fetching, check `feedEnabled` (falling back to `isPublished` for older docs, matching the existing Dart fallback in `CalendarMetadata.fromMap` at `lib/services/firestore_sync_service.dart:172`) **in application code, not in the query**. Putting `feedEnabled == true` directly in the Firestore query would silently miss any doc that only has the legacy `isPublished` field set — checking in code after fetch avoids that trap and keeps one clear 404 path.

## 3. Does Firestore need an index or a token-lookup collection?

**No to both.**

- No separate lookup collection: token uniqueness is already global (32 random bytes via `Random.secure()`, base64url-encoded, ~43 chars — see `AppState._generateFeedToken`, `lib/state/app_state.dart:659`), so querying the existing `calendars` collection directly by `feedToken` is unambiguous even if multiple-calendar support is added later (every calendar doc, regardless of owner, still has its own globally-unique token).
- No manual composite index: the lookup is a single equality filter on one field (`feedToken == token`). Firestore auto-creates a single-field index for every field by default, and single-equality queries never require a manually-defined composite index — composite indexes are only needed for range/`!=`/`array-contains` filters combined with `orderBy` on a different field, which doesn't apply here.

## 4. Privacy/security risks of token URLs

- **The token is a bearer secret.** Anyone with the URL can read the calendar's titles, categories, and times for as long as the feed stays enabled — already disclosed in Settings ("Anyone with a published feed link may be able to view that feed"). This plan doesn't change that contract, just makes it real.
- **Logging leakage.** Netlify Function logs capture the full request URL including the query string by default. The function must not log the raw `token` value (log a truncated/hashed prefix only, e.g. first 8 chars, if logging is needed at all for debugging).
- **Error-response leakage.** Never echo the submitted token back in an error body, and never let a 404 reveal *why* it's a 404 (don't distinguish "token never existed" from "token exists but feed is disabled" — both must return the same generic 404; see §6).
- **Shared/intermediate caches.** Because the content is private-but-token-gated, response caching must say `private` (not `public`) so CDNs, corporate proxies, or browser shared caches don't store it (see §5).
- **Transport.** Netlify serves everything over HTTPS already; no extra work needed, but worth stating explicitly since the token is effectively a password in the URL.
- **Revocation is the main mitigation**, and it already exists end-to-end: `AppState.revokeFeedToken()` clears `_feedToken` to `null`, so a lookup against the old token simply returns zero Firestore results — no extra revocation logic needed in the function.
- **Out of scope for MVP:** rate limiting / abuse throttling. At two-person household scale this isn't worth the complexity; revisit only if the feed URL ever leaks publicly.

## 5. Cache headers

```
Content-Type: text/calendar; charset=utf-8; method=PUBLISH
Content-Disposition: inline; filename="life-shuffle.ics"
Cache-Control: private, max-age=900, must-revalidate
```

- `private` because the content is access-controlled by a secret token, not safe for shared/CDN caches.
- `max-age=900` (15 minutes) is a reasonable MVP balance between Firestore read cost and freshness; calendar apps already poll on their own schedule (often hourly+), so this mostly just protects against accidental rapid re-fetching.
- ETag / `If-None-Match` / `304 Not Modified` support (keyed off `icsFeedUpdatedAtMillis`) is a clean fast-follow but not required for MVP — skip it in the first implementation.

## 6. Disabled/revoked feed behavior

| State | Firestore shape | Function response |
|---|---|---|
| Never published | no doc has this token | `404` |
| Enabled | `feedEnabled: true`, `feedToken` set, `cachedIcsText` present | `200` + ICS body |
| Disabled (toggle off, token kept) | `feedEnabled: false`, `feedToken` still set | `404` |
| Revoked / regenerated | old token cleared from the doc entirely | `404` (lookup finds nothing) |
| Enabled but `cachedIcsText` not yet computed (edge case — feed just turned on, no save has run yet) | `feedEnabled: true`, `cachedIcsText` missing/empty | `404` |

All four "not available" rows return the **same generic 404**, by design (see §4 — no signal about *why*).

## 7. Error responses

| Condition | Status | Body |
|---|---|---|
| Missing/empty `token` query param | `404` | `{"error":"not_found"}` |
| Method other than GET | `405` (+ `Allow: GET`) | `{"error":"method_not_allowed"}` |
| Token not found, disabled, or revoked | `404` | `{"error":"not_found"}` |
| Firestore/Admin SDK failure | `500` | `{"error":"internal_error"}` (no internals in the body; log details server-side only) |

Error bodies are plain JSON for easy debugging; calendar clients fetching a working feed will only ever see `200` + ICS text, so the error shape doesn't need to be calendar-app-friendly.

**Implementation note:** a missing token returns `404` rather than the `400` originally sketched above. Folding it into the same generic "not available" bucket as every other negative case is simpler and slightly more private (it removes even the weak signal of "this looks like a well-formed-but-wrong request" vs. "this looks malformed").

## 8. Local testing steps

**Automated (done, run anytime, no credentials needed):** `npm test` (`node --test "netlify/tests/**/*.test.js"`) runs `netlify/tests/calendar-feed.test.js` against the pure helper functions (`extractToken`, `isFeedEnabled`, `buildFeedResponse`) and the parts of `handler` that don't need live Firestore access (missing token, wrong method, missing credentials). This is fast unit coverage, not a substitute for the steps below against a real calendar. Tests intentionally live outside `netlify/functions` so Netlify does not package them as deployable serverless functions.

**Manual, against a real calendar (deployed endpoint verification passed 2026-06-20; real calendar-app subscription still pending):**

1. Get a Firebase service-account key for local-only use: Firebase Console → Project Settings → Service Accounts → "Generate new private key" for project `life-shuffle-8d3bd`. Save it outside the repo or to a gitignored path (e.g. `tool/serviceAccountKey.json` — already added to `.gitignore`, never commit it).
2. Export it for local function runs as `FIREBASE_SERVICE_ACCOUNT_JSON` (the function reads this exact env var — see §9). On Windows PowerShell: `$env:FIREBASE_SERVICE_ACCOUNT_JSON = Get-Content tool/serviceAccountKey.json -Raw`.
3. Get a real `feedToken` to test against: enable publishing in a signed-in local app run (Settings > Publishing), then either copy the link directly from the new "Copy link" button, or read `feedToken` from the Firebase Console (`calendars/{uid}_default`).
4. Run the function locally with the Netlify CLI: `netlify dev` (serves both the function and a static site) or `netlify functions:serve` (function only).
5. `curl "http://localhost:8888/.netlify/functions/calendar-feed?token=<token>"` and confirm `Content-Type: text/calendar` and a well-formed `BEGIN:VCALENDAR…END:VCALENDAR` body. Cross-check the body against `test/ics_calendar_service_test.dart` expectations.
6. Exercise the negative paths: no `token` param (expect 404), a made-up token (expect 404), a token for a disabled feed (expect 404, after toggling off in Settings), a POST request (expect 405).
7. Recommended before considering this fully verified: use `netlify dev --live` (or any HTTPS tunnel) to get a public HTTPS URL, then actually add it as a subscribed calendar in Apple Calendar or Google Calendar and confirm it imports without errors — this is the only way to catch ICS formatting issues that `curl` won't surface.
8. Optional: run against the Firebase Local Emulator Suite (`firebase emulators:start --only firestore`, with `FIRESTORE_EMULATOR_HOST=localhost:8080` set for the function process) to avoid touching the real project's data while iterating. Seed a fake calendar doc with a known token via the Emulator UI.

**Deployed verification completed 2026-06-20:**

- Netlify env diagnostics confirmed `FIREBASE_SERVICE_ACCOUNT_JSON` is present.
- Firestore diagnostics confirmed one real `calendars/{uid}_default` document with `feedEnabled: true`, a feed token, and cached ICS text.
- The deployed Netlify endpoint returned HTTP 200 with `Content-Type: text/calendar; charset=utf-8; method=PUBLISH`.
- The response body contained both `BEGIN:VCALENDAR` and `END:VCALENDAR`.

## 9. Netlify env vars needed

| Var | Purpose | Notes |
|---|---|---|
| `FIREBASE_WEB_API_KEY` | Already exists; used only by the Flutter web build | Function does not need this |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | New. Full service-account JSON (as one string) for Admin SDK auth | Paste the entire downloaded JSON file as one Netlify dashboard value, then `JSON.parse()` it in the function. Preferred over splitting into `FIREBASE_PROJECT_ID`/`FIREBASE_CLIENT_EMAIL`/`FIREBASE_PRIVATE_KEY` because the private key's embedded `\n` characters are a well-known source of subtle breakage when split across separate single-line env vars. |

No changes needed to the existing `[build]` command in `netlify.toml`. Netlify's own dependency-install step (which runs before the configured build command) will pick up a root-level `package.json` automatically.

**Implementation note:** `firebase-admin` v14 (the version available when this was implemented) dropped the old namespaced `admin.firestore()` / `admin.credential.cert()` / `admin.apps` API entirely — there is no top-level `apps` property anymore, so that exact check silently produced a confusing `TypeError` instead of the intended "credentials not set" error. The function uses the modular subpath imports instead: `require('firebase-admin/app')` for `initializeApp`/`getApps`/`cert`, and `require('firebase-admin/firestore')` for `getFirestore`. If `firebase-admin` is upgraded later, re-check this surface again.

## 10. Implementation steps (status)

1. [x] Confirmed the §0 decision (cached ICS text written by the client).
2. [x] `AppState._refreshCachedIcs()` (`lib/state/app_state.dart`) recomputes ICS via `IcsCalendarService.generate()` whenever the feed is enabled, called from `_currentSavedState()` and `_applySavedState()` — implemented in the prior session (2026-06-18, "Cache generated ICS text in Firestore for the future feed endpoint").
3. [x] `cachedIcsText`/`cachedIcsUpdatedAtMillis` flow into Firestore automatically because `FirestoreSyncService.saveState()` already spreads `SavedState.toMap()` — no changes to `firestore_sync_service.dart` were needed (the original step 3 here, written before that prior session ran, turned out to be unnecessary).
4. [x] `_refreshCachedIcs()` clears `cachedIcsText`/`cachedIcsUpdatedAtMillis` to `null` whenever `feedEnabled` is false, so disabling always clears the cache (stronger than the "optional hygiene" originally sketched here).
5. [x] Added root-level `package.json` with `firebase-admin` as a dependency (`npm install` run; `package-lock.json` committed).
6. [x] Created `netlify/functions/calendar-feed.js` — GET-only, token lookup via `findCalendarByFeedToken`, status/error behavior from §6/§7, headers from §5. Pure decision logic (`extractToken`, `isFeedEnabled`, `buildFeedResponse`) is split out and covered by `netlify/tests/calendar-feed.test.js` (Node's built-in test runner, `npm test`).
7. [x] `netlify.toml` now has `[functions]\n  directory = "netlify/functions"`.
8. [x] `FIREBASE_SERVICE_ACCOUNT_JSON` is present in Netlify env vars and the deployed function can use it to read real Firestore calendar data.
9. [x] Deployed real-calendar endpoint verification passed: Firestore has a published calendar with cached ICS text, and the Netlify feed endpoint returns HTTP 200 with a valid VCALENDAR response.
10. [x] `lib/screens/settings_screen.dart`: `_FeedLinkPlaceholder` → `_FeedLinkDisplay`, now renders the real `/.netlify/functions/calendar-feed?token=<feedToken>` URL (via `Uri.base`, with a safe fallback when not running under http/https — e.g. `flutter test`) plus a working "Copy link" button.
11. [x] `docs/ROADMAP.md` and `docs/SESSION_LOG.md` updated for this implementation session.
12. [ ] Recommended follow-up: subscribe to the deployed feed URL in Apple Calendar, Google Calendar, or Outlook to confirm external calendar-app import behavior.

## 11. Explicitly out of scope (do not build these now)

- ETag/304 conditional responses.
- Rate limiting / abuse detection.
- Multiple calendars per user, calendar switcher, or per-calendar feed management UI.
- Any reimplementation of planner rules in JavaScript (Option B above).
- Google Calendar API / push-based sync — this is pull-only ICS.
- Feed analytics (view counts, last-fetched-by, etc.).
