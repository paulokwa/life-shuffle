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
   - Activity list, rules, calendar generation, locking, regeneration, shared editing, calendar publishing, practical export/print, check-ins, and basic progress tracking come before AI.
   - AI support comes after the core planner works.

4. Keep early scope personal.
   - First version is for Kwame and Laura.
   - The app should support simple shared calendars between Kwame and Laura from Version 1.
   - Do not overbuild public profiles, marketplace, subscriptions, or broad social features too early.

5. The app should reduce stuckness, not increase admin.
   - Adding activities should feel light.
   - The user should never need to perfectly know what they like before starting.
   - Optional planning dimensions should be switchable so users can keep the app simple if they do not want extra fields.
   - Check-ins should not require typing by default.
   - Onboarding should be short, skippable where possible, and focused on getting to the first useful generated week.
   - Empty states, error messages, and planner failures should help the user take the next small action.
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

8. Progress tracking should be gentle.
   - Check-ins should help users learn from their plans, not shame them.
   - The app should use fast visual status controls before asking for notes.
   - Notes should be optional and hidden behind an explicit action.

## Core user flow

1. User opens the app.
2. User signs in with Google.
3. User confirms or edits their display name.
4. User creates or selects a named Life Shuffle calendar.
5. During setup/onboarding, the user is asked to name the first calendar, with a sensible default such as `Kwame and Laura` or `My Life Shuffle`.
6. User can optionally add/share the calendar with another person.
7. User chooses which planning dimensions are enabled: difficulty, energy, and/or social level.
8. User picks starter activities from a built-in starter activity library.
9. User can use sensible default rules or review rules before generating.
10. User chooses a first plan style, such as Gentle, Balanced, or Push me a little.
11. App generates a calendar/agenda from the selected calendar's activity bank.
12. User lands on a Today/Home screen or agenda view that clearly shows what matters next.
13. User can lock certain planned items.
14. User can preview regeneration changes before applying them, or otherwise undo the last regeneration.
15. User can regenerate unlocked items while preserving locked ones.
16. If there are past unchecked activities, the app offers a quick check-in prompt that the user can complete or skip.
17. Laura and Kwame can both edit shared calendars inside Life Shuffle when they are members of that calendar.
18. User can mark past planned items as skipped, partly done, or done.
19. User can view basic progress/statistics for the selected calendar.
20. User can print/export the selected calendar with chosen visible details.
21. User can publish a read-only calendar subscription feed for the selected calendar.
22. User can manage account, calendar, planning, publishing, export, and privacy controls from Settings.
23. Later, AI can suggest activities and generate plans while respecting the user's rules.

## Onboarding and setup

Version 1 should include a short onboarding flow that helps the user create their first useful calendar without too much setup friction.

Recommended flow:
1. Welcome: brief explanation of Life Shuffle.
2. Continue with Google.
3. Confirm display name. Use the Google display name as a default, but let the user edit it.
4. Name first calendar. Provide a default such as `My Life Shuffle` or, for the initial personal use case, `Kwame and Laura`.
5. Optional sharing/member step. Let the user add another person by email or skip.
6. Choose planning dimensions: Difficulty, Energy, and Social. Explain each in plain language and let the user switch them on or off.
7. Pick starter activities from a built-in starter library.
8. Choose whether to use sensible default rules or review rules now.
9. Choose first plan style: Gentle, Balanced, or Push me a little.
10. Generate first week.
11. Show the agenda/week view with small hints for lock and shuffle.

Onboarding should avoid:
- Long profile questionnaires.
- Forcing users to configure rules for every activity before they can continue.
- Asking users to type notes or goals before they have seen the app work.
- Pulling activity ideas from websites in Version 1.
- Presenting too many activity suggestions at once.

## Starter activity library

Version 1 should include a built-in starter activity library so the user is not forced to invent ideas from a blank page.

The starter library should be hardcoded/static in Version 1, not pulled from websites or AI.

Suggested starter categories:
- At home
- Outside
- Health / movement
- Social
- Creative
- Rest
- Food
- Chores / life admin
- Couple time
- Low-energy ideas

The picker should show a small number of suggestions first and use a `See more` pattern for larger lists. Users should also be able to add their own custom activities.

Selected starter activities should be added to the selected calendar's activity bank and used by the planner when generating the first week.

Starter activities may include sensible default metadata such as category, default duration, difficulty, energy, social level, and basic rules. The user should be able to change these later.

## Multiple named calendars

Version 1 should support multiple named Life Shuffle calendars.

