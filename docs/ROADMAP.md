# Life Shuffle Roadmap

## Vision

Life Shuffle helps users create a realistic shared activity calendar from things they already like, things they might like, and rules that make the plan livable.

The first version should help Kwame and Laura plan better weeks together, publish that plan to normal phone calendars, and print/export useful versions of the plan. Public-app thinking comes later.

## Current status

- Repository created
- Flutter chosen as the main technology direction
- Planning docs created
- Firebase + Google sign-in moved into MVP 1 for shared editing
- Calendar publishing and print/export moved into MVP 1
- No app code yet

## MVP 1 — Shared mobile-first planner with publishing/export

Goal: prove the core experience works for Kwame and Laura with shared editing, calendar publishing, and practical print/export, while still avoiding AI and public-app complexity.

### Build tasks

- [ ] Create Flutter project structure
- [ ] Add mobile-first app shell
- [ ] Add bottom navigation
- [ ] Add Firebase project setup
- [ ] Add Google sign-in
- [ ] Add basic auth gate
- [ ] Create shared calendar data model
- [ ] Create simple Kwame/Laura membership model
- [ ] Create activity model
- [ ] Create activity rule model
- [ ] Create planned item model
- [ ] Build one-activity-at-a-time creation flow
- [ ] Add category, colour, and icon support
- [ ] Add allowed day/time rules
- [ ] Add max-per-week rule
- [ ] Add no-consecutive-days rule
- [ ] Build 7-day agenda generator
- [ ] Build agenda-first calendar view
- [ ] Add lock/unlock planned item behaviour
- [ ] Add regenerate-unlocked-only behaviour
- [ ] Save activities and generated plans in Firestore
- [ ] Add Firestore security rules for shared calendar access
- [ ] Generate read-only ICS/iCalendar feed for external calendar apps
- [ ] Add private/unguessable calendar feed URL
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
- [ ] Notes
- [ ] Locked status

Private/internal notes should be excluded by default.

### MVP 1 success test

MVP 1 is successful if Kwame and Laura can both sign in, access the same shared calendar, add/edit activities, generate a useful week, preserve locked items during regeneration, publish a read-only subscribed calendar feed, and print/export the plan with chosen details.

## MVP 2 — Polish and expansion

Goal: improve the shared experience after the core Version 1 works.

- [ ] Improve invite/member management if needed
- [ ] Improve conflict/loading/error states for shared editing
- [ ] Improve calendar feed controls if needed
- [ ] Add richer print/export templates if needed
- [ ] Expand day/month/year calendar views if needed

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

Can Kwame and Laura sign in, share one calendar, generate a useful rule-respecting week, publish it to normal calendar apps, and print/export the plan with useful details?