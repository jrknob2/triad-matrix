# 20 - Lesson YAML Data Architecture

## Purpose

This document is the source of truth for the current Coach lesson YAML file
structure and the data architecture built from it.

It covers:

- the bundled lesson asset shape
- required and optional YAML fields
- how YAML maps into Dart models
- how lesson, pattern, exercise, tempo, and flow data relate
- current validation behavior
- current consumers in list, detail, print/export, notation rendering, and
  audio preview
- known schema limits and future extension points

It does not redefine Drumcabulary notation grammar. Pattern notation syntax is
owned by:

- `docs/18_NOTATION_LANGUAGE_CONTRACT.md`

It also does not redefine the notation rendering pipeline. Rendering is owned by:

- `docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md`

If another document describes lesson YAML differently, treat this document as
authoritative for the YAML data architecture and update the competing document
to reference this one.

## Current Product Boundary

The current product is a Coach lesson-plan MVP.

Lesson content is authored by the app/content author in bundled YAML. Users do
not author, edit, save, complete, or track lessons in the MVP.

The YAML is content-first and print-first. It supports:

- an ordered lesson plan
- lesson objectives and coaching text
- authored pattern examples
- rendered sheet notation
- lightweight notation audio preview
- printable lesson output
- exercise guidance with optional tempo, subdivision, and flow metadata

The YAML does not currently support:

- live practice-session state
- per-user progress or completion
- assessment results
- recommendation data
- user-specific overrides
- multiple lesson plans in a runtime index
- remote lesson loading
- explicit measure or section objects inside one pattern

## Source Files

Primary asset:

- `assets/lessons/flow_foundations.yaml`

Asset registration:

- `pubspec.yaml`

Dart data model and loader:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`

Primary consumers:

- `lib/features/today/today_screen.dart`
- `lib/features/coach/lesson_detail_screen.dart`
- `lib/features/coach/lesson_print_export_service.dart`
- `lib/features/coach/lesson_sheet_notation_svg_renderer.dart`
- `lib/features/practice/widgets/sheet_notation_display.dart`
- `lib/features/practice/pattern_audio_service.dart`

Primary tests:

- `test/lesson_plan_loader_test.dart`
- `test/lesson_print_export_service_test.dart`
- `test/sheet_notation_display_test.dart`
- `test/pattern_audio_service_test.dart`

## Data Flow

```text
assets/lessons/flow_foundations.yaml
  -> LessonPlanLoader.loadFlowFoundations()
  -> LessonPlanLoader.loadAsset(...)
  -> yaml.loadYaml(...)
  -> LessonPlan.fromYaml(...)
  -> immutable Dart model objects
  -> lesson list screen
  -> lesson detail screen
  -> print/export service
  -> sheet notation renderer
  -> notation audio preview
```

`LessonPlanLoader` loads exactly one bundled asset for the current MVP:

```dart
assets/lessons/flow_foundations.yaml
```

The loader returns immutable model objects:

```text
LessonPlan
  lessons: List<Lesson>

Lesson
  patterns: List<LessonPattern>
  exercises: List<LessonExercise>
  coachingNotes: List<String>
  mastery: List<String>

LessonExercise
  tempo: TempoTarget?
  flow: List<FlowStep>
```

The YAML structure is not kept as a dynamic map after loading. UI, print, and
preview code consume the typed model objects.

## Top-Level YAML Shape

Every lesson YAML file must have one top-level `lesson_plan` map.

```yaml
lesson_plan:
  id: flow-foundations
  title: Flow Foundations
  subtitle: Starter path for groove, subdivision, fill placement, and kit flow.
  version: 1
  lessons:
    - id: groove-foundation
      number: 1
      title: Groove Foundation
      objective: Build a simple rock groove using simultaneous hand and kick/snare hits.
      skill_focus: groove
      estimated_minutes: 20
      patterns: []
      exercises: []
      coaching_notes: []
      mastery: []
