# 19 - Notation Rendering Pipeline Design

## Purpose

This document is the source of truth for the current Drumcabulary notation
rendering pipeline.

It describes how authored exercise notation moves from YAML into Flutter
models, sheet notation display, audio preview, and print/export.

It does not define the full lesson YAML schema or data architecture. That is
owned by:

- `docs/20_LESSON_YAML_DATA_ARCHITECTURE.md`

It does not define the notation language grammar. Grammar, token meaning,
metadata meaning, valid examples, and invalid examples are owned by:

- `docs/18_NOTATION_LANGUAGE_CONTRACT.md`

If another document appears to define rendering behavior differently, treat this
file as authoritative for the rendering pipeline and update the competing
document to reference this one.

## Current Product Boundary

The rendering pipeline serves authored lesson exercises. It is not currently a
full user-facing notation authoring system.

Supported rendering goals:

- render YAML-authored exercise notation on Lesson Detail
- render the same exercise notation into printable/exportable PDF content
- provide a lightweight "Hear It" preview from rendered examples
- allow Lesson Detail to control Hear It and Play Along preview BPM from the
  fixed practice footer
- preserve authored grouping spaces as visual phrasing aids
- preserve computed measures for display and print
- render one or more YAML-authored sections inside a single exercise
- render optional sticking only when authored

Not currently supported:

- explicit measure separators in notation text
- sections encoded inside one notation string
- user notation editing in Coach
- full practice transport controls
- assessment or recommendation rendering

## Authority Map

| Concern | Authority |
| --- | --- |
| Lesson YAML schema and data architecture | `docs/20_LESSON_YAML_DATA_ARCHITECTURE.md` |
| Notation grammar and YAML authoring rules | `docs/18_NOTATION_LANGUAGE_CONTRACT.md` |
| Rendering pipeline and display/export architecture | this document |
| Screen content and flow | `docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md` |
| Web sheet runtime operational notes | `web/sheet_notation/README.md` |

## Pipeline Summary

```text
assets/content/index.yaml
  -> listed lesson YAML files
  -> LessonContentLibrary
  -> Lesson / LessonExercise / ExerciseNotationSection
  -> LessonDetailScreen exercise card
  -> lesson_notation_document.documentForNotationSection(...)
  -> DrumSheetNotationDocument.fromPattern(...)
  -> DrumSheetPatternParser.parse(...)
  -> computed DrumSheetNotationMeasure list
  -> _documentJson(...)
  -> WebView payload
  -> web/sheet_notation/app_host.html
  -> web/sheet_notation/app_renderer.js
  -> renderDrumNotationSvgWithMetadata(...)
  -> VexFlow SVG + Drumcabulary note metadata
  -> shared semantic selection and active-event overlays in app_host.html
```

Print/export uses the same parser, document JSON, WebView host, generated JS
bundle, and SVG renderer, then embeds returned SVG into a PDF.

Audio preview uses the same `DrumSheetNotationDocument`, but it does not use
VexFlow. It converts the document directly into playback tokens, timing spans,
voices, and active-event frames.

Selection state is semantic, not coordinate-based. Flutter passes flattened
notation event indexes and a selection purpose into the WebView host. The host
resolves those stable event indexes against the current VexFlow SVG after each
render, then draws a translucent rounded event rectangle and notehead glow.
Interactive editing, pattern-string selection sync, audio preview active-event
display, and Guided Practice highlighting all use this same event-index path.

## YAML Source

Primary lesson content:

- `assets/content/index.yaml`
- `assets/content/lessons/<level>/<skill>/<lesson>.yaml`

Relevant model files:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`
- `lib/features/coach/lesson_notation_document.dart`

Each YAML exercise owns one `notation` block.

The notation block can be single-section:

```yaml
notation:
  subdivision: 8
  time_signature: "4/4"
  repeat_count: 4
  pattern: "[HH] [HH] [HH] [HH] [HH] [HH] [HH] [HH]"
```

Or sectioned:

```yaml
notation:
  sections:
    - title: Money Beat
      subdivision: 8
      time_signature: "4/4"
      repeat_count: 3
      pattern: "[HH K] [HH] [HH S] [HH] [HH K] [HH] [HH S] [HH]"
    - title: Triplet Fill
      subdivision: triplet
      time_signature: "4/4"
      repeat_count: 1
      pattern: "[S:RL][K] [S:R][K][S:L] [S:R(L)(L)] [CR K]"
