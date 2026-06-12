# Life Shuffle AI Communications

This file is the active controlled handoff log between ChatGPT and coding agents such as Claude, Codex, or other IDE assistants.

It is not a general chat transcript.

## Active-file rule

Keep this file short and current.

Archive older resolved entries when this file:
- Exceeds roughly 250 lines, or
- Contains entries from more than one major milestone, or
- Starts taking too long/noisy to read.

Archive path pattern:

`docs/comms_archive/AI_COMMS_YYYY-MM-DD.md`

When archiving:
1. Move old completed/resolved entries into a dated archive file.
2. Keep the rules in this file.
3. Keep the current pending instruction, latest completion, latest blocker, and latest open question.
4. Add archive links to the archive index below.
5. Keep or update the completed feature index so agents do not rebuild finished work.

Do not create `AI_COMMS_2.md`, `AI_COMMS_3.md`, etc. Use dated archive files instead.

## Archive index

No archive files yet.

## Completed feature index

No completed features logged yet.

## Rules

- Only use this file for direct AI-to-AI implementation instructions, completion reports, blockers, and handoff notes.
- Do not paste casual conversation with the user into this file.
- ChatGPT should read this file only when the user explicitly says: `check comms`.
- Coding agents should update this file when they complete work, hit a blocker, or need clarification.
- Each entry must include a timestamp.
- Completion entries must list what was changed so the same feature is not rebuilt accidentally.
- Completion entries must include a `Feature/work completed` section.
- If the user manually copies instructions instead of using this file, that is fine. This file is a backup/bridge, not the only communication path.
- Keep entries concise and implementation-focused.

## Entry format

```md
## YYYY-MM-DD HH:mm TZ — From [Agent] to [Agent/User]

Type: Instruction | Completion | Blocker | Question | Review Request | Archive

Summary:
- ...

Feature/work completed:
- ...

Files changed:
- ...

Commands run:
- ...

Tests run:
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

Feature/work completed:
- None yet by coding agent.

Files changed:
- None yet by coding agent.

Commands run:
- None yet by coding agent.

Tests run:
- None yet by coding agent.

Status:
- Pending

Next requested action:
- Coding agent should implement the first UI milestone and then append a Completion entry to this file listing changed files, commands run, tests run, completed work, remaining work, and any blockers.
