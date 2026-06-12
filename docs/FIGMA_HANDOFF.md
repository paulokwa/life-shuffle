# Life Shuffle Figma Make Handoff

This document captures detailed implementation guidance from the Figma Make Today screen and generated style files.

It exists because the original Figma Make URL may not be readable by every MCP client. When MCP access fails, this document gives coding agents enough concrete visual detail to build the first Flutter UI pass without guessing.

This document does not replace:
- `docs/MASTER_PLAN.md`
- `docs/ROADMAP.md`
- `docs/DESIGN.md`
- `docs/DECISIONS.md`

Product scope still comes from the repo docs. This file is visual handoff only.

## Implementation priority

First UI milestone:

1. Flutter app shell.
2. Theme tokens.
3. Shared reusable UI components.
4. Bottom navigation.
5. Today screen with mock data.
6. Placeholder/static Plan, Activities, Progress, Settings, and Onboarding screens.

Do not start Firebase, Firestore, auth, calendar publishing, planner logic, or generation logic in this first UI milestone unless explicitly asked.

## Visual source

The approved Figma Make direction is a warm minimalist mobile app.

The Figma Make Today screen used:
- Cream app background.
- White rounded cards.
- Terracotta primary highlight.
- Sage secondary highlight.
- Warm dark brown text.
- Warm muted grey secondary text.
- Soft chips.
- Rounded full pills.
- Rounded card corners.
- Calm spacing.
- Bottom navigation.

The Today screen should be built with close visual fidelity to this handoff.

## Core colour tokens

Use these as Flutter constants/theme tokens.

| Name | Hex | Use |
| --- | --- | --- |
| `backgroundCream` | `#FAF7F2` | Main page background |
| `surfaceWhite` | `#FFFFFF` | Cards, bottom nav, panels |
| `primaryTerracotta` | `#C8603A` | Primary actions, selected nav, next-up card |
| `accentSage` | `#6A9E88` | Check-in action, done state, supportive accents |
| `textPrimary` | `#2C2A26` | Main text |
| `textMuted` | `#7A7568` | Secondary text, inactive nav |
| `warmBeige` | `#EDE8E0` | Header pills, muted surfaces, progress track |
| `sand` | `#C8943A` | Partly-done state |
| `dustySky` | `#8BB4C8` | View plan quick action accent |
| `mauve` | `#B08EA0` | Progress quick action accent |
| `couplePink` | `#C87888` | Couple time category accent |
| `borderWarm` | `rgba(44, 42, 38, 0.08)` | Card/bottom nav border |
| `borderWarmStrong` | `rgba(44, 42, 38, 0.15)` | Secondary button border |

Recommended Flutter equivalents:

```dart
const backgroundCream = Color(0xFFFAF7F2);
const surfaceWhite = Color(0xFFFFFFFF);
const primaryTerracotta = Color(0xFFC8603A);
const accentSage = Color(0xFF6A9E88);
const textPrimary = Color(0xFF2C2A26);
const textMuted = Color(0xFF7A7568);
const warmBeige = Color(0xFFEDE8E0);
const sand = Color(0xFFC8943A);
const dustySky = Color(0xFF8BB4C8);
const mauve = Color(0xFFB08EA0);
const couplePink = Color(0xFFC87888);
```

For alpha values:
- `rgba(44,42,38,0.08)` is approximately `Color(0x142C2A26)`.
- `rgba(44,42,38,0.10)` is approximately `Color(0x1A2C2A26)`.
- `rgba(44,42,38,0.15)` is approximately `Color(0x262C2A26)`.

## Category chip colours

Use rounded pills with small text.

| Category | Background | Text |
| --- | --- | --- |
| Creative | `#FAF0EC` | `#C8603A` |
| Outside | `#EEF6F2` | `#6A9E88` |
| Couple time | `#FAF0F2` | `#C87888` |
| Social | `#F6EEF3` | `#B08EA0` |
| At home | `#FDF5EC` | `#C8943A` |
| Rest | `#F2F0F8` | `#9A90BE` |
| Default | `#F4F2EE` | `#9E9888` |

Approximate chip styling:
- Border radius: full pill.
- Horizontal padding: `10px` equivalent.
- Vertical padding: `2px` to `4px` equivalent.
- Font size: around `12px`.
- Font weight: medium.

## Typography

Figma Make used:
- `DM Sans` for body, UI labels, buttons, chips, nav, and cards.
- `Lora` for major headings.

Flutter implementation:
- Use `DM Sans` and `Lora` if already available and easy.
- If not, use Flutter defaults or another clean sans-serif first. Do not block the UI milestone on font setup.
- Keep Lora/serif limited to major headings such as `Today`.

