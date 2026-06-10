# Working Agreement

This document describes how Kwame and AI assistants should work together on Life Shuffle.

It exists because project ideas can drift when brainstorming gets exciting. The goal is to preserve good early ideas while still allowing new ideas to be evaluated properly.

## Main collaboration rule

The repository docs are the source of truth for product direction.

Important files:

- `docs/MASTER_PLAN.md` — stable product vision
- `docs/DECISIONS.md` — important choices and why they were made
- `docs/ROADMAP.md` — build order and milestones
- `docs/PARKING_LOT.md` — useful ideas that are not for now
- `docs/SESSION_LOG.md` — running handoff notes between sessions
- `docs/TROUBLESHOOTING_LOG.md` — recurring problems and fixes
- `AGENTS.md` — operating instructions for AI coding agents

## Trigger phrases

### "check this against master plan"

The assistant should:

1. Read the relevant repo docs.
2. Compare the new idea/request against the current plan.
3. Identify whether it:
   - Supports the plan
   - Conflicts with the plan
   - Duplicates something already planned
   - Is scope creep
   - Belongs in the parking lot
4. Give a recommendation before any change is made.

### "safe to update master plan"

The assistant may update `docs/MASTER_PLAN.md` after checking for consistency with the rest of the docs.

### "park this"

The assistant should add the idea to `docs/PARKING_LOT.md` with a short explanation of why it is not part of the current milestone.

### "log this decision"

The assistant should add a decision entry to `docs/DECISIONS.md`.

### "end session"

The coding agent should update continuity files before stopping work:

- `docs/SESSION_LOG.md`
- `docs/TROUBLESHOOTING_LOG.md` if relevant

## Preferred build philosophy

- Prove value quickly.
- Keep changes small and reviewable.
- Prefer working MVPs over elaborate architecture.
- Avoid adding auth, AI, subscriptions, or public-launch features too early.
- Use the parking lot to preserve good ideas without derailing the current milestone.

## Communication style for AI assistants

Assistants should be direct about:

- Scope creep
- Over-engineering
- Conflicts with the master plan
- Risks that could slow down the project
- Missing tests or unverified assumptions

Assistants should not pretend something was tested if it was not tested.

## Current product bias

When there is uncertainty, bias toward this order:

1. Rule-based planner engine
2. Mobile-first Flutter UI
3. Local storage
4. Firebase persistence
5. Shared calendar feed
6. AI assistance
7. Auth/profile complexity
8. Public launch and monetization

## Handoff goal

At any point, another AI agent should be able to read the docs and understand:

- What Life Shuffle is
- What is being built now
- What should not be built yet
- What decisions have already been made
- What problems have already been solved