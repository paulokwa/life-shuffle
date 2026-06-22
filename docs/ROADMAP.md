# Life Shuffle Roadmap

## Vision

Life Shuffle helps users create realistic shared activity calendars from things they already like, things they might like, and rules that make the plans livable.

The first version should help Kwame and Laura plan better weeks together, create more than one named calendar if needed, check in on what happened, publish plans to normal phone calendars, and print/export useful versions of the plan. Public-app thinking comes later.

## Current status

App is runnable. Core planner loop, Firebase auth, Google display name confirmation, first-calendar naming, Firestore sync, selected-calendar-safe save targeting, activity creation/editing, optional activity dimensions, difficulty-aware planning, plan generation with rules, planner soft-failure messages, lock/unlock, regeneration undo, check-ins, basic progress, local ICS/iCalendar feed-string generation, and private feed token metadata are all working. Settings shows account, calendar info, owner/member display, an owner-only Add member action, a Create calendar action, a member-only Leave calendar action, an owner-only Delete calendar action, a simple calendar switcher when multiple accessible calendars exist, planning style, activity-default dimension toggles, Publishing controls for local feed metadata, a simple Export / print text-copy action, and a plain-language Privacy/help section for sharing and future feed links. Additional named calendars can be created with generated IDs, selected immediately, and remembered locally; if a previously selected calendar is no longer accessible, sync safely falls back to an accessible shared calendar or the deterministic personal default without copying stale shared data. Non-owner members can leave a shared calendar without deleting it for other members; after leaving, the app reloads accessible calendars, selects another accessible calendar when available, or creates/uses the deterministic personal default with blank starter state. Owners can hard-delete the current calendar after typing its exact name; after delete, the app selects another accessible calendar or creates/uses a blank deterministic personal default, and the old feed URL becomes unavailable because the calendar document no longer exists. Starter activity library and plan style choice are live. The Today screen's check-in prompt opens a full quick catch-up view that lists every past unchecked activity grouped by day with explicit Done/Partly/Skipped buttons. The Plan screen now lets users tap a day card or day-strip date to open a day check-in sheet with Done/Partly/Skipped/Unchecked controls. Progress now includes past 7 days and past 30 days summaries with planned, done, partly, skipped, and unchecked counts, a Difficulty-only hard-activity summary when Difficulty is enabled, a compact Recent Rhythm section for streaks and 7-day comparison, and a Looking Ahead summary for upcoming planned items. A public read-only ICS feed endpoint now exists (`netlify/functions/calendar-feed.js`): Settings > Publishing shows the real subscribable link with a working copy button, and the function serves the calendar's cached ICS text by `feedToken`, gated to the same enabled/disabled/revoked behavior already in the app. Production endpoint verification passed against real Firestore data, and Kwame manually subscribed to the public feed in Google Calendar: the calendar appeared under Google Calendar's Other calendars list as "Kwame and Laura," and planned Life Shuffle activities rendered on the expected dates/times. For V1 that Google Calendar smoke test is considered sufficient; Apple Calendar and Outlook were not tested, to move faster. Settings > Export / print now also has an `Open print view` action that opens a read-only, print-friendly weekly view (calendar title, week range, per-day activities with time/duration/category, check-in status, and lock icon) and a `Print` button that triggers the browser print dialog on web. Settings > Export / print also has output detail toggles (Time, Duration, Category, Check-in status, Locked status, and Enabled planning dimensions when at least one of Difficulty/Energy/Social is on) that apply to both Copy text and Open print view; Activity title and the day/date always show and have no toggle. Sync/save/load problems and shared-edit staleness now show calm, plain-language messages instead of raw Firebase text: Settings shows a sync diagnostics card with a short title, body, and a Retry button for load/save/permission/profile failures, and the Plan screen shows a dismissible "Updated elsewhere" notice when a newer remote version was just applied during sync. MVP 2 range planning now separates the generated planning horizon from the Plan screen's view: Week/2 weeks/Month are today-anchored future-facing horizons (7, 14, and ~30/31 days starting today, never literal calendar boundaries), and switching the Week/2 weeks/Month selector only changes the view — it never regenerates or discards the existing generated range. If the selected view needs more days than are currently generated, the Plan screen shows a "Generate" CTA instead of silently regenerating; the read-only month grid still renders as a calendar-style grid (it may span calendar weeks for layout and can itself cross a calendar-month boundary) with blank/dimmed cells before the generated start date and after the generated end date. Done/Partly/Skipped check-in controls are disabled for future dates (today and past dates remain check-in-able) in both the day check-in sheet and week review. The day check-in sheet's per-item card now also has "Edit activity" (opens the same activity edit form used on the Activities screen, with the source activity preloaded) and "Remove from this plan" (removes only that occurrence/date from the generated plan, with a plain confirmation; the source activity stays in the activity library and enabled for future regeneration) actions, available for past, today, and future dates alike — only the Done/Partly/Skipped/Unchecked check-in controls stay date-gated. `Open print view` now also renders a print-friendly Monday-start calendar grid over the full generated range when the Plan screen's view is Month (week/2-week print is unchanged); if Month view has no generated range yet, print preview shows a message to generate it first instead of regenerating on its own. Copy text (the Plan screen's `Export` action and Settings > Export/print's `Copy text` action) now exports based on the current Week/2 weeks/Month view instead of always copying the visible week: Week is unchanged, 2 weeks copies the full generated 14-day range once one exists (falling back to the visible week otherwise, same as print), and Month copies the full generated month/range grouped by date, or shows a "generate first" message instead of silently generating one or exporting a stale range. Settings > Export/print's heading and summary now state in plain language what the current view mode will copy/print, and print preview shows a short note in 2-week view clarifying it still only prints the visible week. The on-screen and print Month/range grids now show a compact month-name label on the first generated date and on the 1st of any later month inside the range, so a range spanning two calendar months (e.g. Jun 22 - Jul 21) stays readable at a glance; day numbers stay visible either way.