Approximate Today heading:
- Text: `Today`.
- Font family: Lora / Georgia-like serif.
- Size: `32px` equivalent.
- Weight: `500`.
- Line height: about `1.2`.
- Colour: `#2C2A26`.

General UI text:
- Body/card title: `15px` to `16px`, medium.
- Secondary text: `12px` to `14px`, colour `#7A7568`.
- Section labels: `12px`, uppercase, medium, tracking wide, colour `#7A7568`.
- Bottom nav label: around `10px`, medium.

## Shape and spacing system

Use a soft rounded system.

Suggested Flutter values:
- Page horizontal padding: `16`.
- Header top padding should respect safe area. Figma used roughly `48px` top on mobile.
- Section spacing: `16`.
- Small card spacing: `10` to `12`.
- Card border radius: `16` to `20`.
- Major cards: radius `20`/`rounded-2xl` equivalent.
- Circular icon containers: `32` to `40` square with full circle radius.
- Bottom nav height: about `64`, plus safe area padding.
- Activity row padding: horizontal `16`, vertical `14`.
- Check-in circle: `32 x 32`.
- Header calendar pill: horizontal padding `12`, vertical `6`, full pill radius.
- Profile circle: `36 x 36`.

Borders:
- Cards use a subtle `borderWarm` rather than heavy shadows.
- Prefer light borders and spacing over strong drop shadows.

## Today screen structure

The Today screen is a vertical mobile layout with fixed bottom navigation.

High-level structure:

1. Screen background: `#FAF7F2`.
2. Header row.
3. Greeting/title block.
4. Scrollable content with cards and sections.
5. Fixed bottom navigation.

### Header row

Layout:
- Horizontal row.
- Padding left/right: `16`.
- Top padding: safe area plus about `12`.
- Bottom padding: `8`.
- Main axis: space-between.

Left control: selected calendar pill.
- Text: `Kwame and Laura`.
- Chevron down icon.
- Background: `#EDE8E0`.
- Text colour: `#2C2A26`.
- Chevron colour: `#7A7568`.
- Font size: `14`.
- Font weight: medium.
- Rounded full pill.
- Padding: horizontal `12`, vertical `6`.

Right control: profile circle.
- Size: `36 x 36`.
- Background: `#EDE8E0`.
- Text: `K`.
- Text colour: `#C8603A`.
- Font size: `14`.
- Font weight: semi-bold.

### Greeting/title block

Padding:
- Left/right: `16`.
- Top: about `20`.
- Bottom: `4`.

Content:
- Heading: `Today`.
- Date line: `Thursday, 11 June`.

Date line:
- Font size: `14`.
- Colour: `#7A7568`.
- Top margin: about `2`.

### Scroll area

Scrollable content:
- Padding left/right: `16`.
- Top: `16`.
- Bottom: enough to clear fixed nav, about `128`.
- Vertical gap between sections/cards: `16`.

## Today screen cards/components

### Next up card

Purpose: warm hero card showing the next planned activity.

Container:
- Background: `#C8603A`.
- Border radius: `20`.
- Padding: `16`.
- Horizontal row.
- Gap: `16`.

Left icon circle:
- Size: `40 x 40`.
- Shape: circle.
- Background: white with opacity about `0.2`.
- Icon: Waves/water-like icon.
- Icon size: about `18`.
- Icon colour: white.

Text stack:
- Label: `NEXT UP`.
  - Uppercase.
  - Font size: `12`.
  - Medium.
  - Tracking wide.
  - Colour: white with about `70%` opacity.
- Title: `Walk waterfront`.
  - White.
  - Semi-bold.
  - Single line/truncate if needed.
- Time: `6:30 PM`.
  - Font size: `14`.
  - Colour: white with about `80%` opacity.

### Quick check-in card

Container:
- Background: `#FFFFFF`.
- Border: `rgba(44,42,38,0.08)`.
- Border radius: `20`.
- Padding: `16`.

Top content row:
- Icon circle: `32 x 32`, background `#EEF6F2`.
- Icon/text: `◐`, colour `#6A9E88`, font size around `16`.
- Title: `3 past activities need a quick check-in`.
  - Font size: `14`.
  - Font weight: medium.
  - Colour: `#2C2A26`.
- Helper: `No typing needed — just tap to mark how it went.`
  - Font size: `12`.
  - Colour: `#7A7568`.

Button row:
- Top margin: `12`.
- Horizontal gap: `8`.
- Two equal-width buttons.

