# Decision Log

This file records important product and technical decisions so future brainstorming does not accidentally erase earlier thinking.

Use this when a choice affects direction, architecture, scope, or user experience.

## Decision format

Each entry should include:

- **Date**: YYYY-MM-DD
- **Decision**: What was decided
- **Why**: The reasoning at the time
- **Alternatives considered**: Other options discussed
- **Status**: Active, Deprecated, or Under Review
- **Related files**: Optional links to docs or code

## Active decisions

### 2026-06-10 — Use Flutter as the primary app technology

- **Decision**: Build Life Shuffle with Flutter.
- **Why**: The app must be extremely mobile responsive and feel like a real app. Flutter gives a strong mobile-first path while still allowing web deployment and future iOS/Android builds from one codebase.
- **Alternatives considered**:
  - Swift: stronger for Apple-only native apps, but weaker fit for web/Android later.
  - Ionic React: strong for PWA/web-first development, but the project direction shifted toward a real app feel.
- **Status**: Active

### 2026-06-10 — Build the rule-based planner before AI

- **Decision**: MVP 1 will focus on activities, rules, agenda generation, lock/unlock, regeneration, and local storage before adding AI.
- **Why**: The planner engine is the real foundation. AI should assist the experience later, not hide a weak core.
- **Alternatives considered**:
  - Add BYOK AI immediately.
  - Start with local event discovery.
- **Status**: Active

### 2026-06-10 — Start personal before public

- **Decision**: First version is for Kwame and Laura, not a public multi-user product.
- **Why**: The fastest way to prove value is to make the app useful in real life first. Full auth, public profiles, and social features can be expensive distractions early.
- **Alternatives considered**:
  - Build profile/login support from day one.
  - Build as a public SaaS immediately.
- **Status**: Active

### 2026-06-10 — Use docs as continuity guardrails

- **Decision**: Use MASTER_PLAN.md, DECISIONS.md, ROADMAP.md, and PARKING_LOT.md as the source of truth for project direction.
- **Why**: Past projects suffered from idea drift when new brainstorming accidentally overrode earlier good ideas. These docs protect the original idea while still allowing new ideas to be evaluated.
- **Alternatives considered**:
  - Keep everything in chat memory.
  - Let the implementation evolve without written guardrails.
- **Status**: Active