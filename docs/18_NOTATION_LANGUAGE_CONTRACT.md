# 18 - Notation Language Contract

## Purpose

This is the single source of truth for the Drumcabulary notation language.

Other files may implement, render, test, or demonstrate the language, but they
should not redefine it. When the notation language changes, update this file
first, then update parser, renderer, lesson content, and tests to match.

## Current Product Boundary

The current product is a Coach lesson-plan MVP.

Notation is authored by lesson/content authors in YAML. Users are not expected
to write notation strings in the app yet.

The notation language must support:

- compact authored lesson examples
- readable sheet music rendering
- lightweight audio preview
- printable lesson output
- beginner lesson vocabulary such as grooves, fills, triplets, ghost notes,
  accents, repeats, and basic kit voices

The notation language must not imply:

- live practice-session state
- progress tracking
- assessment scoring
- user-specific recommendations
- user-facing notation editing

## Language Layers

Drumcabulary notation has three layers.

1. Pattern notation string

   This is the compact text authored in lesson YAML, such as:

   ```text
   [HH K:R][HH:R] [HH S:R][HH:R]
   ```

2. Pattern metadata

   Metadata defines timing/display context that should not be embedded as
   pattern tokens, such as subdivision, triplet feel, time signature, and repeat
   count.

3. Render document

   The app converts pattern notation plus metadata into a render-ready JSON
   document for sheet music, print, and audio preview.

## Pattern Metadata

Pattern metadata belongs beside the notation string in YAML.

```yaml
patterns:
  - id: money-beat-one-bar
    title: Money Beat - One Bar
    role: groove
    subdivision: 8
    time_signature: "4/4"
    repeat_count: 4
    notation: "[HH K:R][HH:R] [HH S:R][HH:R] [HH K:R][HH:R] [HH S:R][HH:R]"
```

Supported metadata:

- `subdivision`
- `time_signature`
- `repeat_count`

### Subdivision

`subdivision` defines the default rhythmic value and feel for the pattern.

Supported YAML values:

- `8`
- `16`
- `triplet`

Current defaults:

- omitted pattern `subdivision` resolves to eighth notes
- `triplet` resolves to eighth-note triplet feel

Subdivision is not a normal pattern token. Do not write words like `triplet` or
`16th` inside notation strings.

### Time Signature

`time_signature` defines the displayed meter and measure grouping.

Current default:

- omitted `time_signature` resolves to `4/4`

Supported format:

- a string in `number/number` form, such as `"4/4"`

### Repeat Count

`repeat_count` defines a repeated pattern instruction for display and preview.

Current behavior:

- repeat count is metadata, not a notation token
- sheet notation uses repeat bars rather than writing all repetitions out
- repeat labels such as `4x` or `8x` are not part of the current MVP display

## Pattern Notation String

Pattern notation is a sequence of note events and grouping spaces.

Each parsed note event becomes one rhythmic slot unless it appears inside a
bracketed override that expands to more than one event.

### Core Tokens

| Token | Meaning | Default Voice | Sticking |
| --- | --- | --- | --- |
| `R` | right hand | snare | `R` |
| `L` | left hand | snare | `L` |
| `K` | kick | kick | `K` |
| `X` | crash or big hit | crash | `X` |
| `F` | flam | snare | `F` |
| `_` | rest | none | `_` |

Tokens are case-insensitive in parsing and are normalized to uppercase.

### Deprecated And Invalid Tokens

`B` is intentionally invalid. Use `[RL]` for both hands/unison or assign
explicit voices with bracket overrides.

Unknown letters are invalid in strict parsing. Lenient parsing may ignore
incomplete or invalid editing states, but authored lesson YAML should be valid
strict notation.

## Grouping Spaces

Top-level spaces are grouping markers.

They affect phrasing, beams, visual spacing, and wrapping. They do not change
timing.

Examples:

```text
RLRLL K RLRLL RLRLL X
```

This shows phrase groups. It does not create tuplets and does not change note
durations.

Spaces inside brackets are part of the bracket syntax and do not create
top-level groups:

```text
[HH K:R]
[T2 16:L]
[32:R L]
```

## Accents

Use `^` immediately before a note, ghost group, or bracket group to mark an
accent.

Valid examples:

```text
^R
^L
^[T1:R]
[^RK]
```

Accent applies to the next parsed note event or bracket result.

Accent does not remain active after that note event.

## Ghost Notes

Use parentheses around exactly one note event to mark a ghost note.

Valid examples:

```text
(R)
(L)
([T1:L])
```

Invalid examples:

```text
()
(RL)
^(L)
```