Still to build for MVP 1: PDF export.

## MVP 1 — Shared mobile-first planner with onboarding/publishing/export/check-ins

Goal: prove the core experience works for Kwame and Laura with a short setup flow, subtle onboarding transitions, starter activities, multiple named calendars, shared editing, structured settings, clear navigation, check-ins, basic progress tracking, calendar publishing, practical print/export, optional planning dimensions, and safety UX, while still avoiding AI and public-app complexity.

### Build tasks

- [x] Create Flutter project structure
- [x] Add mobile-first app shell
- [ ] Add responsive layout system: phone first, wider screens adapt
- [x] Add bottom navigation on mobile: Today, Plan, Activities, Progress, Settings
- [ ] Add sidebar navigation on tablet/desktop using the same sections
- [x] Add consistent top/header area with selected calendar name and calendar switcher
- [x] Keep Export, Publish, Check-in, Calendar switcher, and AI out of the main bottom nav
- [ ] Add one clear primary action per main screen
- [x] Add Firebase project setup
- [x] Add Google sign-in
- [x] Add basic auth gate
- [x] Add short onboarding/setup flow
- [x] Add welcome screen with brief app explanation
- [ ] Add subtle onboarding Next transitions: quick fade or small slide
- [ ] Avoid dramatic, bouncy, spinning, or distracting onboarding animation
- [ ] Respect reduced-motion accessibility settings
- [x] Confirm/edit display name after Google sign-in
- [x] Create calendar data model with title/name
- [x] Support multiple named Life Shuffle calendars per user/member
- [x] Add onboarding/setup prompt to name the first calendar, with a sensible default
- [ ] Add optional sharing/member setup step
- [x] Add calendar switcher or clear way to create/select calendars
- [x] Create simple Kwame/Laura membership model per calendar
- [x] Add calendar ownership, member leave, delete, and feed-revocation basics
- [x] Add structured Settings area
- [x] Add Settings > Account: display name and sign out
- [x] Add Settings > Calendar: name, switcher, create calendar, members, roles, leave, delete
- [x] Add Settings > Planning: default plan style (Gentle/Balanced/Push me) — week start and time window still static
- [x] Add Settings > Activity defaults: dimension toggles and defaults
- [x] Add Settings > Publishing placeholder showing feed is not enabled yet but local ICS foundation exists
- [x] Add Settings > Publishing local metadata controls: feed enable/disable, no-endpoint copy/link placeholder, token preview, regenerate token, revoke token, feed explanation
- [x] Add Settings > Publishing public feed controls: copy link and public endpoint-backed explanation
- [x] Add Settings > Export/print text export section with Copy text
- [ ] Add Settings > Export/print: default output details and note/status/dimension visibility (status/dimension visibility toggles done; notes are not implemented yet, so no notes toggle)
- [x] Add Settings > Privacy/help: privacy explanation, feed explanation, help/about
- [ ] Add calendar-level plan settings: week start, earliest/latest time, default activity count
- [x] Add planning-dimensions onboarding screen: Difficulty, Energy, Social
- [x] Create activity model scoped to a calendar
- [x] Create activity rule model scoped to a calendar
- [x] Create planned item model scoped to a calendar
- [x] Add check-in status model: skipped, partly done, done, unchecked
- [x] Add optional planning dimension settings
- [x] Add default values for enabled planning dimensions
- [x] Add built-in starter activity library
- [x] Add starter categories: At home, Outside, Health/movement, Social, Creative, Rest, Food, Chores/life admin, Couple time, Low-energy ideas
- [x] Add starter activity picker with limited first view and `See more` pattern
- [x] Add ability to create custom activities from onboarding or after onboarding
- [x] Add sensible default metadata/rules for starter activities
- [ ] Add option to use sensible default rules or review rules now
- [x] Add first plan style choice: Gentle, Balanced, or Push me a little
- [x] Build one-activity-at-a-time creation flow
- [x] Add category, colour, and icon support
- [x] Add activity enabled/disabled state
- [x] Add optional difficulty/resistance field, 1 to 5
- [x] Add optional energy level field: Low, Medium, High
- [x] Add optional social level field: Solo, Together, Group, Either
- [ ] Hide disabled planning dimensions from forms, cards, planner rules, and export options (forms/cards done)
- [x] Add allowed day/time rules
- [x] Add max-per-week rule
- [x] Add no-consecutive-days rule
- [x] Add difficulty-aware planner rules if difficulty is enabled
- [x] Build 7-day agenda generator
- [x] Build agenda-first calendar view
- [x] Add Today/Home screen or clear landing view
- [x] Add helpful empty states: no activities, no plan (no calendars, no check-ins, no stats, offline still to do)
- [x] Add lock/unlock planned item behaviour
- [x] Add regeneration preview or undo for last regeneration
- [x] Add regenerate-unlocked-only behaviour
- [x] Add clear generation conflict/failure messages
- [x] Add basic shared-edit/sync conflict messages
- [ ] Add first-run hints for lock and shuffle in agenda/week view
- [x] Add skippable check-in prompt on app open/login when past unchecked items exist
- [x] Add quick catch-up check-in view
- [x] Add one-by-one check-in review
- [x] Add week review check-in view
- [x] Add day sheet check-in from agenda/calendar
- [ ] Add optional note action for check-ins, hidden by default
- [x] Add basic progress/stats page scoped to selected calendar
- [x] Add past 7 days and past 30 days summaries
- [x] Add planned vs done/partly/skipped counts
- [x] Add category breakdown
- [x] Add difficulty summary if difficulty is enabled
- [x] Add simple streaks or trends
- [x] Add looking-ahead summary for upcoming planned items
- [x] Add plain-language privacy/feed explanation
- [x] Save calendars, activities, generated plans, and check-in statuses in Firestore
- [x] Add Firestore security rules for shared calendar access
- [x] Generate local read-only ICS/iCalendar feed string for the selected calendar
- [x] Add private/unguessable feed token metadata per selected calendar
- [x] Add ability to disable publishing metadata without deleting the calendar
- [x] Add ability to revoke/regenerate calendar feed token
- [x] Add private/unguessable calendar feed URL per published calendar
- [x] Add public endpoint support for revoked/regenerated feed URLs
- [x] Add printable calendar view
- [ ] Add PDF export if practical
- [x] Add simple text/share export if practical
- [x] Add output detail toggles for print/export

