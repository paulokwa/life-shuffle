# Shared Calendar Plan

Date: 2026-06-20

## Goal

Start V1 shared calendar access for Kwame and Laura without building public teams, public profiles, email invitations, roles beyond owner/member, AI, or a broader sharing system.

## Current State

Each signed-in user currently syncs through a deterministic default calendar document:

`calendars/{uid}_default`

`AppState` tracks the current calendar metadata, but the save function only receives the signed-in user ID. `FirestoreSyncService.saveState()` therefore always writes to the signed-in user's default calendar, not necessarily the selected/shared calendar.

Settings already displays basic calendar metadata:

- Current calendar title
- Owner
- Member IDs

Firestore rules already gate `calendars/{calendarId}` reads/writes to owners or members, with a narrow default-calendar read allowance for first save.

## Desired V1 Behavior

- Kwame can add Laura as a member of the current calendar.
- Laura can sign in with her own Google account.
- Laura can open the shared calendar and edit it.
- Existing users still open their current default calendar normally.
- If a user can access one calendar, the app selects it automatically.
- If a user can access more than one calendar, the app offers a simple switcher.

This is a private two-person V1 path, not a public invite system.

## Proposed Firestore Shape

### `userProfiles/{uid}`

Minimal signed-in lookup profile:

```json
{
  "uid": "firebase-auth-uid",
  "emailLower": "person@example.com",
  "displayName": "Display Name",
  "updatedAtMillis": 1234567890
}
```

Rules:

- A signed-in user can create/update their own profile.
- Signed-in users can read/query minimal profile documents for member lookup.
- Profiles must not store secrets, tokens, private notes, or broad public profile data.

### `calendars/{calendarId}`

Keep the current flat calendar document shape, including the existing saved planner state fields.

Membership fields stay simple:

```json
{
  "calendarId": "ownerUid_default",
  "title": "Kwame and Laura",
  "ownerUserId": "ownerUid",
  "memberUserIds": ["ownerUid", "memberUid"]
}
```

Rules:

- Owners and members can read calendars where they are included.
- Owners and members can edit planner state.
- Only the owner should be allowed to change `memberUserIds`.
- `ownerUserId` and `calendarId` remain immutable after create.

## User Identity Discovery

On signed-in app startup, the app should upsert `userProfiles/{uid}` using safe Firebase Auth fields:

- `uid`
- `emailLower`
- `displayName`, if available
- `updatedAtMillis`

Adding a member by email should:

1. Normalize the entered email to lowercase.
2. Query `userProfiles` where `emailLower` matches.
3. If found, add that profile's `uid` to the current calendar's `memberUserIds`.
4. If not found, show: `Laura needs to sign in once before she can be added.`

This means Laura must sign in once before Kwame can add her by email. No email invite is sent in this slice.

## Accessible Calendar Loading

After sign-in, load calendars with:

`calendars.where('memberUserIds', arrayContains: uid)`

Then:

- If one or more accessible calendars exist, choose the previously selected current/default calendar when possible, otherwise choose the first accessible calendar with the current user's default calendar preferred.
- If none exist, create or load the signed-in user's default calendar as today.
- Do not delete or migrate existing calendar documents.

## Selected Calendar Choice

`AppState` should track the selected/current calendar ID.

All calendar-specific edits must save back to the selected calendar, not blindly to `{uid}_default`.

For V1:

- If only one accessible calendar exists, select it automatically.
- If multiple accessible calendars exist, show a simple switcher in Settings and/or the header.
- Keep the existing default-calendar behavior for current users.

## Risks

- Accidental overwrite of Kwame's calendar if a member's edits save to `{memberUid}_default` instead of the selected shared calendar.
- Selected calendar versus default calendar confusion when Laura has both her own default calendar and Kwame's shared calendar.
- Rules accidentally allowing too much profile or calendar access.
- Feed token and cached ICS behavior must remain tied to the selected calendar document.
- Querying by email exposes minimal profile lookup to signed-in users; keep the profile document intentionally small.

## Implementation Steps

1. Add minimal user profile upsert and email lookup methods to `FirestoreSyncService`.
2. Add accessible calendar loading via `memberUserIds arrayContains uid`.
3. Thread selected calendar ID through `AppState` save/load logic.
4. Preserve current default calendar creation when no accessible calendar exists.
5. Add owner-only member-add method for the selected calendar.
6. Add Settings > Calendar `Add member` action with an email dialog and helpful unknown-email message.
7. Add a simple calendar switcher only when multiple accessible calendars exist.
8. Update Firestore rules conservatively for `userProfiles` and owner-only membership changes.
9. Enhance diagnostics with safe calendar counts, titles, owner/member counts, and optional inspected-account owner/member status.
10. Add focused tests for default loading, shared loading, member add success/failure, selected-calendar save target, safe member display, and live controls.

## Final Status

Design status: straightforward enough for a small implementation slice. No production Firestore reset or destructive migration is required.

Implementation status: implemented locally for the first V1 slice.

Completed in this slice:

- Minimal `userProfiles/{uid}` upsert from signed-in Auth data.
- Accessible calendar loading with `memberUserIds arrayContains uid`.
- Selected-calendar save targeting so edits save to the selected shared calendar.
- Existing default calendar fallback when no accessible calendar exists.
- Owner-only Settings > Calendar `Add member` action by email.
- Helpful unknown-email message when the profile does not exist yet.
- Simple Settings/header switcher when more than one calendar is accessible.
- Conservative rules draft for `userProfiles` and owner-only membership changes.
- Secret-safe diagnostics update that reports feed-token presence only.

Not completed in this slice:

- Firestore rules deploy. Rules changed locally, but deployment still requires Kwame approval.
- Email invitations.
- Public profiles.
- Owner/member role UI beyond simple owner/member behavior.
- Calendar create/leave/delete lifecycle.
- Real production smoke test with Laura's account.