```

The loader normalizes the single-section form into one
`ExerciseNotationSection` so rendering can operate on a single section list.

Current section rendering fields:

- `title`
- `pattern`
- `subdivision`
- `timeSignature`
- `repeatCount`
- `sticking`

Each `ExerciseNotationSection.pattern` is rendered as one isolated notation
example. One exercise can therefore display multiple notation examples when it
authors multiple sections.

One notation field can become multiple computed measures, but section
boundaries are authored in YAML, not inside the notation string.

## Lesson Detail Path

Primary file:

- `lib/features/coach/lesson_detail_screen.dart`

The lesson detail screen renders one full active exercise card at a time. The
top exercise navigator selects which `LessonExercise` is active; non-active
exercises are not rendered as duplicate expanded or collapsed rows below the
card.

Each section creates a `DrumSheetNotationDisplay` with:

- `documentForNotationSection(section)`
- section subdivision mapped to `DrumSheetNoteValue`
- section `subdivision: triplet` mapped to `DrumSheetFeel.triplet`
- section time signature
- section repeat count
- lesson preview BPM
- grouping inferred from top-level spaces in the section pattern string
- `showSticking` only when the section authors `sticking`
- `compactLayout: false`
- `preserveMeasures: false` so longer active patterns can wrap vertically
- `minNoteWidth: 54`
- `audioPreviewEnabled: true`
- `showAudioPreviewControl: false`, because Lesson Detail's footer owns Hear It
- tighter staff layout overrides so the notation sheet does not carry excessive
  top and bottom padding

Raw notation strings are not shown as the student-facing display. Rendering
failures should remain visible; the app should not silently replace failed sheet
rendering with raw notation strings.

## Dart Notation Document

Primary file:

- `lib/features/practice/widgets/sheet_notation_display.dart`

`DrumSheetNotationDocument.fromPattern(...)` performs the first rendering-stage
transformation.

Inputs:

- authored pattern string
- subdivision
- feel
- time signature
- repeat count
- lenient parsing flag

Output:

- `DrumSheetNotationDocument`
- `DrumSheetNotationMeasure` list
- flattened note access for playback/selection

The document stores:

- `subdivision`
- `feel`
- `timeSignature`
- `repeatCount`
- `measures`

## Parsing

`DrumSheetPatternParser.parse(...)` converts pattern text into
`DrumSheetNotationNote` objects.

The parser understands the notation grammar defined in:

- `docs/18_NOTATION_LANGUAGE_CONTRACT.md`

Current lesson display and print paths pass `lenient: true` when constructing
display documents. The content loader validates authored YAML notation before
the UI sees it.

## Measure Calculation

After parsing, `_measuresForNotes(...)` splits the parsed note list by computed
notes-per-measure.

The measure size is derived from:

- `timeSignature`
- `subdivision`
- `feel`

Examples:

- `4/4` + eighth notes -> 8 note slots per measure
- `4/4` + sixteenth notes -> 16 note slots per measure
- `4/4` + eighth-note triplet feel -> 12 note slots per measure
- `4/4` + sixteenth-note triplet feel -> 24 note slots per measure

This is automatic. The pattern text does not currently contain explicit measure
markers.

If the note count is shorter than one measure, the document contains one
measure. If longer, the list is chunked into multiple measures.

## Grouping Extraction

Top-level spaces in the pattern string are converted into a grouping string for
the renderer.

Examples:

```text
RLRLL K RLRLL RLRLL X -> grouping "5 1 5 5 1"
RLR LRL -> grouping "3 3"
```

Grouping spaces inside bracket overrides are ignored for grouping extraction.

Grouping controls beams, visual phrase gaps, and wrapping. It does not alter
timing or measure calculation.

## Sticking

Sticking is optional authored display metadata on an
`ExerciseNotationSection`.

Rules:

- if `sticking` exists, render it
- if `sticking` does not exist, do not invent or render sticking
- do not use `show_sticking` or `hide_sticking` YAML flags
- sticking is display metadata, not timing metadata

The display path gets the sticking labels from the section, not from parsed
notation tokens.

## Triplets

Triplets are metadata-driven.

```yaml
subdivision: triplet
```

This maps to:

- eighth-note subdivision value for note sizing
- `DrumSheetFeel.triplet` for timing/rendering
- visible triplet grouping marks where the renderer can group notes

Rudiment content may use `subdivision: 16_triplet` when a quarter-note pulse
contains six evenly spaced strokes. This maps to:

- sixteenth-note subdivision value for note sizing
- `DrumSheetFeel.triplet` for timing/rendering
- visible sextuplet grouping marks where the renderer can group six notes

The notation parser does not infer triplets from spaces, titles, or grouping
counts.

## Flutter Display Widget

Primary widget:

- `DrumSheetNotationDisplay`

Primary file:

- `lib/features/practice/widgets/sheet_notation_display.dart`

The widget owns:

- WebView controller setup
- render payload generation
- selection channel handling
- height channel handling
- audio preview button and lifecycle
- active-event frame calculation and WebView updates

The lesson display path uses the WebView/VexFlow renderer. Rendering failures
must surface as renderer failures; Drumcabulary does not substitute a native
fallback painter or raw notation string in production lesson views.

## Web Render Host

Primary files:

- `web/sheet_notation/app_host.html`
- `web/sheet_notation/app_renderer.js`
- `web/sheet_notation/renderer.js`

The Flutter widget sends a JSON document payload to the host. The host calls the
renderer, receives an SVG plus note-position metadata, then reports height and
metadata back to Flutter.

The note-position metadata is also used for:

- note selection overlays in editor-oriented contexts
- active-event alignment during Hear It preview

## System Width And Density

The renderer treats available screen width as a wrapping constraint, not as a
request to justify sparse notation across the full container.

Current MVP rules:

- note density is based on renderer spacing tokens such as `noteSpacing`,
  `groupGap`, and `systemEndReserve`
- compact lesson notation uses wider note spacing than diagnostic/editor
  previews so selection highlights have room around each rhythmic event
- a short measure keeps the same horizontal note spacing on narrow and wide
  screens
- available width limits the maximum formatter width and controls when systems
  wrap
- the time-signature reserve reduces the available formatter width for the
  first system, but it does not stretch sparse content
- phrase grouping spaces may add visual gaps, but they do not change timing

## Repeat Rendering

`repeatCount` is metadata on the notation document/section.

Current MVP rules:

- render an end-repeat bar when a repeat count is authored
- do not render a separate repeat-count text label in lesson detail
- audio preview and active-event highlighting should honor repeat count
- active-event highlighting should continue to the end of the written measure before wrapping

## Audio Preview

Primary file:

- `lib/features/practice/pattern_audio_service.dart`

Audio preview builds a playback plan from `DrumSheetNotationDocument`.

Important behavior:

- Lesson Detail owns BPM controls in the fixed practice footer and passes that
  value to each active `DrumSheetNotationDisplay`.
- Changing BPM while a notation preview is running stops the active preview so
  the next Hear It action starts at the selected tempo.
- notes in a simultaneous bracket share the same scheduled offset
- rests do not produce audible cues
- explicit voice overrides choose kit voices
- cymbal voices use cymbal sample handling
- ghost notes use reduced volume
- kick ignores ghost marking
- playback stops on inactive/hidden/paused/detached lifecycle states

Current default relative levels:

- kick: `1.0`
- normal non-cymbal hits: `0.8`
- ghosts: `0.1`

Audio preview is intentionally a lightweight teaching preview, not a full
practice transport.

## Print/Export Path

Primary files:

- `lib/features/coach/lesson_sheet_notation_svg_renderer.dart`
- `lib/features/coach/lesson_print_export_service.dart`

Print/share uses the same render path as the screen, but with a dedicated SVG
collection step:

1. `LessonSheetNotationSvgRenderer.renderLesson(...)` iterates lesson exercises.
2. Each `ExerciseNotationSection` is converted to `DrumSheetNotationDocument`.
3. The WebView/VexFlow renderer returns SVG for each section.
4. `LessonPrintExportService.buildLessonPdf(...)` embeds the section SVGs.
5. Missing rendered notation is treated as an export error, not silently replaced
   with raw pattern text.

The print service receives rendered notation keyed by exercise ID. A sectioned
exercise maps to multiple rendered SVG sections for that exercise.

## Failure Rules

Rendering failures should be visible.

Do not silently replace failed notation rendering with:

- raw pattern text
- placeholder bars
- alternate simplified notation

Fallbacks hide authoring or renderer defects and make the current app state
harder to evaluate.

## Current Limitations

- No explicit measure marker syntax in the notation language.
- No multi-exercise combined render surface.
- No persisted or exercise-specific BPM settings.
- No live practice session transport.
- No user notation editing in Coach.
- No PDF-specific notation renderer separate from the WebView/VexFlow path.
- No inference of sticking labels when omitted.
