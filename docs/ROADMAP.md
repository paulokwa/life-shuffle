# Life Shuffle Roadmap

## Vision

Life Shuffle helps users create realistic shared activity calendars from things they already like, things they might like, and rules that make the plans livable.

The first version should help Kwame and Laura plan better weeks together, create more than one named calendar if needed, check in on what happened, publish plans to normal phone calendars, and print/export useful versions of the plan. Public-app thinking comes later.

## Current status

- Repository created
- Flutter chosen as the main technology direction
- Planning docs created
- Firebase + Google sign-in moved into MVP 1 for shared editing
- Calendar publishing and print/export moved into MVP 1
- Optional planning dimensions added to MVP 1: difficulty, energy, and social level
- Check-ins and basic progress tracking added to MVP 1
- Multiple named calendars added to MVP 1
- Onboarding and starter activity library added to MVP 1
- V1 foundations and safety UX added: Today/Home, empty states, regeneration preview/undo, activity enable/disable, conflict messages, calendar-level plan settings, privacy/feed explanation, and calendar lifecycle basics
- Structured Settings area added to MVP 1
- Navigation and responsive layout direction added to MVP 1
- Subtle onboarding transitions added to MVP 1
- No app code yet

## MVP 1 — Shared mobile-first planner with onboarding/publishing/export/check-ins

Goal: prove the core experience works for Kwame and Laura with a short setup flow, subtle onboarding transitions, starter activities, multiple named calendars, shared editing, structured settings, clear navigation, check-ins, basic progress tracking, calendar publishing, practical print/export, optional planning dimensions, and safety UX, while still avoiding AI and public-app complexity.

### Build tasks

- [ ] Create Flutter project structure
- [ ] Add mobile-first app shell
- [ ] Add responsive layout system: phone first, wider screens adapt
- [ ] Add bottom navigation on mobile: Today, Plan, Activities, Progress, Settings
- [ ] Add sidebar navigation on tablet/desktop using the same sections
- [ ] Add consistent top/header area with selected calendar name and calendar switcher
- [ ] Keep Export, Publish, Check-in, Calendar switcher, and AI out of the main bottom nav
- [ ] Add one clear primary action per main screen
- [ ] Add Firebase project setup
- [ ] Add Google sign-in
- [ ] Add basic auth gate
- [ ] Add short onboarding/setup flow
- [ ] Add welcome screen with brief app explanation
- [ ] Add subtle onboarding Next transitions: quick fade or small slide
- [ ] Avoid dramatic, bouncy, spinning, or distracting onboarding animation
- [ ] Respect reduced-motion accessibility settings
- [ ] Confirm/edit display name after Google sign-in
- [ ] Create calendar data model with title/name
- [ ] Support multiple named Life Shuffle calendars per user/member
- [ ] Add onboarding/setup prompt to name the first calendar, with a sensible default
- [ ] Add optional sharing/member setup step
- [ ] Add calendar switcher or clear way to create/select calendars
- [ ] Create simple Kwame/Laura membership model per calendar
- [ ] Add calendar ownership, member leave, delete, and feed-revocation basics
- [ ] Add structured Settings area
- [ ] Add Settings > Account: display name and sign out
- [ ] Add Settings > Calendar: name, switcher, create calendar, members, roles, leave, delete
- [ ] Add Settings > Planning: week start, earliest/latest time, default plan style, default activity count
- [ ] Add Settings > Activity defaults: dimension toggles and defaults
- [ ] Add Settings > Publishing: feed enable/disable, copy link, revoke/regenerate link, feed explanation
- [ ] Add Settings > Export/print: default output details and note/status/dimension visibility
- [ ] Add Settings > Privacy/help: privacy explanation, feed explanation, help/about
- [ ] Add calendar-level plan settings: week start, earliest/latest time, default plan style, default activity count
- [ ] Add planning-dimensions onboarding screen: Difficulty, Energy, Social
- [ ] Create activity model scoped to a calendar
- [ ] Create activity rule model scoped to a calendar
- [ ] Create planned item model scoped to a calendar
- [ ] Add check-in status model: skipped, partly done, done, unchecked
- [ ] Add optional planning dimension settings
- [ ] Add default values for enabled planning dimensions
- [ ] Add built-in starter activity library
- [ ] Add starter categories: At home, Outside, Health/movement, Social, Creative, Rest, Food, Chores/life admin, Couple time, Low-energy ideas
- [ ] Add starter activity picker with limited first view and `See more` pattern
- [ ] Add ability to create custom activities from onboarding or after onboarding
- [ ] Add sensible default metadata/rules for starter activities
- [ ] Add option to use sensible default rules or review rules now
- [ ] Add first plan style choice: Gentle, Balanced, or Push me a little
- [ ] Build one-activity-at-a-time creation flow
- [ ] Add category, colour, and icon support
- [ ] Add activity enabled/disabled state
- [ ] Add optional difficulty/resistance field, 1 to 5
- [ ] Add optional energy level field: Low, Medium, High
- [ ] Add optional social level field: Solo, Together, Group, Either
- [ ] Hide disabled planning dimensions from forms, cards, planner rules, and export options
- [ ] Add allowed day/time rules
- [ ] Add max-per-week rule
- [ ] Add no-consecutive-days rule
- [ ] Add difficulty-aware planner rules if difficulty is enabled
- [ ] Build 7-day agenda generator
- [ ] Build agenda-first calendar view
- [ ] Add Today/Home screen or clear landing view
- [ ] Add helpful empty states: no calendars, no activities, no plan, no check-ins, no stats, offline/sync problem
- [ ] Add lock/unlock planned item behaviour
- [ ] Add regeneration preview or undo for last regeneration
- [ ] Add regenerate-unlocked-only behaviour
- [ ] Add clear generation conflict/failure messages
- [ ] Add basic shared-edit/sync conflict messages
- [ ] Add first-run hints for lock and shuffle in agenda/week view
- [ ] Add skippable check-in prompt on app open/login when past unchecked items exist
- [ ] Add quick catch-up check-in view
- [ ] Add one-by-one check-in review
- [ ] Add week review check-in view
- [ ] Add day sheet check-in from agenda/calendar
- [ ] Add optional note action for check-ins, hidden by default
- [ ] Add basic progress/stats page scoped to selected calendar
- [ ] Add past 7 days and past 30 days summaries
- [ ] Add planned vs done/partly/skipped counts
- [ ] Add category breakdown
- [ ] Add difficulty summary if difficulty is enabled
- [ ] Add simple streaks or trends
- [ ] Add looking-ahead summary for upcoming planned items
- [ ] Add plain-language privacy/feed explanation
- [ ] Save calendars, activities, generated plans, and check-in statuses in Firestore
- [ ] Add Firestore security rules for shared calendar access
- [ ] Generate read-only ICS/iCalendar feed for each published calendar
- [ ] Add private/unguessable calendar feed URL per published calendar
- [ ] Add ability to revoke/regenerate calendar feed URL
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