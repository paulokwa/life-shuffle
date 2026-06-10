# Life Shuffle Roadmap

## Vision

Life Shuffle helps users create a realistic shared activity calendar from things they already like, things they might like, and rules that make the plan livable.

The first version should help Kwame and Laura plan better weeks together. Public-app thinking comes later.

## Current status

- Repository created
- Flutter chosen as the main technology direction
- Planning docs created
- Firebase + Google sign-in moved into MVP 1 for shared editing
- No app code yet

## MVP 1 — Shared mobile-first planner

Goal: prove the core experience works for Kwame and Laura with shared editing, while still avoiding AI and public-app complexity.

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

### MVP 1 success test

MVP 1 is successful if Kwame and Laura can both sign in, access the same shared calendar, add/edit activities, generate a useful week, and preserve locked items during regeneration.

## MVP 2 — Calendar subscription and polish

Goal: make the shared plan visible from normal phone calendar apps and improve the shared experience.

- [ ] Add shared calendar export/feed
- [ ] Generate ICS calendar feed
- [ ] Let another person subscribe to the calendar
- [ ] Document calendar refresh limitations
- [ ] Improve invite/member management if needed
- [ ] Improve conflict/loading/error states for shared editing

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

Can Kwame and Laura sign in, share one calendar, and generate a useful, rule-respecting week from their activity list?