```

Current root fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `lesson_plan` | n/a | yes | map | Single root object. |
| `lesson_plan.id` | `LessonPlan.id` | yes | non-empty string | Stable plan identifier. |
| `lesson_plan.title` | `LessonPlan.title` | yes | non-empty string | Displayed on lesson list and detail header. |
| `lesson_plan.subtitle` | `LessonPlan.subtitle` | yes | non-empty string | Displayed on lesson list. |
| `lesson_plan.version` | `LessonPlan.version` | yes | integer | Schema/content version marker. No migration logic exists yet. |
| `lesson_plan.lessons` | `LessonPlan.lessons` | yes | list of maps | Must contain at least one lesson. |

## Lesson Object

Each item in `lesson_plan.lessons` becomes a `Lesson`.

Example:

```yaml
- id: the-money-beat
  number: 2
  title: The Money Beat
  objective: Learn the foundational 4/4 drum beat with steady eighth-note hi-hat, kick on 1 and 3, and snare on 2 and 4.
  skill_focus: groove
  estimated_minutes: 25
  patterns:
    - id: money-beat-one-bar
      title: Money Beat - One Bar
      role: groove
      subdivision: 8
      time_signature: "4/4"
      repeat_count: 4
      notation: "[HH K:R][HH:R] [HH S:R][HH:R] [HH K:R][HH:R] [HH S:R][HH:R]"
  exercises:
    - title: Add Kick And Snare
      instructions: Keep the hi-hat even, place the kick on 1 and 3, and place the snare on 2 and 4.
      subdivision: 8
      tempo:
        start: 60
        target: 100
      flow:
        - pattern: money-beat-one-bar
          repeat: 8
  coaching_notes:
    - Count out loud until the placement feels automatic.
  mastery:
    - Play the one-bar beat at 100 BPM with even hi-hat notes.
```

Current lesson fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `id` | `Lesson.id` | yes | non-empty string | Stable lesson identifier. Used in tests and future routing. |
| `number` | `Lesson.number` | yes | integer | Sort key and displayed lesson number. |
| `title` | `Lesson.title` | yes | non-empty string | List row and detail app bar title. |
| `objective` | `Lesson.objective` | yes | non-empty string | List row summary and detail intro. |
| `skill_focus` | `Lesson.skillFocus` | yes | non-empty string | Detail metadata pill. |
| `estimated_minutes` | `Lesson.estimatedMinutes` | yes | integer | List row and detail metadata. |
| `patterns` | `Lesson.patterns` | yes | list of maps | Rendered in lesson detail and print output. |
| `exercises` | `Lesson.exercises` | yes | list of maps | Rendered in lesson detail and print output. |
| `coaching_notes` | `Lesson.coachingNotes` | yes | non-empty string list | Rendered as bullet guidance. |
| `mastery` | `Lesson.mastery` | yes | non-empty string list | Rendered as mastery target bullets. |

Lessons are sorted by `number` after loading. The physical order in YAML should
still match `number` for readability, but runtime display order is the sorted
order.

Current loader validation does not enforce:

- unique lesson IDs
- unique lesson numbers
- contiguous lesson numbers
- positive lesson numbers
- positive estimated minutes

Current tests do assert the bundled Flow Foundations lesson numbers are ordered
and contiguous.

## Pattern Object

Each item in `lesson.patterns` becomes a `LessonPattern`.

Patterns are named musical ideas. In the MVP, each pattern owns exactly one
`notation` string and renders as one isolated notation example row. One
`notation` string can produce multiple computed measures, but the schema does
not represent multiple pattern sections.

Example:

```yaml
- id: money-beat-four-bars
  title: Money Beat - Four Bars With Crash
  role: groove
  subdivision: 8
  time_signature: "4/4"
  notation: "[HH K:R][HH:R] [HH S:R][HH:R] [HH K:R][HH:R] [HH S:R][HH:R]"
