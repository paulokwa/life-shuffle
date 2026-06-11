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
   - Activity list, rules, calendar generation, locking, regeneration, shared editing, calendar publishing, and practical export/print come before AI.
   - AI support comes after the core planner works.

4. Keep early scope personal.
   - First version is for Kwame and Laura.
   - The app should support a simple shared calendar between Kwame and Laura from Version 1.
   - Do not overbuild public profiles, marketplace, subscriptions, or broad social features too early.

5. The app should reduce stuckness, not increase admin.
   - Adding activities should feel light.
   - The user should never need to perfectly know what they like before starting.
   - AI assistance can help suggest ideas, but the user stays in control.

6. Shared editing should be simple, not enterprise-grade.
   - Use Firebase and Google sign-in for Version 1 shared editing.
   - Avoid building a custom password system.
   - Avoid full public account/profile complexity until much later.

7. Export and publishing should be practical, not perfect.
   - Version 1 should include a way to publish a read-only calendar feed that Apple Calendar, Google Calendar, Outlook, and similar calendar apps can subscribe to.
   - Version 1 should include print/export options for the generated calendar.
   - Users should be able to choose which details appear in printed/exported output.
   - External calendar apps may not refresh subscribed calendars immediately.

## Core user flow

1. User opens the app.
2. User signs in with Google.
3. User enters or creates the shared Kwame/Laura calendar.
4. User adds activities one at a time.
5. Each activity can include category, location type, duration, notes, icon/colour, and energy/social level.
6. User can add rules such as:
   - Allowed days
   - Allowed time windows
   - Max times per week/month/year
   - Do not repeat on consecutive days
   - Do not schedule outside a specific timeframe
7. App generates a calendar/agenda from the activity bank.
8. User can lock certain planned items.
9. User can regenerate unlocked items while preserving locked ones.
10. Laura and Kwame can both edit the shared calendar inside Life Shuffle.
11. User can print/export the calendar with chosen visible details.
12. User can publish a read-only calendar subscription feed for external calendar apps.
13. Later, AI can suggest activities and generate plans while respecting the user's rules.

## Calendar views

The app should eventually support switchable calendar views:

- Day view
- Week view
- Month view
- Year view

For MVP 1, the priority is a mobile-friendly agenda/week view. Day, month, and year views are part of the product direction, but they do not all need to be fully implemented before the rule-based planner is proven useful.

## Calendar publishing

Version 1 should include a read-only published calendar feed using an external-calendar-friendly format such as ICS/iCalendar.

Purpose:
- Let the generated Life Shuffle plan appear in normal phone calendar apps.
- Allow Apple Calendar, Google Calendar, Outlook, and compatible Android calendar apps to subscribe to the feed.
- Reflect changes when Life Shuffle plans are updated, subject to each calendar app's refresh behaviour.

Important limits:
- The feed is read-only from external calendar apps.
- Editing happens inside Life Shuffle.
- Updates may not appear instantly in external calendar apps.
- Feed URLs should be private/unguessable and revocable.

## Print and export

Version 1 should include practical print/export support for the generated calendar.

Output types may include:
- Printable calendar view
- PDF export
- Simple text/share export

Users should be able to choose which details appear in output, such as:
- Activity title
- Date and time
- Duration
- Category
- Colour/icon
- Location
- Who it is for: Kwame, Laura, Both, or Either
- Notes
- Locked status

Private/internal notes should not be printed or exported unless explicitly included by the user.

## MVP 1: shared mobile-first planner

MVP 1 should prove the app is useful for Kwame and Laura with shared editing, calendar publishing, and practical print/export, without AI or public-app complexity.

Must include:
- Flutter app structure
- Mobile-first layout
- Firebase setup
- Google sign-in
- Simple shared calendar membership for Kwame and Laura
- Activity creation flow
- Activity categories with colours/icons
- Activity rules
- 7-day agenda generation
- Mobile-friendly agenda/week calendar view
- Lock/unlock planned items
- Regenerate unlocked items only
- Firestore persistence for shared activities and planned items
- Read-only published calendar feed for external calendar apps
- Print/export support with user-selectable output details

Should not include yet:
- Custom password system
- Full public profile system
- Public user accounts beyond the private shared setup
- AI local event discovery
- Paid subscriptions
- Complex social sharing
- Native app store release

## MVP 2: polish and expansion

After MVP 1 feels useful:
- Improve sharing/invite flow if needed
- Add stronger polish around shared editing states
- Improve calendar feed controls if needed
- Add richer print/export templates if needed
- Expand day/month/year calendar views if needed

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

Can this help Kwame and Laura make a better week together?

## Master plan change rule

When a new idea comes up, use the phrase "check this against master plan" before changing direction.

The assistant should then inspect this document and identify whether the idea:
- Supports the plan
- Conflicts with the plan
- Is useful but belongs later
- Requires a decision log entry
- Should be parked

Only update this master plan after explicit approval such as "safe to update master plan".