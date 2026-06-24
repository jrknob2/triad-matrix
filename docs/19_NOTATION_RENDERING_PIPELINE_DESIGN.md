# 19 - Notation Rendering Pipeline Design

## Purpose

This document is the source of truth for the current Drumcabulary notation
rendering pipeline.

It describes how authored lesson notation moves from YAML into Flutter models,
sheet notation display, audio preview, and print/export.

It does not define the notation language grammar. Grammar, token meaning,
metadata meaning, valid examples, and invalid examples are owned by:

- `docs/18_NOTATION_LANGUAGE_CONTRACT.md`

If another document appears to define rendering behavior differently, treat this
file as authoritative for the rendering pipeline and update the competing
document to reference this one.

## Current Product Boundary

The current product is a Coach lesson-plan MVP.

The rendering pipeline serves authored lesson content. It is not currently a
full user-facing notation authoring system.

Supported rendering goals:

- render YAML-authored lesson patterns on the lesson detail screen
- render the same patterns into printable/exportable PDF content
- provide a lightweight "hear notation" preview from rendered examples
- preserve authored grouping spaces as visual phrasing aids
- preserve computed measures for display and print

Not currently supported:

- explicit measure separators in pattern text
- named sections inside one `notation` field
- multiple notation blocks inside one `LessonPattern`
- rendering exercise `flow` as one combined notation sequence
- user notation editing in Coach
- live practice transport controls
- progress, assessment, or recommendation rendering

## Authority Map

| Concern | Authority |
| --- | --- |
| Notation grammar and YAML authoring rules | `docs/18_NOTATION_LANGUAGE_CONTRACT.md` |
| Rendering pipeline and display/export architecture | this document |
| Coach lesson-screen content and flow | `docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md` |
| MVP reset status | `docs/17_MVP_RESET_HANDOFF.md` |
| Web sheet runtime operational notes | `web/sheet_notation/README.md` |
| Historical grouping/warmup notes | `docs/10_NOTATION_GROUPING_AND_WARMUPS.md` |

## Pipeline Summary

```text
assets/lessons/flow_foundations.yaml
  -> LessonPlan / Lesson / LessonPattern
  -> LessonDetailScreen pattern row
  -> DrumSheetNotationDocument.fromPattern(...)
  -> DrumSheetPatternParser.parse(...)
  -> computed DrumSheetNotationMeasure list
  -> _documentJson(...)
  -> WebView payload
  -> web/sheet_notation/app_host.html
  -> web/sheet_notation/app_renderer.js
  -> renderDrumNotationSvgWithMetadata(...)
  -> VexFlow SVG + Drumcabulary note metadata
  -> selection/playhead overlays in app_host.html
```

Print/export uses the same parser, document JSON, WebView host, generated JS
bundle, and SVG renderer, then embeds the returned SVG into a PDF.

Audio preview uses the same `DrumSheetNotationDocument`, but it does not use
VexFlow. It converts the document directly into playback tokens, timing spans,
voices, and playhead events.

## YAML Source

Primary lesson asset:

- `assets/lessons/flow_foundations.yaml`