Purpose:
- Let users separate different planning needs.
- Allow different calendars to have different activity banks, rules, members, published feeds, and progress stats.
- Avoid forcing every activity into one giant mixed calendar.

Examples:
- `Kwame and Laura`
- `Solo getting out`
- `Health and movement`
- `Weekend ideas`
- `House projects`

Each calendar should have:
- A title/name.
- Members and roles.
- Its own activity bank.
- Its own generated plans.
- Its own check-in history and progress stats.
- Its own print/export settings.
- Its own optional published calendar feed.
- Its own calendar-level plan settings.

Onboarding/setup should ask the user to name their first Life Shuffle calendar. The app may provide a default name so the user can continue quickly without typing if they prefer.

Users should be able to create additional calendars later from a clear calendar switcher or settings area.

Calendar lifecycle rules for Version 1 should stay simple:
- Each calendar has an owner.
- Owners can rename or delete the calendar.
- Members can leave a calendar.
- Deleting a calendar revokes its published feed.
- Access should be controlled by calendar membership.

## Settings

Version 1 should include a clear Settings area so important controls are not scattered or hidden.

Settings should be grouped in plain-language sections:

### Account
- Display name.
- Sign out.

### Calendar
- Current calendar name.
- Calendar switcher.
- Create another calendar.
- Members.
- Owner/member roles.
- Leave calendar.
- Delete calendar.

### Planning
- Week starts on Monday or Sunday.
- Earliest activity time.
- Latest activity time.
- Default plan style: Gentle, Balanced, or Push me a little.
- Default number of activities per week.

### Activity defaults
- Enable/disable Difficulty.
- Enable/disable Energy.
- Enable/disable Social.
- Default difficulty.
- Default energy.
- Default social level.

### Publishing
- Enable/disable published calendar feed.
- Copy feed link.
- Revoke/regenerate feed link.
- Explain feed privacy and refresh limitations.

### Export / print
- Choose default output details.
- Include/exclude notes.
- Include/exclude check-in status.
- Include/exclude enabled planning dimensions.

### Privacy / help
- Plain-language privacy explanation.
- Published feed explanation.
- Basic help/about screen.

Settings should respect the selected calendar. Calendar-specific settings should clearly apply to the current calendar, not every calendar the user has access to.

## Calendar-level plan settings

Each calendar should have simple plan settings that affect generation without forcing every activity to carry the same rules.

Version 1 plan settings may include:
- Week starts on Monday or Sunday.
- Earliest activity time.
- Latest activity time.
- Default plan style: Gentle, Balanced, or Push me a little.
- Default number of activities per week.

These settings should be separate from activity-specific rules.

## Optional planning dimensions

Version 1 should support optional planning dimensions that can be enabled or disabled in settings.

Planning dimensions:
- Difficulty/resistance level: how hard the activity feels to actually do, from 1 to 5.
- Energy level: the physical or mental load of the activity, such as Low, Medium, or High.
- Social level: the social shape of the activity, such as Solo, Together, Group, or Either.

Users should be able to switch these dimensions on or off so disabled dimensions do not appear in activity creation, editing, calendar cards, planner rules, or print/export options.

Settings should allow defaults such as:
- Default difficulty: for example 3/5.
- Default energy level: for example Medium.
- Default social level: for example Either.

Difficulty should not rely on colour because category already uses colour. A compact dot display such as `●●●○○` is preferred, with accessible text such as `Difficulty 3 of 5` available where needed.

If difficulty is enabled, the planner should use it to avoid unrealistic weeks, such as too many hard activities or hard activities scheduled back-to-back.

## Activity lifecycle

Version 1 should allow activities to be enabled or disabled.

Disabled activities should:
- Stay in the activity bank.
- Not be used in future generation.
- Preserve past plans, check-ins, and stats history.

Deleting should be more cautious than disabling and should not be the main way to pause an activity.

## Generation safety and conflicts

Version 1 should protect users from accidental or confusing planner changes.

Regeneration should either:
- Preview proposed changes before applying them, or
- Offer an undo action for the last regeneration.

The app should show clear messages when:
- A plan cannot fit all requested activities.
- A locked item conflicts with new rules.
- An activity has nowhere valid to go.
- An activity is disabled but still exists in older plans.
- Another member has updated the calendar.
- Sync fails or the app is offline.

Messages should explain what happened and suggest the next small action, such as relaxing rules, widening the time window, unlocking an item, or trying fewer activities.

## Today/Home screen and empty states