### MVP 1 export/output detail options

Users should be able to choose whether exported/printed output includes:

- [ ] Activity title (always shown, no toggle)
- [ ] Date and time (date always shown, no toggle; time has a toggle)
- [x] Duration
- [x] Category
- [ ] Colour/icon
- [ ] Location
- [ ] Who it is for: Kwame, Laura, Both, or Either
- [x] Enabled planning dimensions: difficulty, energy, and/or social level
- [x] Check-in status
- [ ] Notes
- [x] Locked status

Private/internal notes should be excluded by default.

### MVP 1 success test

MVP 1 is successful if Kwame and Laura can both sign in, complete a short setup flow with subtle non-distracting transitions, create/select a named shared calendar, navigate between Today/Plan/Activities/Progress/Settings, use structured settings, pick starter activities without a blank page, add/edit activities with enabled planning dimensions, generate a useful week, preserve locked items during regeneration, preview or undo regeneration, check in on past planned items without typing, view basic progress, publish a read-only subscribed calendar feed for that calendar, understand feed privacy, and print/export the plan with chosen details.

## MVP 2 — Polish and expansion

Goal: improve the shared experience after the core Version 1 works.

- [ ] Improve invite/member management if needed
- [ ] Add stronger polish around shared editing states
- [ ] Improve calendar feed controls if needed
- [ ] Add richer print/export templates if needed
- [ ] Expand day/month/year calendar views if needed (month generation + read-only month grid slice done; day/year views still open)
- [ ] Add richer analytics/charts if needed
- [ ] Add richer starter activity templates if needed
- [ ] Add notifications/reminders if needed