Relevant model files:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`

Each YAML `patterns[]` entry becomes one `LessonPattern`.

Current `LessonPattern` rendering fields:

- `id`
- `title`
- `role`
- `notation`
- `subdivision`
- `timeSignature`
- `repeatCount`

Each `LessonPattern.notation` field is rendered as one isolated example row.

One notation field can become multiple computed measures, but it is still one
pattern/example. The current schema does not represent sections or multiple
notation blocks inside one pattern.

## Lesson Detail Screen Path

Primary file:

- `lib/features/coach/lesson_detail_screen.dart`

The lesson detail screen renders one `_PatternBlock` per `LessonPattern`.

Each block creates a `DrumSheetNotationDisplay` with:

- `DrumSheetNotationDocument.fromPattern(pattern.notation, ...)`
- pattern subdivision mapped to `DrumSheetNoteValue`
- pattern `subdivision: triplet` mapped to `DrumSheetFeel.triplet`
- pattern time signature
- pattern repeat count
- grouping inferred from top-level spaces in the notation string
- `compactLayout: true`
- `minNoteWidth: 32`
- `audioPreviewEnabled: true`

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

### Parsing

`DrumSheetPatternParser.parse(...)` converts pattern text into
`DrumSheetNotationNote` objects.

The parser understands the notation grammar defined in
`docs/18_NOTATION_LANGUAGE_CONTRACT.md`.

Current lesson display and print paths pass `lenient: true`. That is current
implementation behavior, but it is not the preferred content-validation policy.
YAML should still be authored as valid strict notation. Tightening Coach YAML
loading to strict parse validation is a reasonable future cleanup.

### Measure Calculation

After parsing, `_measuresForNotes(...)` splits the parsed note list by computed
notes-per-measure.

The measure size is derived from:

- `timeSignature`
- `subdivision`
- `feel`

For example:

- `4/4` + eighth notes -> 8 note slots per measure
- `4/4` + sixteenth notes -> 16 note slots per measure
- `4/4` + eighth-note triplet feel -> 12 note slots per measure

This is automatic. The pattern text does not currently contain explicit measure
markers.

If the note count is shorter than one measure, the document contains one
measure. If longer, the list is chunked into multiple measures.

### Grouping Extraction

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
- playhead frame calculation and WebView updates
- native debug fallback painter

Important public inputs:

- `document`
- `grouping`
- `selectedIndexes`
- `onSelectionChanged`
- `selectable`
- `finalRepeat`
- `showSticking`
- `minNoteWidth`
- `compactLayout`
- `darkTheme`
- `debugUseNativeFallback`
- `audioPreviewEnabled`
- `audioPreviewBpm`
- `audioPreviewAccentVoice`

## WebView Render Payload

`DrumSheetNotationDisplay` serializes the Dart document into JSON with
`_documentJson(...)`.

The JSON includes:

- `subdivision`
- `feel`
- `timeSignature`
- optional `repeatCount`
- `measures[].notes[]`

Each note may include:

- `value`
- `voices`
- `rest`
- `sticking`
- `accent`
- `flam`
- `ghost`
- `tie`

The WebView payload includes:

- `document`
- `selectedIndexes`
- `options`

Current compact-layout options include:

- `availableWidth`
- `finalRepeat`
- `grouping`
- `minNoteWidth`
- `preserveMeasures: true`
- `staffY`
- `staffHeight`
- `systemGapY`
- `paddingRight`
- `systemEndReserve`
- `timeSignatureReserve`
- `noteSpacing`
- `groupGap`
- `stemLength`

`preserveMeasures: true` is important. It tells the JS renderer to preserve the
computed Dart measures as visual systems instead of flattening everything into
auto-wrapped chunks.

## WebView Host

Primary file:

- `web/sheet_notation/app_host.html`

The WebView host loads:

- `web/sheet_notation/vendor/vexflow.js`
- `web/sheet_notation/app_renderer.js`

The host exposes:

```js
globalThis.DrumcabularySheetNotation.render(payload)
globalThis.DrumcabularySheetNotation.setSelection(selected)
globalThis.DrumcabularySheetNotation.setPlayhead(state)
```

The host owns:

- rendering pending payloads when JS initializes late
- dark/light background setup
- calling `renderDrumNotationSvgWithMetadata(...)`
- injecting returned SVG into `#notation`
- collecting rendered note targets
- click/tap selection
- selection overlay
- playhead overlay
- height reporting back to Flutter
- visible render errors

Flutter channels used by the host:

- `SheetSelection`
- `SheetHeight`

The host does not define notation grammar. It consumes render-ready JSON and
runtime options.

## Generated Web Renderer Bundle

Source files:

- `web/sheet_notation/duration.js`
- `web/sheet_notation/voice_mapping.js`
- `web/sheet_notation/document.js`
- `web/sheet_notation/renderer.js`

Generated file:

- `web/sheet_notation/app_renderer.js`

Build command:

```sh
npm run build:sheet-notation-app
```

Do not edit `app_renderer.js` by hand.

`build_app_renderer_bundle.mjs` concatenates the source files into a plain
script bundle usable by the Flutter WebView asset host.

## JavaScript SVG Renderer

Primary file:

- `web/sheet_notation/renderer.js`

Entry points:

```js
renderDrumNotationSvg(documentJson, options)
renderDrumNotationSvgWithMetadata(documentJson, options)
```

Rendering stages:

