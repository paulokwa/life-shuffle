# Life Shuffle AI Communications

This file is a controlled handoff log between ChatGPT and coding agents such as Claude, Codex, or other IDE assistants.

It is not a general chat transcript.

## Rules

- Only use this file for direct AI-to-AI implementation instructions, completion reports, blockers, and handoff notes.
- Do not paste casual conversation with the user into this file.
- ChatGPT should read this file only when the user explicitly says: `check comms`.
- Coding agents should update this file when they complete work, hit a blocker, or need clarification.
- Each entry must include a timestamp.
- Completion entries must list what was changed so the same feature is not rebuilt accidentally.
- If the user manually copies instructions instead of using this file, that is fine. This file is a backup/bridge, not the only communication path.
- Keep entries concise and implementation-focused.

## Entry format

```md
## YYYY-MM-DD HH:mm TZ — From [Agent] to [Agent/User]

Type: Instruction | Completion | Blocker | Question | Review Request

Summary:
- ...

Files changed:
- ...

Status:
- Pending | In progress | Done | Blocked

Next requested action:
- ...
```

## 2026-06-12 19:00 ADT — From ChatGPT to Claude/Codex

Type: Instruction

Summary:
- Build the first Flutter UI milestone only.
- Read repo docs first: `docs/MASTER_PLAN.md`, `docs/ROADMAP.md`, `docs/DESIGN.md`, `docs/FIGMA_HANDOFF.md`, `docs/DECISIONS.md`, `docs/PARKING_LOT.md`, and `docs/WORKING_AGREEMENT.md`.
- Use `docs/FIGMA_HANDOFF.md` as the concrete visual handoff because the original Figma Make URL may not be readable through every MCP client.
- Product truth remains `MASTER_PLAN.md` and `ROADMAP.md`.
- Visual truth is `DESIGN.md` and `FIGMA_HANDOFF.md`.
- Implementation target is Flutter.

Requested build:
- Flutter app shell.
- Theme tokens from `docs/FIGMA_HANDOFF.md`.
- Shared reusable UI components:
  - `AppScaffold`
  - `LifeShuffleHeader`
  - `LsCard`
  - `CategoryChip`
  - `CheckInCircle`
  - `QuickActionCard`
  - `BottomNavShell`
  - `ActivityPlanCard`
- Bottom navigation with exactly:
  - Today
  - Plan
  - Activities
  - Progress
  - Settings
- Today screen using mock data, matching `docs/FIGMA_HANDOFF.md` as closely as practical.
- Warm styled placeholder/static screens for:
  - Plan
  - Activities
  - Progress
  - Settings
  - Onboarding

Do not implement yet:
- Firebase
- Firestore
- Google sign-in
- Auth gate
- Real database setup
- Real planner generation logic
- Calendar publishing / ICS feed
- Export / PDF generation
- Real persistence
- Notifications
- AI screens
- Public/social features

Definition of done:
- Flutter app runs locally.
- User can view it in browser or emulator.
- Bottom nav switches between the five main sections.
- Today screen closely follows the Figma-derived handoff.
- Other main screens exist as styled placeholders.
- No backend setup is required.
- No extra scope is added.

Files changed:
- None yet by coding agent.

Status:
- Pending

Next requested action:
- Coding agent should implement the first UI milestone and then append a Completion entry to this file listing changed files, commands run, and any blockers.
