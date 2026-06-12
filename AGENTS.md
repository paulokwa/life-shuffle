# AGENTS.md

This file tells AI coding agents how to work in this repository.

Life Shuffle is a mobile-first Flutter app for planning personal activities, generating rule-based calendars, and helping users get unstuck.

## Required start-of-session routine

Before proposing or making code changes, read these files:

1. `docs/MASTER_PLAN.md`
2. `docs/DECISIONS.md`
3. `docs/ROADMAP.md`
4. `docs/PARKING_LOT.md`
5. `docs/WORKING_AGREEMENT.md`
6. `docs/SESSION_LOG.md`
7. `docs/TROUBLESHOOTING_LOG.md`
8. `docs/DESIGN.md`
9. `docs/FIGMA_HANDOFF.md`
10. `docs/AI_COMMS.md` only if Kwame explicitly asks you to use/check the AI communications file, or if you are appending a completion/blocker entry after work.

Then summarize:

- What the current project goal is
- What milestone the requested work belongs to
- Whether the request supports the master plan
- Whether it risks scope creep
- Which files you expect to modify

Do not skip this for major features, architecture changes, AI features, auth/profile work, Firebase work, calendar sharing, or anything that changes product direction.

## Product direction rules

- Mobile-first Flutter app.
- Rule-based planner first.
- AI later.
- Public launch later.
- First useful version is for Kwame and Laura.
- Firebase and Google sign-in are in MVP1 for simple shared editing, but do not start them before the current UI shell milestone unless explicitly requested.
- Do not let new brainstorming quietly replace the original vision.

## Scope control

If a requested idea is useful but not needed for the current milestone, suggest adding it to `docs/PARKING_LOT.md`.

If a requested idea changes product direction, ask for confirmation before updating `docs/MASTER_PLAN.md`.

Only update the master plan when Kwame explicitly approves with wording like:

- "safe to update master plan"
- "yes update the master plan"
- "make that the new direction"

## Coding style

- Prefer small, reviewable changes.
- Avoid over-engineering.
- Keep implementation practical.
- Explain what changed and why.
- Use clear Flutter/Dart structure.
- Build the visible UI shell and Today screen first for the current milestone.
- Do not start backend/database/auth work until requested for a later milestone.

## Design handoff rules

For UI work, read:

1. `docs/DESIGN.md`
2. `docs/FIGMA_HANDOFF.md`

The original Figma Make URL may not be readable by all MCP clients because it is a `figma.com/make` file rather than a normal design file. If MCP access fails, use `docs/FIGMA_HANDOFF.md` as the concrete visual handoff.

Do not import Figma Make React files into the production Flutter app.

Use the Figma-derived details to translate the visual style into Flutter widgets with good fidelity.

## AI communications workflow

`docs/AI_COMMS.md` is a controlled active handoff log between ChatGPT and coding agents such as Claude, Codex, or other IDE assistants.

Rules:

- Use it only for direct AI-to-AI implementation instructions, completion reports, blockers, questions, and review requests.
- Do not paste casual user conversation into it.
- ChatGPT should read it only when Kwame explicitly says `check comms`.
- Coding agents should append to it when they complete work, hit a blocker, or need clarification.
- Each entry must include a timestamp.
- Completion entries must list changed files, commands run, tests run, and any unfinished work.
- Completion entries must clearly say what feature/work was completed so duplicate implementation can be avoided.
- If Kwame manually copies instructions instead of using the file, that is fine. This file is a bridge, not the only communication path.

### AI comms archiving

Keep `docs/AI_COMMS.md` short and current.

Archive older resolved entries when `docs/AI_COMMS.md`:

- Exceeds roughly 250 lines, or
- Contains entries from more than one major milestone, or
- Starts taking too long/noisy to read.

Archive path pattern:

`docs/comms_archive/AI_COMMS_YYYY-MM-DD.md`

When archiving:

1. Move old completed/resolved entries into a dated archive file.
2. Keep active rules in `docs/AI_COMMS.md`.
3. Keep only the current pending instruction, latest completion, latest blocker, and latest open question.
4. Add the archive file to the archive index in `docs/AI_COMMS.md`.
5. Keep/update the completed feature index in `docs/AI_COMMS.md`.

Do not create numbered files like `AI_COMMS_2.md`.

## Required end-of-session routine

When Kwame says `end session`, do the following:

1. Summarize what changed.
2. Update `docs/SESSION_LOG.md` with:
   - Date
   - Goal
   - Files changed
   - Decisions made
   - Current state
   - Next recommended step
3. Update `docs/TROUBLESHOOTING_LOG.md` if any notable errors, blockers, build failures, dependency issues, or confusing fixes occurred.
4. Suggest whether any item should be added to `docs/DECISIONS.md`, `docs/ROADMAP.md`, or `docs/PARKING_LOT.md`.

Do not invent successful tests. If tests were not run, say so.

## Agent handoff rule

Write logs so another AI agent can continue the work without needing the previous chat.

The goal is continuity, not theatre.