1. Validate/normalize render document with `parseDrumNotationDocument(...)`.
2. Resolve VexFlow implementation.
3. Merge provided render options with `DEFAULT_RENDER_OPTIONS`.
4. Build notation systems from document measures and grouping.
5. Create an SVG renderer and VexFlow context.
6. For each system:
   - create a `VF.Stave`
   - add time signature on the first system
   - set end-repeat bar on the final system when enabled
   - map each note to `VF.StaveNote`
   - create a non-strict `VF.Voice`
   - format notes with `VF.Formatter`
   - apply group spacing
   - create beams
   - create triplets when document feel is `triplet`
   - draw voice, beams, tuplets
   - append sticking labels as SVG text
7. Return SVG markup and Drumcabulary note metadata.

### Systems And Measures

When `preserveMeasures: true`, each computed Dart measure is rendered as a
separate system.

When `preserveMeasures` is false, the renderer may split systems by
`notesPerSystem`, `availableWidth`, and grouping.

The lesson screen and print path currently pass `preserveMeasures: true`.

### Time Signature

The renderer adds `document.timeSignature` only to the first system.

The old `||` placeholder behavior should not be used as a time signature
substitute.

### Repeat Bars

When `finalRepeat: true`, the renderer sets an end-repeat bar on the final
system.

Current MVP display does not render repeat-count text labels such as `4x`.

`repeatCount` still matters for audio preview repetition.

### Beams And Group Spacing

Grouping is parsed from the `grouping` render option.

Groups control:

- beam breaks
- extra x-shift after group boundaries
- wrapping when auto systems are used

`avoidSingleNoteFlags` currently removes some grouping-implied beam breaks when
they would create isolated flagged notes.

### Triplets

Triplet display comes from `document.feel === 'triplet'`.

The renderer creates VexFlow tuplets over groups of three eighth-note entries.

Triplet behavior is display/timing metadata, not syntax inside the pattern
string.

### Sticking Labels

The renderer stores the sticking label on the VexFlow note, then appends labels
as SVG text after VexFlow draws the note.

This is currently separate from VexFlow's built-in annotation flow because the
app needs labels above the staff and aligned with final note positions.

Known issue:

- On iOS/WebView, sticking-label visual alignment is still not fully correct.
  This is a renderer defect, not a notation-language issue.

## Selection And Playhead Overlay

`renderDrumNotationSvgWithMetadata(...)` returns note metadata with note indexes
and selection geometry.

The WebView host uses metadata and SVG element bounds to build
`selectionTargetsByIndex`.

Selection:

- tapping a note toggles its selected index
- tapping empty staff space clears selection
- host posts selection back to Flutter through `SheetSelection`

Playhead:

- Flutter computes current/next token index and progress
- Flutter sends playhead state to WebView
- host draws a vertical SVG line over the current system
- if the next note is on another system or loops, the line extends toward the
  end of the current system before cycling

The playhead is an overlay. It does not alter the SVG note layout.

## Audio Preview Pipeline

Primary file:

- `lib/features/practice/widgets/sheet_notation_display.dart`

Audio services:

- `lib/features/practice/pattern_audio_service.dart`
- `lib/features/practice/pattern_playback_scheduler.dart`

The audio preview starts from the same `DrumSheetNotationDocument` used for
rendering.

It does not consume the SVG or VexFlow output.

Stages:

1. `_audioPlanForDocument(...)` flattens measures and visible note indexes.
2. The plan expands `repeatCount` into repeated playback tokens.
3. Each sheet note maps to:
   - `PatternTokenV1`
   - `PatternNoteMarkingV1`
   - primary `DrumVoiceV1`
   - optional additional voices
   - explicit timing span
4. `PatternPlaybackSchedulerV1.buildPlan(...)` creates playback events.
5. `PatternAudioService.start(...)` schedules samples.
6. A `Stopwatch` plus periodic timer computes playhead frames.
7. Frames are sent to the WebView host for overlay rendering.

Current defaults:

- `audioPreviewBpm`: `92`
- one active notation preview at a time
- preview stops when app lifecycle becomes inactive, hidden, paused, or detached

Current mixer defaults:

- kick: `1.0`
- normal non-cymbal: `0.8`
- normal cymbal: `0.8`
- ghost: `0.1`
- accent: `1.0`
- kick ignores ghost marking

Current playback behavior:

- preview prepares only samples required by the selected notation
- stale delayed cue callbacks are skipped to avoid catch-up bursts
- exercise tempo is displayed as lesson guidance, not used as a live speed
  control
