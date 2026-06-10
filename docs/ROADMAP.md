# Life Shuffle Roadmap

## Vision

Life Shuffle helps users create a realistic personal activity calendar from things they already like, things they might like, and rules that make the plan livable.

The first version should help Kwame and Laura plan better weeks. Public-app thinking comes later.

## Current status

- Repository created
- Flutter chosen as the main technology direction
- Planning docs created
- No app code yet

## MVP 1 — Local mobile-first planner

Goal: prove the core experience works without AI, accounts, or cloud sync.

### Build tasks

- [ ] Create Flutter project structure
- [ ] Add mobile-first app shell
- [ ] Add bottom navigation
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
- [ ] Add local storage

### MVP 1 success test

MVP 1 is successful if the app can generate a useful week of activities from a small activity bank and allow locked items to survive regeneration.

## MVP 2 — Save and share

Goal: make the app usable across devices and shareable with Laura.

- [ ] Add Firebase setup
- [ ] Add simple persistence
- [ ] Consider anonymous auth before full accounts
- [ ] Save activities and generated plans remotely
- [ ] Add shared calendar export/feed
- [ ] Generate ICS calendar feed
- [ ] Let another person subscribe to the calendar
- [ ] Document calendar refresh limitations

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

When in doubt, build the smallest useful version of the planner engine first.

No feature should be added to MVP 1 unless it helps answer this question:

Can Life Shuffle generate a useful, rule-respecting week from a user's activity list?