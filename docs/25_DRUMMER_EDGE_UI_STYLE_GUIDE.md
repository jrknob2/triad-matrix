# Drummer Edge UI Style Guide

Drummer Edge is Drumcabulary's MVP visual direction for the Level -> Skill ->
Lesson teaching flow. It uses a high-contrast, drummer-focused interface with
user-selectable light/dark appearance and accent color.

## Design Goals

- Focused and high contrast in both dark and light appearance.
- Confident and modern without feeling cartoonish.
- Rock/drummer inspired, but still premium and readable.
- Burnt orange is the default accent for action, tempo, and progress, not a
  page fill. The accent is user configurable.
- Teaching content remains the priority; notation legibility wins over styling.

## Color Palette

| Role | Color |
| --- | --- |
| App background | `#0B0B0D` |
| Primary surface/card | `#141416` |
| Secondary surface | `#1F2023` |
| Border/divider | `#2C2D31` |
| Primary text | `#FFFFFF` |
| Secondary text | `#B5B5B8` |
| Muted text | `#8A8A8D` |
| Default accent | `#FF6A00` |
| Accent pressed/hover | derived from selected accent |
| Success/progress | selected accent unless a status requires another color |

## Typography

- Use the existing app font stack where possible.
- Large lesson titles use confident, readable weights and tight line height.
- Avoid ultra-heavy weights. Prefer `w600`/`w700` for emphasis instead of
  `w800`/`w900`.
- Breadcrumbs, section labels, and compact metadata labels use uppercase.
- Body copy stays readable, with no stylized treatment that slows reading.
- Avoid thin low-contrast gray text.

## Spacing

- Screen padding: 16 px on iPhone-sized layouts.
- Card padding: 16-20 px depending on density.
- Exercise card internal gaps: 8-16 px.
- Lesson Detail uses a fixed practice footer, so scrollable content should stay
  compact and avoid duplicating footer actions.

## Cards

- Use dark surfaces with subtle borders.
- Border radius: 8 px for card-like surfaces.
- Elevation is restrained and should be used only where it clarifies depth.
- Do not nest decorative cards inside decorative cards; notation may use a
  dedicated light panel only for legibility.

## Buttons

- Primary actions are solid and tappable.
- Orange is reserved for important affordances, especially playback and tempo.
- Secondary actions use dark surfaces with visible borders.
- Tap targets should stay at least 44 px.

## Chips

- Chips use dark secondary surfaces, border strokes, and strong label weight.
- Orange outline/text is preferred for tempo and lesson metadata.
- Status pills:
  - `Not Started`: secondary surface
  - `In Progress` / active practice: orange accent
  - `Complete`: orange accent unless a future status color system is added

## Lesson Headers

- Lesson Detail does not need a second app-bar title when the lesson title is
  already prominent in the header.
- Header content includes:
  - back navigation
  - MIDI and LED status chips when supported
  - orange breadcrumb, for example `BEGINNER • RUDIMENTS`
  - large bold lesson title
  - short overview copy
  - compact completion summary
  - restrained More Actions menu for Print Lesson
- Do not add separate lesson number, duration, or status pills unless they
  answer a concrete user question that is not already answered elsewhere.

## Exercise Cards

- Exercise number and title are prominent.
- Status pill appears in the header row.
- Only the active exercise renders as a full card.
- Goal, Focus, and Tip replace Why / What / How for student-facing labels.
- On wide layouts, Goal, Focus, and Tip align in one row directly above
  notation. On narrow layouts they stack.
- Tempo guidance and interactive BPM controls live in the fixed practice footer,
  not inside Tip.
- Practice It and Complete Exercise behavior must remain unchanged.

## Lesson Detail Practice Controls

- Lesson Detail uses a fixed footer for the primary practice controls:
  BPM, Practice It, Guided Practice, Hear It, and Play Along.
- The scrollable active exercise card must not duplicate these controls or add a
  sheet-local Hear It label/control.
- More Actions is restrained and contains only secondary lesson actions such as
  Print Lesson.

## Notation Display

- Notation must stay highly readable.
- Preferred future direction is a true dark notation renderer with light strokes.
- Current safe rule: on dark exercise cards, place notation on a dedicated light
  notation panel if dark rendering is not reliable.
- Notation panels must avoid edge collisions and wrap vertically when a pattern
  is too long for the available width.

## Accessibility Rules

- Maintain strong foreground/background contrast.
- Do not use orange as the only status indicator where text can clarify state.
- Preserve large tap targets.
- Keep long lesson titles and exercise text wrapping cleanly.
- Avoid low-opacity body text.

## Implementation Notes

- Centralize tokens in `DrumcabularyTheme`.
- Theme mode and accent color are profile settings and must be persisted with
  app data.
- Reuse shared components in `drumcabulary_ui.dart` instead of cloning surface
  styling in every screen.
- Apply the style first to Lesson Detail, then minimally to Level, Skill, and
  Lesson list screens.
- Do not change lesson data models, YAML schema, notation grammar, curriculum
  structure, or lesson content for this visual pass unless a small optional
  UI-facing field is already authored and needed by this contract.