```

Current pattern fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `id` | `LessonPattern.id` | yes | non-empty string | Stable ID. Referenced by exercise `flow[].pattern`. |
| `title` | `LessonPattern.title` | yes | non-empty string | Pattern row title and print title. |
| `role` | `LessonPattern.role` | yes | non-empty string | Display label such as `groove`, `fill`, `warmup`, `vocabulary`, or `chop`. |
| `notation` | `LessonPattern.notation` | yes | non-empty string | Drumcabulary pattern text. Rendered as sheet notation and preview audio. |
| `subdivision` | `LessonPattern.subdivision` | no | scalar string | Default rhythmic value/feel for notation rendering and preview. |
| `time_signature` | `LessonPattern.timeSignature` | no | scalar string | Defaults to `4/4`. |
| `repeat_count` | `LessonPattern.repeatCount` | no | positive integer | Repeat metadata for display and audio preview. |

`subdivision`, `time_signature`, and `repeat_count` are pattern metadata. They
should not be encoded as normal notation tokens.

### Pattern Subdivision

The loader accepts any scalar and stores it as a string. The current lesson
detail renderer maps these values:

| YAML value | Rendered note value | Feel |
| --- | --- | --- |
| `4` | quarter | straight |
| `8` | eighth | straight |
| `16` | sixteenth | straight |
| `32` | thirty-second | straight |
| `triplet` | eighth | triplet |
| omitted or unknown | eighth | straight, except exact `triplet` is triplet |

Current authored YAML uses `8`, `16`, and `triplet`.

`subdivision: triplet` is timing/display metadata. It does not add a new
notation token.

### Pattern Time Signature

`time_signature` is a string such as `"4/4"`.

Current behavior:

- omitted `time_signature` resolves to `4/4`
- renderer uses the time signature to compute measure grouping
- invalid or unexpected formats are not rejected by the YAML loader
- the notation document falls back to four quarter-note beats if parsing fails

Authoring rule:

- quote time signatures in YAML, for example `"4/4"`, to keep the value clearly
  string-like.

### Pattern Repeat Count

`repeat_count` is a positive integer.

Current behavior:

- on-screen notation renders repeat bars for repeated examples
- MVP does not render separate text labels such as `4x`
- audio preview and playhead movement honor `repeat_count`
- print/export receives the same pattern metadata through the notation document

`repeat_count` is not a replacement for writing a longer phrase. Use it when a
short written pattern should be repeated as a practice instruction. Write the
full pattern when the actual notes change across measures.

### Pattern IDs And Flow References

Exercises can reference patterns by ID:

```yaml
flow:
  - pattern: money-beat-one-bar
    repeat: 8
```

The loader currently stores this reference as text. It does not resolve it or
fail on missing pattern IDs. The lesson detail and print output resolve flow
references locally and fall back to displaying the raw ID if no matching pattern
exists.

The bundled asset test checks that every authored flow reference points to a
pattern in the same lesson.

Authoring rule:

- keep `flow[].pattern` references within the same lesson
- do not reference patterns from another lesson unless the model and UI are
  extended deliberately

## Exercise Object

Each item in `lesson.exercises` becomes a `LessonExercise`.

Exercises are coaching instructions. They are not live practice sessions and do
not create timers, transport controls, completion state, or persisted progress.

Example:

```yaml
- title: Four-Bar Phrase With Crash
  instructions: Play four measures; on measure 4, use crash plus kick on beat 1 instead of hi-hat plus kick.
  subdivision: 8
  tempo:
    start: 60
    target: 100
  flow:
    - pattern: money-beat-four-bars
      repeat: 4
```

Current exercise fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `title` | `LessonExercise.title` | yes | non-empty string | Exercise row title. |
| `instructions` | `LessonExercise.instructions` | yes | non-empty string | Exercise body text. |
| `subdivision` | `LessonExercise.subdivision` | no | scalar string | Display metadata only. |
| `subdivision_sequence` | `LessonExercise.subdivisionSequence` | no | scalar string list | Display metadata only. |
| `tempo` | `LessonExercise.tempo` | no | map | Optional `TempoTarget`. |
| `flow` | `LessonExercise.flow` | no | list of maps | Optional ordered sequence of pattern repeats. |

Exercise `subdivision` and `subdivision_sequence` are instructional metadata.
They do not control notation preview speed in the current MVP. Pattern preview
uses the pattern's own `subdivision` metadata and a fixed preview BPM.

## Tempo Target Object

`tempo` becomes a `TempoTarget`.

```yaml
tempo:
  start: 60
  target: 100