### MVP 2 calendar view expansion notes

Do not pull monthly/two-week/day/year views into MVP 1 unless there is an explicit direction change. For now, keep MVP 1 focused on the useful shared weekly planner and weekly print/export.

When MVP 2 calendar-view work begins, treat month view as a planning feature, not just a visual/print template. A monthly grid is only valuable if the app can generate, save, and reload a whole month of activities.

Preferred approach for monthly planning:

- Build a dedicated `MonthPlannerService` or equivalent month-planning layer that can reuse the weekly planner internally, rather than calling the weekly generator directly from the UI.
- Expose a clean month-plan model to the front end so the user sees a normal month calendar, not week-generation plumbing.
- Keep generated months stable across refreshes, shared-account reloads, and printing; do not regenerate a different month accidentally on every view open.
- Preserve locks and check-ins for the correct dates across the whole generated month.
- Decide how rules behave across week boundaries before implementation. In particular, no-consecutive-days should probably apply across Sunday/Monday boundaries because users experience the month as continuous days, not isolated weeks.
- Keep browser print / Save as PDF as the first PDF path. Native app-generated PDF export is not required unless V2 later needs one-tap PDF download/share, exact page breaks, or custom PDF templates.

Suggested narrow first slice for MVP 2:

- [x] Read-only generated month view for the selected calendar.
- [x] Proper 7-column calendar grid.
- [x] Activity titles inside date cells.
- [x] Browser print / Save as PDF support now also covers Month/range view (slice 4); week/2-week print is unchanged.
- No drag/drop, no cell editing, no recurring-events system, no native PDF package, and no full Google/Outlook-style calendar clone in the first slice.

### MVP 2 range foundation progress