Primary check-in button:
- Text: `Check in`.
- Background: `#6A9E88`.
- Text: white.
- Height/padding: about `40` to `44`.
- Rounded full pill.
- Font size: `14`.
- Medium.

Secondary later button:
- Text: `Later`.
- Transparent background.
- Border: `rgba(44,42,38,0.15)`.
- Text colour: `#7A7568`.
- Rounded full pill.

### This week summary card

Container:
- Background: `#FFFFFF`.
- Border: `rgba(44,42,38,0.08)`.
- Border radius: `20`.
- Padding: `16`.

Section label:
- Text: `THIS WEEK`.
- Uppercase.
- Font size: `12`.
- Medium.
- Tracking wide.
- Colour: `#7A7568`.
- Bottom margin: about `12`.

Three stats, evenly spaced:
- Planned: value `5`, colour `#2C2A26`.
- Done: value `2`, colour `#6A9E88`.
- Partly: value `1`, colour `#C8943A`.

Stat value:
- Font size: `24`.
- Semi-bold.
- Line height: `1`.

Stat label:
- Font size: `12`.
- Colour: `#7A7568`.
- Top margin: `4`.

Progress bar:
- Top margin: `12`.
- Height: `6`.
- Rounded full.
- Track background: `#EDE8E0`.
- Fill width: `40%`.
- Fill gradient: left `#6A9E88`, right `#C8943A`.

### Quick actions section

Section label:
- Text: `QUICK ACTIONS`.
- Uppercase.
- Font size: `12`.
- Medium.
- Tracking wide.
- Colour: `#7A7568`.
- Bottom margin: `10`.

Grid:
- Two columns.
- Gap: `10`.

Action card:
- Background: `#FFFFFF`.
- Border: `rgba(44,42,38,0.08)`.
- Border radius: `20`.
- Padding: `16`.
- Row layout.
- Gap: `10`.
- Text align left.

Action icon circle:
- Size: `32 x 32`.
- Circle.
- Background uses accent colour with low opacity, about `9%` to `12%`.
- Icon size: `16`.

Actions:

| Label | Icon intent | Accent |
| --- | --- | --- |
| Add activity | Plus | `#C8603A` |
| Generate week | Zap/lightning | `#6A9E88` |
| View plan | Calendar | `#8BB4C8` |
| View progress | Trending/chart | `#B08EA0` |

Action label:
- Font size: `14`.
- Medium.
- Colour: `#2C2A26`.

### Today's plan section

Section header row:
- Left label: `TODAY'S PLAN`.
- Right text button: `See all`.

Left label:
- Uppercase.
- Font size: `12`.
- Medium.
- Tracking wide.
- Colour: `#7A7568`.

Right button:
- Font size: `12`.
- Medium.
- Colour: `#C8603A`.

Activity list:
- Vertical gap: `10`.

Activity card:
- Background: `#FFFFFF`.
- Border: `rgba(44,42,38,0.08)`.
- Border radius: `20`.
- Padding: horizontal `16`, vertical `14`.
- Row layout.
- Gap: `12`.
- If skipped, opacity about `0.55` and title has line-through.

Left icon circle:
- Size: `36 x 36`.
- Shape: circle.
- Background: `#FAF7F2`.
- Icon size: `16`.

Activity examples:

| Activity | Time | Category | Status | Icon intent | Icon colour |
| --- | --- | --- | --- | --- | --- |
| Cafe reading | `11:00 AM` | Creative | Done | Book | `#C8603A` |
| Walk waterfront | `6:30 PM` | Outside | None | Waves/water | `#6A9E88` |
| Cook together | `8:00 PM` | Couple time | None | Food/utensils | `#C87888` |

Activity title:
- Font size: `15`.
- Medium.
- Line height tight.
- Colour: `#2C2A26`.

Metadata row:
- Top margin: `4`.
- Wrap allowed.
- Gap: `8`.
- Time text colour: `#7A7568`.
- Time font size: `12`.
- Category chip beside time.

Right check-in circle:
- Size: `32 x 32`.
- Does not shrink.

## Check-in circle states

The check-in circle cycles through states in the Figma prototype:

`none → done → partly → skipped → none`

Flutter does not need real state persistence yet; mock local state is okay.

### None state

- Size: `32 x 32`.
- Circle.
- Border: `2px` equivalent, `borderWarm`.
- Background: transparent.
- Inside: small centre dot, `8 x 8`, background `borderWarm`.
- Hover state from web can be ignored on mobile, but pressed feedback is useful.

### Done state

