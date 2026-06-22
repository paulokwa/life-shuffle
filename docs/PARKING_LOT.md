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

### AI local community event discovery

- **Idea**: Let AI pull in local community events and suggest them to the user.
- **Why it is useful**: Helps users discover things outside their existing activity list.
- **Why it is parked**: This needs reliable data sources, search/API decisions, and privacy thinking. It should come after the core planner works.
- **Possible phase**: MVP 3 or later

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

### Historical calendar archive and trends

- **Idea**: Preserve dated plan and check-in history from calendar creation so users can go back through past weeks, two-week ranges, months, and eventually year-style views.
- **Why it is useful**: Users should be able to see what was planned, done, partly done, skipped, and left unchecked over time, not just the currently generated range. This would also support richer trends, streaks, category breakdowns, and long-term analytics.
- **Why it is parked**: The current MVP 2 calendar work is focused on generating/viewing/printing current ranges. A true history archive likely needs a deliberate persistence/schema design so regenerated plans do not overwrite historical truth.
- **Possible phase**: Later MVP 2 analytics/history slice, after the current month generation and print-grid work

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
