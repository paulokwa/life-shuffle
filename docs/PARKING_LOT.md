# Parking Lot

This file protects good ideas without letting them hijack the current build.

If an idea is useful but not essential for the current milestone, park it here instead of forcing it into the MVP.

## How to use this file

When a new idea comes up, ask:

1. Does it support the current MVP?
2. Does it conflict with MASTER_PLAN.md?
3. Does it need a decision in DECISIONS.md?
4. Is it exciting but too early?

If it is exciting but too early, put it here.

## Parked feature ideas

### Outside Events & Local Event Discovery

- **Idea**: Provide a browsable, nicely organized feed of date-specific local events — concerts, markets, classes, festivals, community meetups, and similar — sourced from curated RSS/Atom feeds, Ticketmaster, Eventbrite, Bandsintown, and later AI-assisted search. The user can scroll suggested events, review cleaned-up details, and tap Add to place an event into the plan.
- **Why it is useful**: Helps users discover real things happening near them without having to invent ideas from scratch or manually create one-off events in the Activities page. This is especially useful for the app's "get unstuck and go outside" purpose.
- **Why it is parked**: This needs a real source-adapter architecture, a new suggestion-review model, source reliability decisions, and a clear non-AI-trusted-as-truth boundary before it is worth building. It should come after the core planner, the MVP 2 range/planning work, and basic AI assistance (suggesting from the existing activity bank) all work first.
- **Possible phase**: MVP 3 or later. Explicitly **not** MVP 1, and explicitly **not** part of the current MVP 2 range/planning slices (1-8c) — those slices are about generating from the existing Activity bank on a horizon, not about a second category of date-specific outside content.
- **Design notes for whoever picks this up**:
  - **Outside Events are a separate concept from Activities, not a variant of them.** `Activity` (`lib/models/activity.dart`) is a reusable template the rule-based `PlannerService`/`RangePlannerService` schedules repeatedly under rules like `maxPerWeek`, `allowedWeekdays`, and `mustIncludeInPlans`. An outside event is the opposite shape: a specific thing happening at a specific place on a specific date, usually only once. It should never be added to the activity bank or used as planner-generation material — keep the planner's job ("what should I generally do") and outside events' job ("what's actually happening near me on these dates") conceptually and structurally separate, even once both render on the same calendar.
  - **Primary user experience: browse sourced events, then tap Add.** The first useful version should feel like a clean Life Shuffle event-discovery shelf: pull candidate events from selected sources, normalize and tidy their information, display them in the app's design language, and let the user add one with a simple Add action. Manual event creation is not the main goal here because a user can already create their own custom Activity if they simply want to type an idea themselves.
  - **New intermediate record: `EventSuggestion`.** Every source — a curated RSS/Atom feed, Ticketmaster, Eventbrite, Bandsintown, or a future AI web/search source — should normalize into the same `EventSuggestion` shape (title, date/time or date range, location/venue, source name, source URL, optional price/category/tags, optional raw/source-specific payload, and a stable dedup key) before the user ever sees it. Nothing writes directly to the plan. This is the seam that lets every source behave the same way to the rest of the app and keeps AI involvement (see below) confined to *producing better `EventSuggestion`s*, never bypassing them.
  - **Source adapters, not one RSS feature.** Design a small `OutsideEventSourceAdapter`-style interface (conceptually: "given a date window and location/preferences, return `EventSuggestion`s") with one implementation per source: curated RSS/Atom, Ticketmaster, Eventbrite, Bandsintown, and later free-form search/AI discovery. RSS/Atom is *one adapter among several*, not the design's backbone — Ticketmaster/Eventbrite/Bandsintown should slot in without reshaping the suggestion model or the review UI, the same way `RangePlannerService` let week/twoWeek/month share one generator instead of three.
  - **First practical sourced slice: a small hardcoded curated RSS/Atom registry.** A short, vetted, hardcoded list of local/municipal/cultural RSS/Atom feeds (e.g. city events calendar, library, local venue) is a good first dynamic source because it needs no API key, has low maintenance, and many local/municipal/cultural sources already publish this way. **Do not** let users add arbitrary feed URLs in this version — unvetted feeds are a quality and trust risk (irrelevant content, broken feeds, spam). Start with sources the app maintainers chose and tested; user-supplied custom feeds, if ever added, are a distinct later decision with its own validation/safety story.
  - **Ticketmaster, Eventbrite, Bandsintown, and search are first-class future adapters.** These need API keys, rate limits, and ToS review — bigger lifts than a curated feed list — but should plug into the exact same `EventSuggestion`-producing adapter interface the RSS slice establishes, so adding them is "write an adapter," not "redesign the feature." Avoid Facebook Events as a source entirely: its event data access is gatekept and historically brittle/revoked, making it a poor foundation source.
  - **Manual entry/pasted links are optional later utilities, not the preferred first slice.** The product goal is not to make another way to type an event manually; the Activities page already covers self-created ideas well enough for now. A future pasted-link extractor could still be useful as a convenience tool, but it should not delay sourced discovery from RSS/API adapters.
  - **Accepted suggestions become fixed planned items, not movable Activity templates.** When the user approves an `EventSuggestion`, it should land on the calendar as a fixed-date/time item — conceptually the same "pinned to a specific date, lives outside the rule-based generator, survives regeneration" shape `ManualPlanItem` (`lib/models/manual_plan_item.dart`) already proves out for manually-added plan items. Whether an accepted outside event literally becomes a `ManualPlanItem` with extra optional source metadata (source name/URL/price for display), or a sibling model that shares that pattern, is an implementation-time decision — but either way it must never become an `Activity` and must never be eligible for `maxPerWeek`/`allowedWeekdays`-style rule scheduling, since a real event with a real start time isn't a recurring rule-driven suggestion.
  - **Review before add, always.** No suggestion — regardless of source — should reach the plan without an explicit user accept step. This is the same trust posture the rest of the app already takes with AI (MASTER_PLAN: "AI assistance can help suggest ideas, but the user stays in control") and should hold even harder here, since outside events involve real-world venues, prices, and timing the app cannot verify.
  - **Event cards should surface the practical details.** When available from the source, show date/time, venue, address/location, source, source link, price/free/unknown, category/tags, short description, and any useful notes such as ticket link or accessibility/family-friendly cues. If a field is missing or AI-inferred, label it calmly rather than pretending it is confirmed.
  - **No-match should feel calm, not broken.** If generation/preference matching finds no outside event fitting the user's date/time/radius/tag/budget preferences, show a plain, calm message (e.g. "No matching outside events found for this range") rather than an error or empty silence, and optionally offer near-matches (events that fail one soft preference, like being slightly outside the time window or radius) for manual add. This mirrors the planner's existing soft-failure messaging philosophy (MASTER_PLAN's "Generation safety and conflicts" section) rather than inventing a new failure tone.
  - **AI's role is organize/classify/summarize/dedupe/extract/rank — never source of truth.** Once multiple adapters are live, AI is well suited to: cleaning up messy feed/API entries, classifying entries into categories/tags, summarizing long descriptions, deduplicating the same event appearing from two sources, extracting structured fields (date/time/venue) from messy source text, and ranking/ordering candidate suggestions by fit to user preference. AI should never be the thing that decides an event is real or invents/guesses missing details without flagging them as uncertain — every AI-touched suggestion is still an `EventSuggestion` the user reviews, same as a directly sourced one.
  - **Preferences are a later layer, additive over the adapter/review pipeline.** Once the pipeline itself works, add location/radius, tags/categories, budget, allowed days/times, per-source on/off toggles, and a desired frequency (once a week / every 2 weeks / once a month) as filters/ranking inputs into suggestion generation — these shape *which* suggestions surface and how often, not the underlying adapter or review model, so they can be sequenced independently and skipped entirely until there's real source volume to filter.
  - **BYOK/API-key support is MVP 3+ and must not compromise secret handling.** Any source needing a per-user API key (most ticketing APIs eventually, and any user-supplied AI key) follows the same BYOK timing already parked for the AI assistant below: never commit a key to the repo, and never store a user's key insecurely (e.g. plaintext Firestore fields) — this needs the same secret-handling care as the BYOK AI assistant idea, not a separate weaker standard because it's "just an event source."
- **Related parked ideas**: see "BYOK AI assistant" below for the API-key/secret-handling standard this should reuse rather than redefine.

### BYOK AI assistant

- **Idea**: Let the user provide their own AI API key and use AI for suggestions.
- **Why it is useful**: Avoids the app owner paying for AI usage early.
- **Why it is parked**: The app should first prove value without AI.
- **Possible phase**: MVP 3

### Full profiles and login

- **Idea**: Add proper user accounts, saved profiles, preferences, and multi-user support.
- **Why it is useful**: Needed if Life Shuffle becomes public.
- **Why it is parked**: Auth/profile work can slow down early momentum. Start local first, then Firebase/anonymous auth later.
- **Possible phase**: MVP 2 or later

### Historical calendar browsing and richer trends

- **Idea**: Add read-only browsing across archived past weeks, two-week ranges, months, and eventually year-style views, plus richer long-term trends.
- **Why it is useful**: Users should be able to see what was planned, done, partly done, skipped, and left unchecked over time, not just the currently generated range. This would also support richer trends, streaks, category breakdowns, and long-term analytics.
- **Status update (2026-06-30)**: Slice 9 added the persisted `PlanHistoryEntry` foundation, Slice 10 uses it for existing Progress summaries, Slice 11 added archived-day details, Slice 12 added bounded previous-week and previous-month browsing with archive-only summaries, Slice 13 added ranked per-category stats, Slice 14 added current and longest completion streaks, Slice 15 added gentle archive-derived text patterns, and Slice 16 added one compact archived-status bar for Week/Month. **Still parked**: year/N-day views, custom range pickers, calendar-grid history, additional charts/dashboards, and deeper long-term analytics.
- **Why it is parked**: Day, week, and month list browsing now has honest summaries, category stats, streaks, bounded text insights, and one lightweight status chart. Calendar-grid history, arbitrary ranges, further charts, dashboards, and deeper analytics should wait for a concrete need and real archive-growth experience.
- **Possible phase**: Later MVP 2 analytics/history slice, now that the archive foundation exists to build on.

### Custom N-day planning horizon

- **Idea**: Let users choose an arbitrary number of days to generate (beyond the fixed Week/2 weeks/Month presets), capped at a product limit, with month-to-month navigation for long generated ranges.
- **Why it is useful**: Some users may want a horizon that doesn't match the three presets — e.g. exactly 10 days before a trip, or a full season.
- **Why it is parked**: The range/view UX correction slice (MVP 2 slice 3b) deliberately designed `RangeType.horizonDays(start)` and `RangePlannerService`'s single day-count-driven generator so a custom horizon can be added later without another rewrite, but building the actual custom-length UI (a day-count input, a cap, and multi-month navigation for the grid) is a separate, real chunk of work that isn't needed yet.
- **Possible phase**: Later MVP 2, after monthly print (slice 4) and export/output-detail polish (slice 5)
- **Design notes for whoever picks this up**:
  - Suggested initial cap: 90 days. Long enough to cover "plan my whole summer"-style requests without the month-grid needing true multi-month-page navigation on day one; 180/365 days can follow once that navigation exists.
  - Start at 90, not 365: the read-only month grid currently renders one continuous grid for the whole generated range (see `_MonthGrid` in `lib/screens/plan_screen.dart`). A 90-day grid is already ~13 calendar-week rows; a 365-day grid in one continuous scroll would be unwieldy and is the real blocker for jumping straight to a 1-year cap.
  - Month-to-month navigation: once a custom horizon exceeds roughly one visible month, the grid should page by calendar month (or by a fixed N-day window) rather than rendering every generated day in one scroll — add a page index similar to `AppState.selectedRangeWeekIndex`, but for months, not weeks.
  - Data/performance risk: `RangePlannerService` generates one `PlannerService` call per 7-day chunk, so a 365-day horizon means ~53 chunked calls per generation/regeneration. That's unlikely to be a real performance problem (each call is a small in-memory shuffle), but `AppState._buildPlan`'s locked-items map and the checkin/locked maps persisted in `SavedState` would all grow linearly with the horizon length — worth checking SharedPreferences/Firestore document size at the 365-day end before shipping it as a default rather than an opt-in.
  - Keep the existing `RangeType` enum (week/twoWeek/month) for the presets; a custom horizon is most naturally a distinct concept (an explicit day count) rather than a fourth enum value, since `RangeType.horizonDays(start)` is preset-shaped (it returns a fixed/derived day count per type) while a custom horizon is just a stored integer the user picked.

### Delete activity from the activity library

- **Idea**: A real "Delete activity" action (distinct from the existing enable/disable toggle) that removes an `Activity` from the activity library entirely, with strong confirmation, reachable from the Activities screen and/or the Plan screen's day sheet ("Edit activity" / "Remove from this plan" actions, MVP 2 slice 4b).
- **Why it is useful**: Today the only way to stop an activity from being used is `setActivityEnabled` (disable), which keeps it around forever. Some users will want to actually delete activities they created by mistake or no longer want, rather than accumulate disabled clutter.
- **Why it is parked**: No delete-the-source-activity flow exists anywhere in the app yet, with or without confirmation. Slice 4b deliberately did not add one to the Plan screen, since a casual implementation there risks a footgun: a user reaching for "remove this one occurrence" could end up deleting the whole activity (and every other occurrence of it) by mistake. A real delete needs: a decision on what happens to already-generated/locked/checked-in occurrences of that activity across the current range, a strong (type-to-confirm, like the existing calendar delete) confirmation, and a single safe implementation reused by both Activities and Plan screens — not two separate ad hoc delete paths.
- **Possible phase**: Later MVP 2 polish, after slice 5 (export/output-detail polish)

### Native App Store / Play Store release

- **Idea**: Package Life Shuffle as a real iOS/Android app.
- **Why it is useful**: Better mobile distribution and more app-like trust.
- **Why it is parked**: First prove the product with Flutter web/local builds.
- **Possible phase**: Later

### Social/community sharing

- **Idea**: Let people share activity lists, templates, or calendars with friends/community.
- **Why it is useful**: Could make the app more engaging.
- **Why it is parked**: Risks turning the app into a social platform too early.
- **Possible phase**: Later

### Paid subscriptions

- **Idea**: Add paid features, premium AI, or subscription plans.
- **Why it is useful**: Could support a public app later.
- **Why it is parked**: Monetization before value is noise.
- **Possible phase**: Much later

## Technical debt / future cleanup

- Keep documentation updated when major direction changes happen.
- Move experiments into branches rather than rewriting the main plan every time a new idea appears.
- Before adding Firebase, review whether local storage data needs migration support.

## Review rhythm

Review this file when finishing each milestone, not every time a cool idea appears.

The parking lot is a shelf, not a graveyard.