Rules:

- ghost groups must contain exactly one parsed note event
- ghost notes cannot be accented
- ghost notes keep their normal sticking label; parentheses are rendered around
  the notehead, not around the sticking label

## Brackets

Brackets have two meanings depending on whether the body contains a colon.

1. No colon: simultaneous multi-voice event
2. With colon: override expression

### Simultaneous Events

Bracketed notation without a colon creates one rhythmic slot containing multiple
limbs or voices.

Examples:

```text
[RK]
[RL]
[XK]
[^RK]
```

Rules:

- a simultaneous event must contain at least two parsed note events
- rests are not allowed inside simultaneous events
- voices from the inner notes are combined into one slot
- sticking labels from the inner notes are combined

Common meanings:

- `[RK]`: right hand with kick
- `[RL]`: both hands together
- `[XK]`: crash with kick

### Overrides

Bracketed notation with a colon applies metadata to the notation after the colon.

General form:

```text
[override-list:notation]
```

Examples:

```text
[T1:L]
[HH:R]
[HH K:R]
[T2 16:L]
[32:R L]
[T1:^R]
[T1:(L)]
```

The override list may include one duration, one or more voices, or both.

Override items may be separated by spaces or commas:

```text
[HH K:R]
[HH,K:R]
[T2 16:L]
```

Overrides apply only inside that bracket.

## Voice Overrides

Voice overrides assign drum voices while preserving the authored sticking label.

Supported voice override labels:

| Label | Voice |
| --- | --- |
| `S`, `SN`, `SNARE` | snare |
| `T1`, `TOM1` | rack tom 1 |
| `T2`, `TOM2` | tom 2 |
| `FT`, `FLOORTOM`, `FLOOR_TOM` | floor tom |
| `K`, `KICK` | kick |
| `HH`, `HIHAT`, `HIGHHAT` | hi-hat |
| `C`, `X`, `CRASH` | crash |
| `RD`, `RIDE` | ride |

Examples:

```text
[HH:R]
[T1:L]
[FT:R]
[RD:R]
```

Multiple voices can be assigned to one sticking:

```text
[HH K:R]
[X K:R]
```

This means the authored sticking remains `R`, while the rendered and previewed
voices include the listed instruments.

## Duration Overrides

Duration overrides assign note value inside a bracket.

Supported duration labels:

| Label | Value |
| --- | --- |
| `1`, `1n` | whole |
| `2`, `2n` | half |
| `4`, `4n` | quarter |
| `8`, `8n` | eighth |
| `16`, `16n` | sixteenth |
| `32`, `32n` | thirty-second |

Examples:

```text
[16:R]
[32:R L]
[T2 16:L]
```

Duration overrides should be used sparingly in lesson YAML. Prefer pattern-level
`subdivision` when the whole pattern shares one grid.

## Triplets

Triplet timing is metadata, not syntax.

Use YAML metadata:

```yaml
subdivision: triplet
notation: "R(L)(L) RLK"
```

Do not create special triplet tokens inside notation strings.

Grouping spaces do not create tuplets. In triplet patterns they still only show
phrase boundaries.

## Rests

Use `_` for a rest.

Examples:

```text
R_L_
R _ L _
```

Rules:

- rest has no voice
- rest may not be part of a simultaneous bracket group
- rest can be duration-overridden:

```text
[16:_]
```

## Flams

Use `F` for the current flam token.

Current behavior:

- `F` defaults to snare
- `F` has sticking `F`
- renderer attempts to attach grace-note flam notation when supported

Current limitation:

- flam target/hand semantics are not fully modeled yet

Do not expand flam syntax until a concrete lesson need exists.

## Render Document Contract

The renderer accepts a render-ready JSON document.

```ts
type DrumNotationDocument = {
  subdivision?: DrumNoteValue;
  feel?: "straight" | "triplet";
  timeSignature?: string;
  repeatCount?: number;
  measures: DrumNotationMeasure[];
};

type DrumNotationMeasure = {
  notes: DrumNotationNote[];
};

type DrumNotationNote = {
  value?: DrumNoteValue;
  voices?: DrumVoiceId[];
  rest?: boolean;
  sticking?: string;
  accent?: boolean;
  flam?: boolean;
  ghost?: boolean;
  tie?: boolean;
};
```

Supported render note values:

```text
1n 2n 4n 8n 16n 32n
```

Supported render feel values:

```text
straight
triplet
```

Supported render voices:

```text
hihat
ride
crash
snare
tom1
tom2
floorTom
kick
```

Render document defaults:

