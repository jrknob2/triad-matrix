# Drummer Edge UI Style Guide

Drummer Edge is Drumcabulary's MVP visual direction for the Level -> Skill ->
Lesson teaching flow. It replaces the washed-out cream/card look with a dark,
high-contrast, drummer-focused interface.

## Design Goals

- Dark, focused, and high contrast.
- Confident and modern without feeling cartoonish.
- Rock/drummer inspired, but still premium and readable.
- Orange is an accent for action, tempo, and progress, not a page fill.
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
| Accent orange | `#FF6A00` |
| Accent orange pressed | `#FF8C42` |
| Success/progress | `#FF6A00` unless a status requires another color |

## Typography

- Use the existing app font stack where possible.
- Large lesson titles use heavy weights and tight line height.
- Breadcrumbs, section labels, and compact metadata labels use uppercase.
- Body copy stays readable, with no stylized treatment that slows reading.
- Avoid thin low-contrast gray text.

## Spacing

- Screen padding: 16 px on iPhone-sized layouts.
- Card padding: 16-20 px depending on density.
- Exercise card internal gaps: 8-16 px.
- Add enough bottom inset so the sticky BPM footer does not cover content.

## Cards

- Use dark surfaces with subtle borders.
- Border radius: 8 px for card-like surfaces.
- Elevation is restrained and mostly used for the sticky footer.
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

- App bar remains dark with centered lesson title.
- Header content includes:
  - orange breadcrumb, for example `BEGINNER • RUDIMENTS`
  - large bold lesson title
  - overview/objective copy
  - lesson number and duration chips
  - full-width Print Lesson button with print icon
- Optional decorative treatment can use a subtle dark gradient, but not custom
  artwork unless it is already available.

## Exercise Cards

- Exercise number and title are prominent.
- Status pill appears in the header row.
- Why / What / How / Success labels are bold and readable.
- Tempo guidance appears as an orange-accent chip.
- Hear It remains attached to each rendered notation example.
- Practice It and Complete Exercise behavior must remain unchanged.

## Sticky BPM Footer

- Footer is a dark elevated surface.
- Layout:
  - metronome/reset control on the left
  - BPM decrement / value / increment in the center
  - orange play/tempo accent on the right
- Current BPM value is large and orange.
- Footer must not cover lesson content; scroll views need bottom padding.

## Notation Display

- Notation must stay highly readable.
- Preferred future direction is a true dark notation renderer with light strokes.
- Current safe rule: on dark exercise cards, place notation on a dedicated light
  notation panel if dark rendering is not reliable.
- Notation panels must avoid edge collisions and footer overlap.

## Accessibility Rules

- Maintain strong foreground/background contrast.
- Do not use orange as the only status indicator where text can clarify state.
- Preserve large tap targets.
- Keep long lesson titles and exercise text wrapping cleanly.
- Avoid low-opacity body text.

## Implementation Notes

- Centralize tokens in `DrumcabularyTheme`.
- Reuse shared components in `drumcabulary_ui.dart` instead of cloning surface
  styling in every screen.
- Apply the style first to Lesson Detail, then minimally to Level, Skill, and
  Lesson list screens.
- Do not change lesson data models, YAML schema, notation grammar, curriculum
  structure, or lesson content for this visual pass unless a small optional
  UI-facing field is already authored and needed by this contract.