```

Current fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `start` | `TempoTarget.start` | yes | integer | Displayed as the starting BPM. |
| `target` | `TempoTarget.target` | yes | integer | Displayed as the target BPM. |

Current loader validation does not enforce:

- positive BPM values
- `target >= start`
- musically reasonable tempo ranges

## Flow Step Object

`flow` is an ordered list of `FlowStep` objects.

```yaml
flow:
  - pattern: basic-triplet-groove
    repeat: 4
  - pattern: six-ab
    repeat: 1
  - pattern: basic-triplet-groove
    repeat: 4
```

Current fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `pattern` | `FlowStep.pattern` | yes | non-empty string | Pattern ID reference. |
| `repeat` | `FlowStep.repeat` | yes | integer | Displayed repeat count for that flow step. |

Current loader validation does not enforce:

- positive repeat counts
- existing pattern references
- same-lesson references

Current UI behavior:

- lesson detail displays the referenced pattern title when found
- print/export displays the referenced pattern title when found
- if not found, both display the raw pattern ID
- flow is not rendered as combined sheet notation
- flow is not played as combined audio

## Removed And Deprecated YAML Fields

The current live schema does not include:

- `required_concepts`

Earlier planning prompts included `required_concepts`, but the MVP UI and model
removed it. Do not add this field back unless the product explicitly restores a
concept-prerequisite surface and updates `Lesson`, loader validation, tests, UI,
and print/export together.

## Validation Architecture

Validation is intentionally simple and local to `LessonPlan.fromYaml(...)` and
the nested model factories.

Current loader validation guarantees:

- root YAML is a map
- `lesson_plan` exists and is a map
- required strings are present, strings, and non-empty
- required integers are present and integers
- required lists are lists
- required string lists contain at least one non-empty string
- required list items that should be maps are maps
- `repeat_count`, when present, is a positive integer
- optional scalar fields can be string, int, double, or bool and are stored as
  trimmed strings
- malformed YAML is wrapped in `LessonPlanLoadException`

Current loader validation does not guarantee:

- uniqueness of IDs
- flow reference integrity
- pattern notation validity
- supported subdivision values
- valid time signature format
- positive lesson numbers
- positive estimated minutes
- positive tempo values
- positive flow repeat values
- absence of unknown YAML keys

Current tests add extra bundled-asset checks for:

- Flow Foundations lesson count and numbering
- removed `notation-basics` lesson staying absent
- Money Beat pattern metadata
- flow references matching same-lesson pattern IDs
- every pattern notation being parseable by `DrumSheetNotationDocument`
- selected audio-plan behavior for crash-plus-kick notation

## Consumer Architecture

### Lesson List

File:

- `lib/features/today/today_screen.dart`

Consumed fields:

- `LessonPlan.title`
- `LessonPlan.subtitle`
- `Lesson.number`
- `Lesson.title`
- `Lesson.objective`
- `Lesson.estimatedMinutes`
- `Lesson.primaryPattern.title`
- `Lesson.primaryPattern.role`

The list does not show raw notation strings.

### Lesson Detail

File:

- `lib/features/coach/lesson_detail_screen.dart`

Consumed fields:

- lesson plan title
- lesson title, number, objective, skill focus, estimated minutes
- patterns and pattern metadata
- exercises and exercise metadata
- flow step references
- coaching notes
- mastery targets

Each `LessonPattern` creates one `DrumSheetNotationDisplay`.

The detail screen currently constructs notation documents with `lenient: true`.
The language contract expects YAML-authored notation to remain valid strict
notation even though this display path is lenient.

### Print And Share

Files:

- `lib/features/coach/lesson_print_export_service.dart`
- `lib/features/coach/lesson_sheet_notation_svg_renderer.dart`

Print/export consumes the same model objects as the lesson detail screen.

Print/export behavior:

- renders lesson header metadata
- embeds rendered SVG notation for every pattern
- renders exercises, tempo, subdivision, flow, coaching notes, and mastery
- throws if required rendered notation SVGs are missing
- should not silently replace failed notation rendering with raw notation text

### Notation Rendering

Pattern fields used by notation rendering:

- `notation`
- `subdivision`
- `time_signature`
- `repeat_count`

One YAML pattern becomes one notation document and one rendered pattern block.

Current schema does not support:

- explicit measure separators in YAML
- section labels inside one pattern
- multiple notation documents under one pattern
- combined exercise-flow notation rendering

### Audio Preview

Audio preview uses the same `DrumSheetNotationDocument` built from pattern
metadata.

Current behavior:

- preview is local to each rendered pattern row
- preview uses a fixed BPM for now
- exercise tempo is displayed as lesson guidance, not used as active preview
  speed
- preview honors pattern `repeat_count`
- preview derives voices from the parsed notation
- preview uses mixer defaults in `PatternAudioMixerConfigV1`

## Authoring Rules

Use these rules when editing `assets/lessons/flow_foundations.yaml`.

1. Keep lesson content in YAML.
2. Keep user-facing lesson text concise and printable.
3. Keep lesson numbers ordered and contiguous even though the loader only sorts.
4. Keep IDs stable once referenced by tests, flow steps, or future links.
5. Keep pattern IDs unique within a lesson.
6. Keep flow references within the same lesson.
7. Use pattern metadata for timing context; do not encode timing words as
   notation tokens.
8. Quote notation strings when they contain brackets, colons, parentheses,
   carets, or other punctuation.
9. Quote time signatures.
10. Do not show or depend on raw notation strings as student-facing output.
11. Use `repeat_count` for repeated written examples; write the full notation
    when note content changes across measures.
12. Keep `tempo` as guidance until a live tempo control is explicitly added.
13. Do not add progress, completion, scoring, or recommendation fields to this
    schema during the MVP.

## Example Minimal Valid Plan

```yaml
lesson_plan:
  id: example-plan
  title: Example Plan
  subtitle: Example subtitle.
  version: 1
  lessons:
    - id: example-lesson
      number: 1
      title: Example Lesson
      objective: Learn one simple idea.
      skill_focus: groove
      estimated_minutes: 10
      patterns:
        - id: example-pattern
          title: Example Pattern
          role: warmup
          subdivision: 8
          time_signature: "4/4"
          repeat_count: 4
          notation: "RLRL"
      exercises:
        - title: Loop It
          instructions: Play the pattern slowly and evenly.
          subdivision: 8
          tempo:
            start: 60
            target: 90
          flow:
            - pattern: example-pattern
              repeat: 4
      coaching_notes:
        - Stay relaxed.
      mastery:
        - Play it evenly at 90 BPM.