- Size: `32 x 32`.
- Circle.
- Border: `#6A9E88`.
- Background: `#6A9E88`.
- Icon: check mark.
- Icon colour: white.
- Icon size: about `14`.
- Stroke weight: visually bold.

### Partly state

- Size: `32 x 32`.
- Circle.
- Border: `#C8943A`.
- Background: sand with low opacity, about `20%`.
- Content: `◐`.
- Text colour: `#C8943A`.
- Font size: `12`.
- Bold.

### Skipped state

- Size: `32 x 32`.
- Circle.
- Border: `borderWarm`.
- Background: transparent.
- Content: `○`.
- Text colour: `#7A7568`.
- Font size: `12`.

## Bottom navigation

Fixed bottom nav.

Container:
- Position: bottom.
- Height: about `64`, plus safe area bottom.
- Background: `#FFFFFF`.
- Top border: `rgba(44,42,38,0.08)`.
- Items stretch evenly across full width.

Items:
1. Today
2. Plan
3. Activities
4. Progress
5. Settings

Active item:
- Colour: `#C8603A`.
- Icon slightly scaled up, about `1.08`.
- Label colour matches active.

Inactive item:
- Colour: `#7A7568`.

Icon size:
- About `22 x 22`.

Label:
- Font size: `10`.
- Font weight: medium.
- Line height tight.

Suggested icon intents:
- Today: clock/circle-time.
- Plan: calendar.
- Activities: list.
- Progress: bar chart.
- Settings: gear.

Do not add Export, Publish, Check-in, Calendar switcher, or AI to the bottom navigation.

## Reusable Flutter widgets to create first

Create these before building the full Today screen:

1. `AppScaffold`
   - Background cream.
   - Optional fixed bottom nav.
   - Safe area handling.

2. `LifeShuffleHeader`
   - Calendar selector pill.
   - Profile circle.

3. `LsCard`
   - White card.
   - Rounded radius.
   - Subtle border.
   - Standard padding.

4. `CategoryChip`
   - Uses category colour table.

5. `CheckInCircle`
   - Implements none/done/partly/skipped visual states.

6. `QuickActionCard`
   - Reusable two-column action card.

7. `BottomNavShell`
   - Five fixed navigation items.

8. `ActivityPlanCard`
   - Icon circle.
   - Activity title/time/category.
   - Check-in circle.

## Mock data for first UI pass

Use this data to reproduce the Figma Today screen.

```dart
final todayActivities = [
  ActivityMock(
    id: '1',
    title: 'Cafe reading',
    time: '11:00 AM',
    category: 'Creative',
    status: CheckStatus.done,
  ),
  ActivityMock(
    id: '2',
    title: 'Walk waterfront',
    time: '6:30 PM',
    category: 'Outside',
    status: CheckStatus.none,
  ),
  ActivityMock(
    id: '3',
    title: 'Cook together',
    time: '8:00 PM',
    category: 'Couple time',
    status: CheckStatus.none,
  ),
];
```

Other Today screen mock values:
- Selected calendar: `Kwame and Laura`.
- Profile initial: `K`.
- Date: `Thursday, 11 June`.
- Next up: `Walk waterfront`, `6:30 PM`.
- Check-in nudge: `3 past activities need a quick check-in`.
- Helper text: `No typing needed — just tap to mark how it went.`
- Weekly stats: Planned `5`, Done `2`, Partly `1`.
- Progress fill: `40%`.

## Placeholder screens after Today

After Today is built, create simple placeholder/static screens using the same shell and visual style:

- Plan
- Activities
- Progress
- Settings
- Onboarding

These should not be blank grey pages. They should use the same Life Shuffle header, cream background, white cards, terracotta/sage accents, and plain-language copy from the master plan.

Do not overbuild these screens in the first pass. They are there so the user can navigate the app and judge the overall structure.

## Do not do in this milestone

Do not implement yet:
- Firebase setup.
- Firestore schema.
- Google sign-in.
- Auth gate.
- Real planner generation logic.
- Calendar publishing / ICS feed.
- Export / PDF generation.
- Real persistence.
- Notifications.
- AI screens.
- Public/social features.

The current goal is visual confidence and navigable Flutter structure.

## Definition of done for first UI milestone

The first UI milestone is done when:

- The Flutter app runs locally.
- The user can view the app in browser or emulator.
- Bottom navigation switches between Today, Plan, Activities, Progress, and Settings.
- Today screen closely matches the Figma-derived handoff.
- The other main screens exist as warm, styled placeholders.
- No backend setup is required to run it.
- The app uses mock data only.
- No product scope has been added beyond the docs.