- `subdivision`: `8n`
- `feel`: `straight`
- `timeSignature`: `4/4`

## Voice Rendering Map

Current sheet rendering voice map:

| Voice | Staff Key | Notehead |
| --- | --- | --- |
| `crash` | `a/5` | x |
| `ride` | `g/5` | x |
| `hihat` | `f/5` | x |
| `tom1` | `e/5` | normal |
| `snare` | `c/5` | normal |
| `tom2` | `a/4` | normal |
| `floorTom` | `g/4` | normal |
| `kick` | `f/4` | normal |

This map is a rendering convention, not author-facing syntax. Authors should use
the override labels above.

## Serialization Rules

When notation notes are serialized back into pattern text:

- limb sticking is uppercased
- non-default duration is written as an override
- non-default voice is written as an override
- simultaneous notes with multi-character sticking may serialize as bracketed
  simultaneous notation
- accented ghost notes must throw rather than serialize

Serialization exists for internal tooling and editing support. It is not yet a
user-facing notation authoring workflow.

## Lesson YAML Contract

Lesson patterns use this notation through `notation`.

```yaml
patterns:
  - id: triplet-vocab-a
    title: A - Right Ghost Ghost
    role: vocabulary
    subdivision: triplet
    notation: "R(L)(L)"
```

Pattern requirements:

- `id`
- `title`
- `role`
- `notation`

Pattern optional fields:

- `subdivision`
- `time_signature`
- `repeat_count`

Current lesson UI intentionally does not show raw notation strings as the main
student-facing experience. The strings are authoring source for sheet rendering,
audio preview, and print.

## Valid Examples

Basic hands:

```text
RLRL
RL RL
```

Basic rock groove:

```text
[RK]R [RL]R [RK]R [RL]R
```

Money Beat:

```text
[HH K:R][HH:R] [HH S:R][HH:R] [HH K:R][HH:R] [HH S:R][HH:R]
```

Accent and ghost:

```text
^R^L^R(L)(L)
```

Crash/kick resolution:

```text
^R^L^R(L)(L) [XK]
```

Tom voice override:

```text
[T1:R][T2:L][FT:R]
```

Triplet vocabulary:

```text
R(L)(L)
RLK
RKL
KRL
(R)(R)L
```

Six-note triplet phrase:

```text
R(L)(L) RLK
```

## Invalid Examples

Unsupported token:

```text
B
```

Empty ghost group:

```text
()
```

Ghost group with more than one note:

```text
(RL)
```

Accented ghost:

```text
^(L)
```

Empty bracket:

```text
[]
```

Single-note simultaneous bracket:

```text
[R]
```

Rest inside simultaneous event:

```text
[R_]
```

Unknown override:

```text
[COWBELL:R]
```

## Parser Modes

Strict parsing is for saved/authored content.

Strict parsing should throw for invalid notation.

Lenient parsing is for incomplete live-editing states.

Lenient parsing may tolerate unfinished constructs such as:

```text
^
(
[32:
```

The lesson MVP should treat YAML as authored source and should not rely on
lenient parsing to hide content errors.

## Renderer And Playback Relationship

The same parsed notation should drive:

- sheet notation rendering
- print/export sheet examples
- audio preview token planning

Rendering and playback may use separate implementation files, but the language
contract is this document.

Any behavior difference between rendered notation and audio preview is a bug
unless explicitly documented here.

Detailed rendering-pipeline ownership, including Flutter, WebView, VexFlow,
audio preview, print/export, and known renderer limitations, is defined in:

- `docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md`

## Current Known Non-Language Issues

The iOS/WebView sheet renderer has known visual alignment issues with sticking
labels above notes. That is a renderer defect, not a notation-language rule.

Do not change the notation grammar to work around a renderer alignment bug.

## Source Files That Implement This Contract

Language-facing implementation files:

- `lib/features/practice/widgets/sheet_notation_display.dart`
- `web/sheet_notation/document.js`
- `web/sheet_notation/renderer.js`
- `web/sheet_notation/duration.js`
- `web/sheet_notation/voice_mapping.js`
- `web/sheet_notation/types.d.ts`

Lesson authoring source:

- `assets/lessons/flow_foundations.yaml`

Tests that must be updated when this contract changes:

- `test/sheet_notation_display_test.dart`
- `test/sheet_notation/sheet_notation.test.mjs`
- `test/lesson_plan_loader_test.dart`

Generated file:

- `web/sheet_notation/app_renderer.js`

Do not edit `web/sheet_notation/app_renderer.js` by hand. Regenerate it with:

```sh
npm run build:sheet-notation-app
```