```

## Versioning And Migration

`lesson_plan.version` currently exists as data but has no migration engine.

Current meaning:

- `version: 1` is the current schema/content version.
- The loader does not branch by version.
- Adding breaking schema changes requires updating this document, the Dart
  models, loader validation, bundled YAML, tests, UI, print/export, and any
  handoff docs that reference the schema.

Recommended future approach:

- keep `version: 1` stable while fields are additive and optional
- use `version: 2` only when existing YAML needs different parsing semantics
- add explicit migration or versioned parser logic before introducing a
  breaking version

## Known Gaps

These are known architecture gaps, not accidental omissions.

- The loader does not reject unknown keys.
- The loader does not enforce ID uniqueness.
- The loader does not enforce flow reference integrity.
- Pattern notation validation is primarily tested, not enforced strictly at
  asset-load time.
- Lesson detail uses lenient notation parsing for display.
- Exercise `flow` is textual guidance only.
- Exercise tempo does not control audio preview speed.
- There is no multi-plan registry.
- There is no remote content loading or cache invalidation layer.
- There is no content localization layer.

## Change Checklist

When changing lesson YAML structure:

1. Update this document first.
2. Update `lib/features/coach/lesson_plan.dart`.
3. Update `lib/features/coach/lesson_plan_loader.dart` if loader behavior
   changes.
4. Update `assets/lessons/flow_foundations.yaml`.
5. Update screen and print/export consumers.
6. Update notation/audio paths if pattern metadata changes.
7. Update tests, especially `test/lesson_plan_loader_test.dart`.
8. Run focused tests and analyzer.
9. Update `docs/18_NOTATION_LANGUAGE_CONTRACT.md` only if notation grammar or
   pattern metadata semantics changed.
10. Update `docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md` only if render flow
    changed.