- [x] Slice 1 — invisible range/model foundation: `RangeType` (week/twoWeek/month), `GeneratedPlanRange`, and `RangePlannerService` (week-only today, reuses the existing weekly `PlannerService` internally rather than duplicating scheduling logic). Added a persisted `rangeType` field defaulting to week. Migrated check-in/lock overlays from activity-id keys to occurrence keys (`yyyy-MM-dd:activityId`) with backward-compatible legacy fallback, so the same recurring activity can have independent check-in/lock state on different dates once longer ranges exist. No visible change yet: every calendar still only ever generates and displays one week, with the same UI, print, and ICS feed as before.
- [x] Slice 2 — real `RangeType.twoWeek` generation (two Monday-aligned 7-day chunks stitched into 14 days, each with its own max-per-week cap) plus a simple Plan-screen "1 week / 2 weeks" control and "Week 1 / Week 2" navigation that switches the visible week without regenerating. Extended `PlannerService`'s existing `scheduledContext` parameter (rather than adding a new one) so no-consecutive-days and difficulty spacing carry across the Sunday-to-Monday week-chunk boundary. Check-in/lock persistence now covers the whole generated range so locks/check-ins on the non-visible week survive a save; Progress, Today's past-unchecked detection, print/export, and the ICS feed intentionally still only reflect the visible week for now. Month remains unimplemented (`RangePlannerService` throws, `AppState.setRangeType` silently ignores it).
- [x] Slice 3 — real `RangeType.month` generation: generalizes slice 2's Monday-aligned weekly chunking across however many weeks a calendar month spans, carries the previous chunk's final day as boundary context so no-consecutive-days/difficulty spacing cross every week boundary in the month (not just one), resets max-per-week per chunk for free since each chunk is its own `PlannerService` call, then clips the stitched days down to the literal in-month dates. The Plan screen adds a "Month" option to the range selector and a read-only Monday-start 7-column grid (blank/dimmed out-of-month cells, day numbers, up to 2 activity labels, `+X more`); tapping a day cell opens the existing day check-in sheet. Picking Month only marks the choice pending (`AppState.hasPendingRangeTypeChange`) — generating a whole month stays behind the existing Regenerate action rather than firing on every selector tap, unlike week/2-week which still regenerate immediately on selection. `AppState.weekPlan` keeps returning a visible/current 7-day slice (the Monday-aligned week containing today) for Today/Progress/print/ICS while `AppState.generatedRange` exposes the full range. No monthly print, native PDF, drag/drop, or editable month cells.
- [x] Slice 3b — range/view UX correction, before monthly print: manual testing of slice 3 surfaced three problems — switching the selector away from Month and back required regenerating again, the selector behaved like a destructive action instead of a harmless view switch, and literal-calendar-month generation pulled in many past days once "today" was late in the month. Fixed by separating the generated planning horizon (`AppState.rangeType`/`generatedRange`, what was actually built, with a persisted `rangeStart` so reload reconstructs the same range deterministically instead of re-anchoring to a new "today") from the Plan screen's view (`AppState.viewMode`, how it's currently displayed). `setViewMode` only ever changes the view and never regenerates or discards `generatedRange`; `generateRange(type)` is the one deliberate action that builds a fresh horizon. `RangeType.horizonDays(start)` and a single day-count-driven `RangePlannerService._generateHorizon` replaced the separate week/twoWeek/month generation paths, so week/2-week/month are now just 7/14/~30-31 future-facing days starting today (never a literal calendar week/month) — this also makes the model ready for a future custom N-day horizon without another rewrite (see Parking Lot). The month grid's in-range/out-of-range cell math was fixed to use the generated range's actual start/end dates rather than "same calendar month as the first day," since a ~30-day horizon routinely spans two calendar months. Done/Partly/Skipped/Unchecked check-in controls are now disabled (with a "Check in after this day." notice) for any date after today, in both the day check-in sheet and week review; today and past dates remain check-in-able.
- [x] Slice 4 — monthly print grid: `print_preview_screen.dart`'s `Open print view` now renders a print-friendly Monday-start 7-column grid (`Table`/`TableRow`, not `GridView`, so row height grows with however many activities a day has) over `AppState.generatedRange` when `viewMode` is `RangeType.month`, with the same blank/dimmed out-of-range cell math as the on-screen month grid (so a range spanning two calendar months doesn't mis-dim valid next-month days). Adds a calendar title, a "Week view"/"2-week view"/"Month view" label, and the generated range label (reusing `TextWeekExportService.weekRangeLabel`, which already handles cross-month spans). If Month view has no sufficient generated range yet, print preview shows a message to go generate it first and never generates on its own. Week print is unchanged; 2-week print still reuses the existing visible-week print path. Output detail toggles (time/duration/category/check-in/locked/dimensions) apply per activity inside grid cells the same as the weekly list. Native PDF, history/archive, custom-horizon UI, year/day views, drag/drop, and editable month cells are still out of scope.
- [x] Slice 4b — Plan item actions (edit/remove): manual testing found that tapping a planned item only opened check-in options, with no way to edit or remove the underlying activity from the Plan screen — planned items felt like dead check-in entries. Fixed before starting slice 5's export polish. The day check-in sheet's per-activity card now has "Edit activity" (reuses the existing `_ActivityFormSheet` from `activities_screen.dart`, now exposed as the public `showActivityFormSheet`, rather than duplicating the form; saving mutates the same `Activity` instance the planned occurrence already points to, so the day sheet reflects the edit immediately) and "Remove from this plan" (`AppState.removeFromPlan(day, activity)` removes just that occurrence from `_generatedDays` and records it in a new occurrence-keyed `removedMap`, parallel to the existing `checkinMap`/`lockedMap`, persisted via `PersistenceService`/Firestore `SavedState` so the removal survives reload; the source `Activity` is never touched, so it stays in the activity library and enabled for future regeneration). Both actions are available regardless of the future-check-in guard. `removedMap` is intentionally cleared on `regenerate()`/`generateRange()`/`setPlanStyle()` — the same as every other non-locked customization — so a stale removal can't silently re-delete an occurrence the user already got back through one of those actions. Direct "Delete activity" from the Plan screen was deliberately not added: no safe, confirmed delete-the-source-activity flow exists anywhere in the app yet (only enable/disable), so adding one here was out of scope for this slice; see Parking Lot.
- [x] Slice 5 — export/output-detail polish across week/2-week/month views, plus month labels in calendar grids: `AppState` gained a single `exportDays` getter that the Plan screen's `Export` action and Settings > Export/print's `Copy text` action both now call instead of always reading `weekPlan`, so what gets copied matches the current `viewMode` rather than always being the visible 7-day window. Week is unchanged. Two weeks copies the full generated 14-day range when `rangeType` is itself `twoWeek` (not just when `hasSufficientRangeForView` is true, since a generated month also satisfies that length check) - otherwise it falls back to the visible week, same as the on-screen view; print stays visible-week-only, now with an on-screen-only note in print preview clarifying Copy text covers more than print does in this view. Month copies the full generated month/range grouped by date (`TextWeekExportService.generate`'s existing per-day grouping unchanged, just fed the full range instead of a 7-day slice) and shows a "generate first" message instead of silently generating or exporting a stale range when no sufficient month range exists yet, mirroring print preview's existing pending-state guard. `TextWeekExportService.generate` gained an optional `rangeType` parameter (default `RangeType.week`, so every prior call site/test is unaffected) that swaps the header word (`week`/`2 weeks`/`month`) and the no-activities message instead of hardcoding "week" regardless of what was actually exported. Settings > Export/print's heading and one-line summary are now driven by `AppState.viewMode` so they always describe what Copy text/print will actually produce. The on-screen `_MonthGrid`/`_MonthDayCell` and print `_PrintMonthGrid`/`_PrintMonthDayCell` now show a small month-abbreviation label next to the day number on the first generated/visible date (even when it isn't the 1st) and on the 1st of any later month inside the range, so a range spanning two calendar months (e.g. Jun 22 - Jul 21) reads clearly at a glance; day numbers are unchanged, the label is purely additive. Native PDF, history/archive persistence, a full custom-horizon UI, year/day views, drag/drop, and editable month cells remain out of scope.

## MVP 3 — AI assistant

Goal: help users who do not know what to add or how to plan.

- [ ] Add user preference/profile prompts
- [ ] Add BYOK AI configuration
- [ ] Add AI activity suggestions
- [ ] Add tick/no-tick suggestion review
- [ ] Add one-question-at-a-time AI mode
- [ ] Add all-suggestions view
- [ ] Add AI weekly plan suggestions that respect rules and locked items

## Later

- [ ] Local community event discovery
- [ ] Public user accounts
- [ ] Multi-profile support
- [ ] Native iOS/Android packaging
- [ ] Activity templates
- [ ] Shared activity lists
- [ ] Public launch polish
- [ ] Monetization exploration

## Current build rule

When in doubt, build the smallest useful shared planner first.

No feature should be added to MVP 1 unless it helps answer this question:

Can Kwame and Laura sign in, complete a short setup, create/select a named shared calendar, navigate clearly, manage settings clearly, generate a useful rule-respecting week, safely adjust that plan, check in without friction, see basic progress, publish it to normal calendar apps, and print/export the plan with useful details?