Version 1 should include a simple Today/Home screen or clear landing view after onboarding.

It should show:
- Selected calendar name.
- Today's planned items.
- Next activity.
- Any pending check-in prompt.
- Quick actions such as Generate, Regenerate, Add activity, or View progress.

Version 1 should include helpful empty states for:
- No calendars yet.
- No activities yet.
- No generated plan yet.
- No check-ins yet.
- No stats yet.
- Offline or sync problem.

Empty states should guide the next action instead of feeling like dead ends.

## Privacy and feed explanation

Version 1 should include a simple privacy/settings explanation in plain language.

It should explain:
- Calendars are private to their members.
- Shared calendar members can see and edit that calendar based on their role.
- Published calendar feeds are read-only.
- Anyone with a published feed link may be able to view that feed.
- Users can revoke/regenerate a feed link.
- Deleting a calendar revokes its feed.

## Check-ins and progress

Version 1 should include a low-friction check-in system for past planned activities.

The app should prompt the user to check in when they open/log into the app if there are past planned items without a status. This prompt should be skippable.

Check-in statuses:
- `○` Skipped / not done
- `◐` Partly done
- `●` Done

Check-ins should not require typing by default. Users may add an optional note, but notes should be hidden behind an explicit `Add note` action rather than presented automatically.

Supported check-in views:
- Quick catch-up: shows unchecked past activities since the last check-in.
- One-by-one review: lets the user check in one activity at a time.
- Week review: shows one week at a time and lets the user mark statuses across that week before saving.
- Day sheet: tapping a day from the agenda/calendar opens that day's planned items and status circles.

Month view check-in should not rely on hidden long-press behaviour. A month/day view may show status summaries, but the main action should be tapping a day to open a clear day sheet.

The stats/progress page should show basic information such as:
- Past 7 days
- Past 30 days
- Planned vs done/partly/skipped
- Category breakdown
- Difficulty summary if difficulty is enabled
- Simple streaks or trends
- Looking-ahead summary for upcoming planned items

Progress language should be gentle and descriptive rather than shame-based.

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
- Enabled planning dimensions, such as difficulty, energy, and social level
- Check-in status
- Notes
- Locked status

Private/internal notes should not be printed or exported unless explicitly included by the user.

## MVP 1: shared mobile-first planner

MVP 1 should prove the app is useful for Kwame and Laura with multiple named calendars, shared editing, onboarding, starter activities, structured settings, safety UX, calendar publishing, practical print/export, check-ins, and basic progress tracking, without AI or public-app complexity.

Must include:
- Flutter app structure
- Mobile-first layout
- Firebase setup
- Google sign-in
- Short onboarding/setup flow
- Confirm/edit display name after Google sign-in
- Multiple named Life Shuffle calendars
- Setup/onboarding prompt to name the first calendar, with a sensible default
- Calendar ownership, membership, leave, delete, and feed-revocation basics
- Calendar switcher or clear way to create/select calendars
- Structured Settings area
- Calendar-level plan settings
- Built-in starter activity library
- Starter activity picker with `See more` pattern
- Sensible default rules for starter activities
- First plan style choice: Gentle, Balanced, or Push me a little
- Simple shared calendar membership for Kwame and Laura
- Activity creation flow
- Activity enabled/disabled state
- Activity categories with colours/icons
- Optional planning dimensions: difficulty, energy, and social level
- Settings to enable/disable planning dimensions and set their defaults
- Activity rules
- 7-day agenda generation
- Mobile-friendly agenda/week calendar view
- Today/Home screen or clear landing view
- Helpful empty states
- Lock/unlock planned items
- Regeneration preview or undo
- Regenerate unlocked items only
- Basic conflict/failure messages for generation and sync
- Low-friction check-ins using skipped/partly/done status circles
- Skippable check-in prompt on app open/login when past unchecked items exist
- Basic stats/progress page
- Plain-language privacy and published feed explanation
- Firestore persistence for calendars, activities, planned items, and check-in statuses
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
- Pulling starter activity ideas from websites
- Long onboarding/profile questionnaires
- Forced rule setup for every starter activity
- Rich analytics/charts beyond basic progress
- Notifications/reminders unless explicitly needed later

## MVP 2: polish and expansion

After MVP 1 feels useful:
- Improve sharing/invite flow if needed
- Add stronger polish around shared editing states
- Improve calendar feed controls if needed
- Add richer print/export templates if needed
- Expand day/month/year calendar views if needed
- Add richer analytics/charts if needed

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