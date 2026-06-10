# Life Shuffle Master Plan

## Purpose

Life Shuffle is a mobile-first Flutter app for helping a person build a realistic, personal activity calendar when they feel stuck, overwhelmed, bored, isolated, or unsure what to do next.

The core idea is simple: the user builds a bank of activities they might want to do, adds conditions/rules around those activities, and the app generates a calendar that gives future-them a plan.

This is not just a productivity app. It is an "options for living" app.

## Working title

Life Shuffle

## Core problem

Sometimes people want to do more with their time but get stuck because they do not have a ready plan, cannot easily think of what they enjoy, or feel overwhelmed by too many vague possibilities.

Life Shuffle should help turn "I should do something" into a small set of realistic calendar options.

## Product principles

1. Mobile-first, not desktop-first.
   - The app must feel like a real phone app.
   - Big tap targets, simple screens, bottom navigation, sticky action buttons, and agenda-first calendar views matter more than dense desktop features.

2. Protect the original idea from future excitement drift.
   - New ideas should be checked against this master plan before being added.
   - If an idea conflicts with the plan, flag the conflict before changing direction.
   - Good-but-later ideas go into PARKING_LOT.md, not straight into the MVP.

3. Build the boring useful engine before the shiny AI layer.
   - Activity list, rules, calendar generation, locking, and regeneration come first.
   - AI support comes after the core planner works.

4. Keep early scope personal.
   - First version is for Kwame and Laura.
   - Do not overbuild social, marketplace, public profile, or complex account features too early.

5. The app should reduce stuckness, not increase admin.
   - Adding activities should feel light.
   - The user should never need to perfectly know what they like before starting.
   - AI assistance can help suggest ideas, but the user stays in control.

## Core user flow

1. User opens the app.
2. User adds activities one at a time.
3. Each activity can include category, location type, duration, notes, icon/colour, and energy/social level.
4. User can add rules such as:
   - Allowed days
   - Allowed time windows
   - Max times per week/month/year
   - Do not repeat on consecutive days
   - Do not schedule outside a specific timeframe
5. App generates a calendar/agenda from the activity bank.
6. User can lock certain planned items.
7. User can regenerate unlocked items while preserving locked ones.
8. Later, AI can suggest activities and generate plans while respecting the user's rules.

## Calendar views

The app should eventually support switchable calendar views:

- Day view
- Week view
- Month view
- Year view

For MVP 1, the priority is a mobile-friendly agenda/week view. Day, month, and year views are part of the product direction, but they do not all need to be fully implemented before the rule-based planner is proven useful.

## MVP 1: local mobile-first planner

MVP 1 should prove the app is useful without AI, accounts, or cloud sync.

Must include:
- Flutter app structure
- Mobile-first layout
- Activity creation flow
- Activity categories with colours/icons
- Activity rules
- 7-day agenda generation
- Mobile-friendly agenda/week calendar view
- Lock/unlock planned items
- Regenerate unlocked items only
- Local storage

Should not include yet:
- Full login/profile system
- Public user accounts
- AI local event discovery
- Paid subscriptions
- Complex social sharing
- Native app store release

## MVP 2: persistence and sharing

After MVP 1 feels useful:
- Add Firebase
- Add anonymous auth or simple private user setup
- Save activities and plans remotely
- Add shared calendar subscription via ICS feed
- Allow Laura/Kwame calendar sharing

Important: calendar subscription updates are not guaranteed to be instant on every phone/calendar provider.

## MVP 3: AI assistance

AI should support the planner, not replace it.

Possible AI features:
- Suggest activity ideas from user profile
- Ask one question at a time
- Show all suggestions view
- Tick/no-tick acceptance flow
- Generate a weekly plan from existing activities and rules
- BYOK API key support
- Later: local community event suggestions

AI must respect user-defined rules and locked calendar items.

## Long-term vision

Life Shuffle could eventually become a public app for people who need help creating structure, variety, and gentle momentum in their lives.

But the first win is much smaller:

Can this help Kwame and Laura make a better week?

## Master plan change rule

When a new idea comes up, use the phrase "check this against master plan" before changing direction.

The assistant should then inspect this document and identify whether the idea:
- Supports the plan
- Conflicts with the plan
- Is useful but belongs later
- Requires a decision log entry
- Should be parked

Only update this master plan after explicit approval such as "safe to update master plan".