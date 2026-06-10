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
- Auth later.
- Public launch later.
- First useful version is for Kwame and Laura.
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
- Build the planner engine before polish-heavy features.

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