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