# Life Shuffle Design Guide

This document captures the approved visual direction from the Figma Make exploration. It is a design bridge for implementing the Flutter app.

It does not replace:
- `docs/MASTER_PLAN.md`
- `docs/ROADMAP.md`
- `docs/DECISIONS.md`

Those documents remain the product source of truth.

## Design intent

Life Shuffle should feel like a calm, friendly activity-planning app for getting unstuck.

It should not feel like:
- A task manager
- A work productivity dashboard
- A habit tracker
- A project management tool
- An admin console

The emotional question the UI should answer is:

> What might I like to do next?

not:

> What have I failed to complete?

Activities should feel like options and opportunities, not obligations.

Progress should feel gentle and reflective, not judgemental.

## Visual direction

Approved direction from Figma Make:
- Warm minimalist
- Cream background
- White rounded cards
- Terracotta primary accent
- Sage secondary accent
- Calm, friendly, lightly optimistic
- Spacious mobile-first layouts
- Large touch targets
- Soft cards and chips
- Gentle progress and check-in language

## Figma MCP handoff

When a coding agent has access to the Figma MCP connector, it should use the Figma Make file as the most accurate visual reference for the approved Today screen.

Use Figma MCP to inspect and preserve, as closely as practical in Flutter:
- Layout structure
- Spacing
- Dimensions
- Padding
- Card shapes
- Border radius
- Visual hierarchy
- Colours
- Typography choices
- Component patterns
- Bottom navigation pattern
- Header/calendar switcher pattern
- Category chips
- Check-in circles

The goal is not loose inspiration. The goal is to translate the approved Figma Today screen into Flutter with good visual fidelity.

However, the Figma Make output is React code. Life Shuffle is a Flutter app.

Use the Figma output as design authority for visual details, but do not copy the generated React architecture, shadcn components, routing, package structure, or React state model into the production Flutter app.

## Colour tokens

Use these as starting Flutter theme tokens:

| Token | Value | Use |
| --- | --- | --- |
| Background cream | `#FAF7F2` | App background |
| Surface / card white | `#FFFFFF` | Cards, sheets, grouped panels |
| Primary terracotta | `#C8603A` | Primary buttons, selected nav, key highlights |
| Secondary sage | `#6A9E88` | Secondary accents, calm highlights, supportive states |

Additional colours should be soft, accessible, and restrained.

Avoid:
- Harsh neon colours
- Dense rainbow category systems
- Red/green shame-style progress states
- Productivity-dashboard blues unless there is a strong reason

## Typography

Use:
- A warm serif such as Lora only for major headings, if practical.
- A clean sans-serif such as DM Sans, Inter, or a Flutter-compatible equivalent for body text, buttons, labels, navigation, cards, and forms.

If custom fonts slow implementation, prefer a clean Flutter default or sans-serif first. Do not block progress on exact font matching.

## Layout principles

- Mobile-first.
- Big tap targets.
- Agenda-first, not dense calendar-grid-first.
- Rounded cards.
- Clear spacing.
- One primary action per screen.
- Keep deeper options available but not dominant.
- Avoid engineer-dashboard density.

## Navigation

Mobile bottom navigation has exactly:

1. Today
2. Plan
3. Activities
4. Progress
5. Settings

Do not put these in the bottom navigation:
- Export
- Publish
- Check-in
- Calendar switcher
- AI

The selected calendar appears in the top/header area, for example:

`Kwame and Laura ▼`

Tablet and desktop layouts can use a sidebar with the same five sections.

## Core UI patterns

### Header

Each main screen should show:
- Selected calendar name
- Clear screen title
- Optional small friendly context line

### Cards

Cards should be:
- White or softly tinted
- Rounded
- Spacious
- Easy to scan
- Used for activities, check-ins, summaries, empty states, and settings groups

### Category chips

Use soft chips for activity categories such as:
- Outside
- Creative
- Couple time
- Rest
- Chores
- Food

### Difficulty

If enabled, difficulty should use compact dots such as:

`●●●○○`

Do not rely only on colour.

### Check-ins

Use the gentle three-state check-in control:

| Symbol | Meaning |
| --- | --- |
| `○` | Skipped / not done |
| `◐` | Partly done |
| `●` | Done |

No typing by default. Notes should be optional and hidden behind an explicit `Add note` action.

## Screen guidance

### Today

The Today screen is the main landing screen. It should feel calm and useful.

It should include:
- Selected calendar header
- Today title or greeting
- Next activity card
- Pending check-in card if needed
- This week summary
- Quick actions
- Today's activity list

The first Flutter implementation of Today should be built from the Figma MCP output as closely as practical, not merely guessed from this written guide.

### Plan

Use an agenda-first weekly view.

Include:
- Day strip or simple week selector
- Activity cards
- Lock/unlock controls
- Regenerate unlocked
- Preview/undo regeneration pattern
- Export/print and publish/feed as secondary actions

Avoid a dense month-grid-first layout for MVP.

### Activities

The activity bank should feel like a list of options.

Include:
- Add activity
- Starter library access
- Activity cards
- Enabled/disabled state
- Category, duration, difficulty, energy, and social where enabled

Avoid making it feel like a task database.

### Progress

Progress should be reflective and non-shaming.

Include:
- Quick catch-up
- Past 7 / Past 30
- Done / partly / skipped summary
- Category breakdown
- Optional difficulty summary
- Looking ahead summary

Avoid productivity-score language.

### Settings

Use grouped plain-language settings:
- Account
- Calendar
- Planning
- Activity defaults
- Publishing
- Export / print
- Privacy / help

Settings apply to the selected calendar where relevant.

## Empty states

Empty states should suggest the next small action.

Examples:
- No activities yet → Pick a few starter activities.
- No generated plan yet → Generate your first week.
- No check-ins yet → Check-ins will appear after planned activities pass.

Avoid dead-end empty screens.

## Figma reference

Figma Make reference:

`https://www.figma.com/make/TcI9RZkCl7wN3VAgGkte1Q/Read-File?t=zxUHjkMKmHmXf1At-0`

Use the Today screen and generated theme as the visual source for the first Flutter UI pass.

The Figma MCP connector should be used for accurate layout, spacing, dimensions, colours, component patterns, and hierarchy where available.

Do not copy the Figma React architecture into the Flutter app.

## Implementation guidance for AI coding agents

When implementing from this design guide:

1. Read `docs/MASTER_PLAN.md`, `docs/ROADMAP.md`, and `docs/DECISIONS.md` first.
2. Treat this file as visual guidance, not product scope.
3. Use Figma MCP, when available, to inspect the approved Today screen and extract accurate visual details.
4. Translate the Figma Make visual style into Flutter widgets with good visual fidelity.
5. Do not import the Figma Make React files into the Flutter app as production code.
6. Start with a static UI shell and mock data before adding Firebase, auth, generation logic, or real persistence.
7. Build the Today screen first as the closest match to the Figma reference.
8. Use the Today screen design language for Plan, Activities, Progress, Settings, and Onboarding.

Product truth = repo docs.

Visual truth = Figma MCP / Figma Today screen, supported by this guide.

Implementation truth = Flutter best practices.