- eighth, sixteenth, and triplet-eighth patterns share the same written-bar
  cursor speed at the fixed preview BPM
- pattern `repeat_count` is honored by preview audio and playhead movement
- playhead continues through line/bar ends before wrapping or looping

Current boundary:

- the ear icon is a preview action, not a practice transport
- no visible BPM controls yet
- no session/progress state

Remaining caveat:

- timer-based one-shot sample playback is adequate for MVP preview, but it is
  not a production-grade sequencer

## Print And Share Pipeline

Primary files:

- `lib/features/coach/lesson_print_export_service.dart`
- `lib/features/coach/lesson_sheet_notation_svg_renderer.dart`

Print/share uses the same render path as the screen, but with a dedicated
WebView controller that returns SVG strings.

Stages:

1. `LessonPrintExportService.printLesson(...)` or `shareLessonPdf(...)` starts
   export.
2. `LessonSheetNotationSvgRenderer` loads `web/sheet_notation/app_host.html`.
3. Each `LessonPattern` is converted to `DrumSheetNotationDocument`.
4. The document is serialized with `_documentJson(...)`.
5. JS calls `renderDrumNotationSvgWithMetadata(...)`.
6. The returned SVG is validated.
7. `LessonPrintExportService.buildLessonPdf(...)` embeds each SVG with
   `pw.SvgImage`.

The PDF builder requires a rendered SVG for every lesson pattern. Missing
pattern SVGs throw an error.

Raw Drumcabulary notation strings should not replace failed sheet rendering in
the PDF.

## Native Fallback Renderer

Primary file:

- `lib/features/practice/widgets/sheet_notation_display.dart`

The native fallback path is selected with:

```dart
debugUseNativeFallback: true
```

It uses a Flutter `CustomPainter` and `_SheetLayout`.

Current role:

- debug/test fallback
- not the normal lesson MVP render path

Known limitation:

- it does not match the WebView/VexFlow renderer feature-for-feature

Do not use fallback behavior as the authority for notation language or primary
rendering design.

## Error Behavior

Screen render path:

- WebView host catches JS render errors
- errors are shown inside the notation area as `<pre class="error">...`
- height is still posted to Flutter

Print path:

- WebView load has a timeout
- failed host load completes with an error
- non-SVG renderer output throws
- missing pattern SVGs throw before PDF completion

Current implementation caveat:

- lesson display and print use lenient parser mode when converting pattern
  strings. This can hide malformed authored YAML. The language contract expects
  authored YAML to be valid strict notation.

## Current Limitations And Known Issues

Current limitations:

- one YAML `notation` field renders as one pattern example
- no explicit notation syntax for measures
- no explicit notation syntax for sections
- no first-class render model for exercise flows
- no render-time section labels
- no repeat-count label text
- no user-facing BPM control for preview
- no fallback from print-render failure to raw notation

Known defects or rough edges:

- sticking-label alignment is still visually wrong in some iOS/WebView cases
- PDF pattern blocks constrain SVG height and may need layout review for longer
  multi-measure examples
- strict YAML validation has not been fully enforced at load time

## Tests And Verification

Primary tests:

- `test/sheet_notation_display_test.dart`
- `test/sheet_notation/sheet_notation.test.mjs`
- `test/lesson_plan_loader_test.dart`
- `test/lesson_print_export_service_test.dart`
- `test/pattern_audio_service_test.dart`

Useful commands:

```sh
npm run test:sheet-notation
flutter analyze
flutter test test/sheet_notation_display_test.dart test/lesson_print_export_service_test.dart
```

Regenerate WebView bundle after JS source edits:

```sh
npm run build:sheet-notation-app
```

## Design Rules For Future Changes

1. Update `docs/18_NOTATION_LANGUAGE_CONTRACT.md` before changing grammar.
2. Update this document before changing pipeline ownership or render stages.
3. Keep the screen and print paths on the same renderer unless there is a
   documented reason to diverge.
4. Do not add fallback raw notation strings that hide render failures.
5. Add explicit schema for sections or multi-block patterns instead of
   overloading spaces.
6. Treat rendering bugs as rendering bugs; do not mutate the language to work
   around VexFlow/WebView layout defects.
7. Regenerate `app_renderer.js` after editing JS renderer sources.
