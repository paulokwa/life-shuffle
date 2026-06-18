# Life Shuffle Roadmap

## Vision

Life Shuffle helps users create realistic shared activity calendars from things they already like, things they might like, and rules that make the plans livable.

The first version should help Kwame and Laura plan better weeks together, create more than one named calendar if needed, check in on what happened, publish plans to normal phone calendars, and print/export useful versions of the plan. Public-app thinking comes later.

## Current status

App is runnable. Core planner loop, Firebase auth, Google display name confirmation, first-calendar naming, Firestore sync, activity creation/editing, optional activity dimensions, difficulty-aware planning, plan generation with rules, planner soft-failure messages, lock/unlock, regeneration undo, check-ins, basic progress, local ICS/iCalendar feed-string generation, and private feed token metadata are all working. Settings shows account, calendar info, planning style, activity-default dimension toggles, Publishing controls for local feed metadata, and a plain-language Privacy/help section for sharing and future feed links. Starter activity library and plan style choice are live. The Today screen's check-in prompt opens a full quick catch-up view that lists every past unchecked activity grouped by day with explicit Done/Partly/Skipped buttons. The Plan screen now lets users tap a day card or day-strip date to open a day check-in sheet with Done/Partly/Skipped/Unchecked controls. Progress now includes past 7 days and past 30 days summaries with planned, done, partly, skipped, and unchecked counts, a Difficulty-only hard-activity summary when Difficulty is enabled, a compact Recent Rhythm section for streaks and 7-day comparison, and a Looking Ahead summary for upcoming planned items. A public read-only ICS feed endpoint now exists (`netlify/functions/calendar-feed.js`): Settings > Publishing shows the real subscribable link with a working copy button, and the function serves the calendar's cached ICS text by `feedToken`, gated to the same enabled/disabled/revoked behavior already in the app. It still needs a real `FIREBASE_SERVICE_ACCOUNT_JSON` Netlify env var and a live calendar-app subscription test before it's verified end-to-end against production.

Still to build for MVP 1: multiple calendars + switcher, planning-dimensions onboarding, shared-edit/sync conflict messages, one-by-one/week-review check-in views, print/export, remaining Settings controls (export/print), and verifying the public feed endpoint against a real deployed Netlify site.

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
- [ ] Support multiple named Life Shuffle calendars per user/member
- [x] Add onboarding/setup prompt to name the first calendar, with a sensible default
- [ ] Add optional sharing/member setup step
- [ ] Add calendar switcher or clear way to create/select calendars
- [ ] Create simple Kwame/Laura membership model per calendar
- [ ] Add calendar ownership, member leave, delete, and feed-revocation basics
- [x] Add structured Settings area
- [x] Add Settings > Account: display name and sign out
- [ ] Add Settings > Calendar: name, switcher, create calendar, members, roles, leave, delete (name/owner/members display only; current calendar name is persisted)
- [x] Add Settings > Planning: default plan style (Gentle/Balanced/Push me) — week start and time window still static
- [x] Add Settings > Activity defaults: dimension toggles and defaults
- [x] Add Settings > Publishing placeholder showing feed is not enabled yet but local ICS foundation exists
- [x] Add Settings > Publishing local metadata controls: feed enable/disable, no-endpoint copy/link placeholder, token preview, regenerate token, revoke token, feed explanation
- [ ] Add Settings > Publishing public feed controls: copy link and public endpoint-backed explanation
- [ ] Add Settings > Export/print: default output details and note/status/dimension visibility
- [x] Add Settings > Privacy/help: privacy explanation, feed explanation, help/about
- [ ] Add calendar-level plan settings: week start, earliest/latest time, default activity count
- [ ] Add planning-dimensions onboarding screen: Difficulty, Energy, Social
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
- [ ] Add basic shared-edit/sync conflict messages
- [ ] Add first-run hints for lock and shuffle in agenda/week view
- [x] Add skippable check-in prompt on app open/login when past unchecked items exist
- [x] Add quick catch-up check-in view
- [ ] Add one-by-one check-in review
- [ ] Add week review check-in view
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
- [ ] Add printable calendar view
- [ ] Add PDF export if practical
- [ ] Add simple text/share export if practical
- [ ] Add output detail toggles for print/export

### MVP 1 export/output detail options

Users should be able to choose whether exported/printed output includes:

- [ ] Activity title
- [ ] Date and time
- [ ] Duration
- [ ] Category
- [ ] Colour/icon
- [ ] Location
- [ ] Who it is for: Kwame, Laura, Both, or Either
- [ ] Enabled planning dimensions: difficulty, energy, and/or social level
- [ ] Check-in status
- [ ] Notes
- [ ] Locked status

Private/internal notes should be excluded by default.

### MVP 1 success test

MVP 1 is successful if Kwame and Laura can both sign in, complete a short setup flow with subtle non-distracting transitions, create/select a named shared calendar, navigate between Today/Plan/Activities/Progress/Settings, use structured settings, pick starter activities without a blank page, add/edit activities with enabled planning dimensions, generate a useful week, preserve locked items during regeneration, preview or undo regeneration, check in on past planned items without typing, view basic progress, publish a read-only subscribed calendar feed for that calendar, understand feed privacy, and print/export the plan with chosen details.

## MVP 2 — Polish and expansion

Goal: improve the shared experience after the core Version 1 works.

- [ ] Improve invite/member management if needed
- [ ] Add stronger polish around shared editing states
- [ ] Improve calendar feed controls if needed
- [ ] Add richer print/export templates if needed
- [ ] Expand day/month/year calendar views if needed
- [ ] Add richer analytics/charts if needed
- [ ] Add richer starter activity templates if needed
- [ ] Add notifications/reminders if needed

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
