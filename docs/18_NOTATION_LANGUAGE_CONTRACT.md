# 18 - Notation Language Contract

## Purpose

This is the source of truth for the current Drumcabulary notation language as
implemented in the app.

Other files may implement, render, test, demonstrate, or adapt the language,
but they should not redefine it. When the notation language changes, update
this file first, then update parser, renderer, lesson content, and tests to
match.

## Authority Boundary

The authoritative authored-text parser is:

- `DrumSheetPatternParser` in
  `lib/features/practice/widgets/sheet_notation_display.dart`

That parser owns strict voice-first notation text.

The Web sheet renderer does not parse notation text. It accepts render-ready
JSON produced by Flutter or by test/demo helpers.

`web/sheet_notation/demo.js` still contains a standalone legacy demo parser for
compact sticking-first patterns such as `RLRL`, `^R`, `(L)`, `K`, `F`, `X`, and
`_`. That parser is demo/runtime-test scaffolding. It is not the lesson YAML
language and it is not the strict app authoring language.

`PracticeItemV1.sequence` and `PatternSequenceV1.parse(...)` also preserve a
legacy token model for old/generated practice items. That model can still feed
sheet rendering, but it is not the authored notation text contract.

## Current Product Boundary

The current product uses notation in these places:

- Coach lesson YAML
- Lesson Detail sheet rendering
- lesson print/export
- Pattern Capture review/editing
- user exercise saving
- Practice Session notation display
- audio preview
- Guided Practice expected events
- LED cue frames

The notation text language is voice-first. The render document and legacy
practice-item model can represent additional display states such as rests,
flams, ties, and per-note values, but those are not authored with inline text
syntax in the current voice-first parser.

## Core Text Model

The notation text language is voice-first.

- A bracketed event is the rhythmic unit.
- Every playable text event has at least one drum voice.
- A voice may optionally carry a stroke sequence.
- A missing stroke sequence is semantically absent, not inferred.
- Sticking is never inferred from the drum voice in the text model.
- Multiple voices inside one bracket are simultaneous unless a stroke sequence
  expands the bracket into multiple sequential events.
- A stroke sequence can expand one bracket into multiple sequential events.
- All voice specs inside one bracket must expand to the same stroke count.
- Events may be separated by whitespace, but whitespace between bracketed
  events is not required by the parser.

Canonical form:

```text
[VOICE[:STROKE_SEQUENCE]]
```

Canonical examples:

```text
[S]
[HH]
[OHH]
[K]
[T1:R]
[S:R]
[S:LRLR]
[S:(L)(L)^R]
[HH K]
[HH:R S:L]
[OHH:R K]
[S:RL][K]
```

`[T1:R]` is valid current voice-first notation: `T1` is the voice and `R` is
the stroke.

`[HH K:R]` is also accepted by the current parser: `HH` has no stroke and `K`
has a right-hand stroke. This is not a recommended authoring pattern for normal
kick notation, but the parser does not prohibit stroke sequences on kick or
cymbal voices.

## Parser Modes

Strict parsing is used for validation and save paths.

Lenient parsing is used for incomplete editing/display states.

| Mode | Behavior |
| --- | --- |
| strict | Throws `FormatException` for malformed events, unknown voices, unclosed brackets, unsupported stroke tokens, duplicate voices, and unequal stroke counts. |
| lenient | Ignores malformed bracket bodies, stops at an unclosed bracket, ignores non-bracket top-level characters, and returns whatever valid notes were parsed before the invalid state. |

Strict parsing of an empty string returns an empty note list. Lesson YAML rejects
empty `pattern` strings before parsing, and the user exercise save path rejects
parsed patterns with no notes.

## Voice Vocabulary

Serialization always uses the canonical labels.

Parsing is case-insensitive and accepts the aliases listed below. Aliases are
accepted implementation behavior, not preferred lesson-authoring style.

| Canonical label | Voice | Accepted aliases |
| --- | --- | --- |
| `S` | snare | `SN`, `SNARE` |
| `T1` | tom 1 | `TOM1` |
| `T2` | tom 2 | `TOM2` |
| `FT` | floor tom | `FLOORTOM`, `FLOOR_TOM` |
| `K` | kick | `KICK` |
| `HH` | closed hi-hat | `HIHAT`, `HIGHHAT` |
| `OHH` | open hi-hat | `OPEN_HH`, `OPENHIHAT`, `OPEN_HIHAT` |
| `CR` | crash | `C`, `X`, `CRASH` |
| `RD` | ride | `RIDE` |

`HH` means closed hi-hat.

`OHH` means open hi-hat. It is a first-class semantic voice in parsing,
serialization, rendering, playback, MIDI capture, Guided Practice, and LED cue
frames. It is not an accent, articulation, or playback-only flag on `HH`.

`X` is accepted as a crash alias only inside a bracket voice position, such as
`[X]`. A bare top-level `X` is not strict voice-first notation.

## Stroke Sequences

A stroke sequence is an ordered list of hand stroke tokens.

Supported stroke tokens:

| Token | Meaning |
| --- | --- |
| `R` | normal right-hand stroke |
| `L` | normal left-hand stroke |
| `^R` | accented right-hand stroke |
| `^L` | accented left-hand stroke |
| `(R)` | ghosted right-hand stroke |
| `(L)` | ghosted left-hand stroke |

Stroke parsing is case-insensitive. Serialization writes uppercase canonical
tokens.

Examples:

```text
[S:LRLR]
[S:(L)(L)^R]
[OHH:RRRR]
[T2:^L]
```

Accent and ghosting belong to individual strokes. Forms such as `[^S:R]`,
`[(S):L]`, `^(L)`, and `[S:^(L)]` are not valid voice-first stroke syntax.

`K`, `F`, `X`, and `_` are not stroke tokens in the strict voice-first parser.
They are legacy token-model symbols outside this text grammar.

## Text Grammar

The implemented parser tokenizes notation like this:

```text
pattern          := topLevel*
topLevel         := whitespace | event
event            := "[" eventBody "]"
eventBody        := voiceSpec separated by comma/whitespace tokens
voiceSpec        := voiceLabel [":" strokeSequence]
strokeSequence   := stroke+
stroke           := hand | "^" hand | "(" hand ")"
hand             := "L" | "R"
voiceLabel       := canonical voice label or accepted alias
```

Implementation details that matter:

- Top-level non-whitespace characters outside brackets are invalid in strict
  mode.
- Top-level commas are invalid in strict mode.
- Whitespace between bracketed events is optional.
- Inside brackets, one or more spaces and/or commas separate voice specs.
- The parser drops empty separator tokens, so redundant or trailing separators
  inside brackets are currently accepted, for example `[HH,,K]` and `[HH,]`.
  They are noncanonical and must serialize without the redundant separators.
- A colon must stay inside one voice-spec token. `[S:R]` is valid; `[S: R]`,
  `[S :R]`, and `[S : R]` are invalid.
- A colon introduces a non-empty stroke sequence.
- A voice without a colon is valid.
- Unknown voices fail validation.
- Duplicate voices fail validation after alias resolution, so `[S SNARE]` is
  invalid.
- Malformed stroke sequences fail validation.

Valid:

```text
[HH K]
[HH]
[HH S]
[OHH K]
[S:(L)(L)^R]
[HH:R S:L]
[S:RL][K]
[snare:r]
[OPEN_HIHAT:^R]
```

Invalid:

```text
[]
[:R]
[S:]
[S:^]
[S:()]
[S:(R]
[S:R)]
[UNKNOWN:R]
[HH:RRRR K]
[OHH:RRRR K]
[S:RK]
[S:RF]
[S:RX]
[S:R_]
RLRL
K
^R
(L)
_
```

## Multi-Stroke Expansion

A stroke sequence represents consecutive strokes on the same voice.

```text
[S:LRLR]
```

expands to four sequential snare events.

```text
[S:(L)(L)^R]
```

expands to three sequential snare events: ghost left, ghost left, accented
right.

Each expanded note keeps:

- `voices`: all voices in the bracket, in authored order
- `voiceStrokes`: one entry for each voice, with `null` when that voice has no
  authored stroke
- `sticking`: the display hand labels from non-null authored strokes joined
  together
- `accent`: true when any authored stroke in that expanded note is accented
- `ghost`: true only when the expanded note has authored strokes and every
  authored stroke in that expanded note is ghosted

The existing subdivision and feel metadata supply timing. The text language
does not create a second timing system.

## Simultaneous Sequence Alignment

Every voice specification inside one bracket must expand to the same stroke
count.

- a voice with no stroke sequence has a stroke count of one
- a voice with one stroke has a stroke count of one
- unequal sequence lengths are invalid
- voices are not implicitly repeated, sustained, padded, or truncated

Valid:

```text
[HH:R K]
[HH:RRRR S:LRLR]
[OHH:RRRR S:LRLR]
```

Invalid:

```text
[HH:RRRR S:LR]
[HH:RRRR K]
[OHH:RRRR K]
```

For:

```text
[HH:RRRR S:LRLR]
```

the expanded events are:

```text
HH R + S L
HH R + S R
HH R + S L
HH R + S R
```

## Lesson YAML Notation

Lesson notation is loaded through:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`
- `lib/features/coach/lesson_notation_document.dart`

Each exercise has one `notation` block. The block can be single-section:

```yaml
notation:
  subdivision: 8
  time_signature: "4/4"
  repeat_count: 4
  pattern: "[HH] [HH] [HH S] [HH]"
```

Or sectioned:

```yaml
notation:
  sections:
    - title: Money Beat
      subdivision: 8
      time_signature: "4/4"
      repeat_count: 3
      pattern: "[HH K] [HH] [HH S] [HH]"
    - title: Triplet Fill
      subdivision: triplet
      time_signature: "4/4"
      repeat_count: 1
      pattern: "[S:RL][K] [S:R][K][S:L]"
```

The loader normalizes the single-section form into a one-item section list.

Current notation section fields:

| YAML field | Code field | Required | Current behavior |
| --- | --- | --- | --- |
| `title` | `title` | no | Optional non-empty string. |
| `pattern` | `pattern` | yes | Required non-empty string, then strict-validated during content-library validation. |
| `subdivision` | `subdivision` | no | Optional scalar string. Missing or unknown values default to eighth straight in Dart. |
| `time_signature` | `timeSignature` | no | Optional scalar string. Defaults to `4/4`. |
| `repeat_count` | `repeatCount` | no | Optional positive integer. Invalid non-positive values fail YAML parsing. |
| `sticking` | `sticking` | no | Optional scalar string sidecar applied after notation parsing. |

## Subdivision Metadata

Accepted lesson YAML subdivision values are normalized by trimming,
lowercasing, and replacing `-` with `_`.

Current loader mapping:

| Accepted value | `DrumSheetNoteValue` | `DrumSheetFeel` |
| --- | --- | --- |
| `4` | quarter | straight |
| `8` | eighth | straight |
| `16` | sixteenth | straight |
| `32` | thirty-second | straight |
| `triplet` | eighth | triplet |
| `8_triplet` | eighth | triplet |
| `eighth_triplet` | eighth | triplet |
| `16_triplet` | sixteenth | triplet |
| `sixteenth_triplet` | sixteenth | triplet |
| `sextuplet` | sixteenth | triplet |

Missing or unknown subdivision values currently fall back to eighth straight.
That fallback is implemented behavior, not a recommended authoring style.

Triplet timing is metadata, not text syntax. Grouping spaces do not create
tuplets.

The render JSON layer supports note values `1n`, `2n`, `4n`, `8n`, `16n`, and
`32n`. The strict voice-first text grammar has no inline duration override
syntax.

## Time Signature Metadata

Lesson YAML accepts any non-empty scalar `time_signature` string and defaults to
`4/4`.

Dart measure splitting uses the time signature when it can parse
`numerator/denominator`. If parsing fails, Dart falls back to four quarter-note
beats.

The Web render document parser is stricter: it accepts strings shaped like
`digits / digits`, removes internal spaces, and rejects unsupported shapes.

MIDI Pattern Capture config currently asserts one of `4/4`, `3/4`, or `6/8`.

## Repeat Count Metadata

`repeat_count` is optional and must be a positive integer when present.

`DrumSheetNotationDocument.repeatCount` stores the value.

Audio preview and Guided Practice repeat the parsed document
`max(1, repeatCount ?? 1)` times.

The Web renderer currently draws an end repeat bar according to the render
option `finalRepeat`, which defaults to true in Flutter display widgets. It
does not render the repeat count number.

## Sticking Sidecar

Inline stroke sequences create model sticking and stroke metadata.

The optional YAML `sticking` field is a separate sidecar used by lesson
rendering when authors want explicit display labels independent of the pattern
text.

`stickingLabels(...)` currently supports:

- whitespace-separated labels, when more than one label is present
- compact single-character labels `R`, `L`, `K`, `F`, `X`, `_`
- compound cue labels matching `([RL])^?[RL]`, such as `(L)R`
- a final fallback that splits non-empty text into individual characters

When a YAML `sticking` sidecar is present, validation requires the number of
labels to equal the number of playable non-rest notes. The sidecar labels are
applied to non-rest notes in flattened-note order and uppercased.

Coach Lesson Detail currently sets `showSticking` from
`shouldShowStickingForNotationSection(section)`, which returns true only when
the section has a YAML `sticking` sidecar. Inline stroke metadata still drives
audio preview, Guided Practice, and LED cues even when visual sticking labels
are suppressed in that Coach view.

## Grouping

Top-level whitespace in a pattern string is used by helper functions to infer
visual grouping text.

`topLevelPatternGroups(...)` splits on whitespace only when the parser is not
inside `[...]` and not inside `(...)`.

Each group is parsed leniently and counted by expanded note count. If more than
one non-empty group exists, the counts are joined with spaces.

Example:

```text
[S:RL][K] [S:R][K][S:L]
```

can infer grouping:

```text
3 3
```

Grouping is display and beaming metadata. It does not change the notation
grammar, subdivision, or playback timing by itself.

## Measure Calculation

`DrumSheetNotationDocument.fromPattern(...)` parses text and then chunks the
flattened notes into computed measures.

Measure size is derived from:

- `timeSignature`
- `subdivision`
- `feel`

Examples:

| Metadata | Notes per 4/4 measure |
| --- | --- |
| eighth straight | 8 |
| sixteenth straight | 16 |
| eighth triplet | 12 |
| sixteenth triplet | 24 |

If the parsed note list is empty, the Dart document contains one empty measure.
The Flutter WebView host detects empty renderable content and renders an empty
placeholder instead of sending the empty measure to the Web renderer.

If the note count is shorter than or equal to one computed measure, the Dart
document contains one measure. If longer, the note list is chunked into
multiple measures.

Audio preview extends the last note in a short measure to the end of that
measure for timing. It does not insert an authored rest into the notation text.

## Serialization

`DrumSheetPatternParser.serialize(...)` writes canonical voice-first syntax.

Rules:

- voice labels serialize to canonical labels only
- events serialize with one space between bracketed events
- absent sticking omits the colon
- serialization never writes a trailing colon
- stroke order is preserved
- accents serialize as `^R` and `^L`
- ghosts serialize as `(R)` and `(L)`
- open hi-hat serializes as `OHH`
- aliases serialize back to canonical labels
- redundant internal separators are removed
- rest notes cannot be serialized as voice-first text and throw an
  `ArgumentError`
- per-note value overrides are not represented in voice-first text

Examples:

```text
[HH]
[OHH]
[OHH:R]
[S:LRLR]
[S:(L)(L)^R]
[HH K]
[OHH:R K]
```

Contiguous notes with the same voices and serializable strokes can collapse
back into one multi-stroke phrase:

```text
[S:^R] [S:(L)] [S:(L)]
```

can serialize as:

```text
[S:^R(L)(L)]
```

`parse(serialize(parse(source)))` must preserve notation meaning for supported
voice-first text semantics.

## Playback

Voice determines playback sound.

- `HH` maps to closed hi-hat playback semantics.
- `OHH` maps to open hi-hat playback semantics.
- `OHH` currently uses `PatternAudioSampleV1.openHihat`, whose asset path is
  `assets/audio/hihat.wav`.
- `CR` maps to the crash sample currently named `accentCrash`.
- `RD` maps to the ride sample currently named `accentRide`.

Playback token selection is current implementation behavior:

- rest notes become rest tokens
- flam notes become flam tokens
- any note containing kick becomes a kick token
- otherwise, the first authored left-hand stroke makes the token left
- otherwise, the token defaults to right

Playback voice selection keeps semantic drum voices distinct. Additional
simultaneous voices are emitted as additional cues at the same token index.

Sticking cues are derived from structured per-voice strokes when present. If no
structured sticking exists, the code attempts to parse the note-level sticking
string as semantic stroke text for the primary voice.

No hand is inferred from a voice in authored notation. Missing sticking remains
absent until a transport boundary requires a concrete cue.

## Guided Practice

Guided Practice derives expected events from the same parsed notation and audio
preview plan used by lesson preview.

Current behavior:

- repeated sections follow `repeat_count`
- simultaneous playback cues with the same offset are grouped into one expected
  event
- selected notation indexes are carried from audio token indexes back to
  flattened display indexes
- expected LED cues use semantic playback voices and sticking cues

Examples:

- `[HH K]` creates one simultaneous expected event: closed hi-hat + kick, no
  authored sticking.
- `[OHH K]` creates one simultaneous expected event: open hi-hat + kick, no
  authored sticking.
- `[OHH:R K]` creates one simultaneous expected event with right-hand sticking
  metadata on the open hi-hat only.
- `[S:(L)(L)^R]` creates three sequential expected snare events.

## LED Output

The physical LED hardware owns rendering, animation, brightness, and endpoint
indicator behavior. The app emits semantic voice and stroke cues; it does not
address pixels or left/right output channels directly.

Direct live MIDI hit commands use backward-compatible voice flashes:

| Drum input voice | Direct command |
| --- | --- |
| snare | `SNARE\n` |
| kick | `KICK\n` |
| closed hi-hat | `HIHAT\n` |
| open hi-hat | `HIHAT\n` |
| hi-hat pedal | `HIHAT\n` |
| tom 1 | `TOM1\n` |
| tom 2 | `TOM2\n` |
| floor tom | `FLOORTOM\n` |
| crash | `CRASH\n` |
| ride | `RIDE\n` |

Cue-frame voice names distinguish open hi-hat:

| Drum input voice | Cue-frame voice |
| --- | --- |
| closed hi-hat | `HIHAT` |
| open hi-hat | `OHH` |
| hi-hat pedal | `HIHAT` |

Atomic cue frames use this shape:

```text
FRAME_BEGIN
ANIMATION,<TYPE>,...
CUE,<VOICE>,<STROKE_SEQUENCE>
FRAME_END
```

Every emitted frame includes exactly one animation primitive before cues.

Flutter maps app behavior to controller primitives:

| App behavior | Controller primitive | Default timing |
| --- | --- | --- |
| Guided Practice | `ANIMATION,SOLID,55` | 55 ms retrigger |
| Hear It | `ANIMATION,FLASH,220` | 220 ms decay |
| Play Along | `ANIMATION,FADE_IN,250,180` | 250 ms lead, 180 ms decay |

The controller never receives educational mode names such as Guided Practice,
Hear It, or Play Along.

Cue stroke syntax uses the same semantic stroke tokens as the notation language:

| Stroke | Meaning |
| --- | --- |
| `R` | normal right-hand cue |
| `L` | normal left-hand cue |
| `(R)` | ghost/dim right-hand cue |
| `(L)` | ghost/dim left-hand cue |
| `^R` | accented right-hand cue |
| `^L` | accented left-hand cue |

Adjacent strokes in one `CUE` field are illuminated together. For example,
`(L)R` means a dim left cue and normal right cue in the same displayed event,
and `(R)^L` means a dim right cue with accented left cue.

Sequential notation strokes normally expand into separate playback or Guided
Practice events and therefore produce separate cue frames.

Because the controller requires a stroke field for every cue, LED frame
encoding resolves absent sticking at the transport boundary to the configured
default stroke, currently normal right-hand `R`. This default is not written
back into authored notation.

Examples:

```text
[HH]      -> CUE,HIHAT,R
[OHH]     -> CUE,OHH,R
[OHH:R]   -> CUE,OHH,R
[S:(R)]   -> CUE,SNARE,(R)
[S:^R]    -> CUE,SNARE,^R
[S:(L)R]  -> CUE,SNARE,(L)R
[OHH K]   -> CUE,OHH,R and CUE,KICK,R in one atomic frame
```

## MIDI Capture

MIDI Pattern Capture emits canonical voice-first notation text.

Examples:

```text
[HH]
[OHH]
[S]
[S:^R(L)(L)]
[HH K]
[OHH K]
```

Capture supports these voice mappings:

| `DrumVoice` | Emitted voice |
| --- | --- |
| `snare` | `S` |
| `kick` | `K` |
| `hiHatClosed` | `HH` |
| `hiHatPedal` | `HH` |
| `hiHatOpen` | `OHH` |
| `tom1` | `T1` |
| `tom2` | `T2` |
| `floorTom` | `FT` |
| `crash` | `CR` |
| `ride` | `RD` |
| `unknown` | skipped |

The LEKATO/General MIDI map distinguishes closed hi-hat note 42 and open
hi-hat note 46. When input maps to `hiHatOpen`, capture emits `OHH`.

Default capture behavior:

- simultaneous hits are grouped when their offsets are within 30 ms of the
  group start
- duplicate voices inside one simultaneous group collapse to the strongest
  velocity hit
- grouped voices serialize in capture voice order: crash, ride, closed hi-hat,
  open hi-hat, hi-hat pedal, snare, tom 1, tom 2, floor tom, kick
- normal velocities do not invent sticking
- velocity articulation is supported for all known voices except kick and
  hi-hat pedal
- velocity `<= 63` becomes a ghost stroke
- velocity `>= 100` becomes an accented stroke
- ghost capture defaults to left hand
- accent capture defaults to right hand

These thresholds and hand defaults are capture configuration, not notation
grammar.

Capture analyzes a raw hit timeline after MIDI input is collected. The live
MIDI callback is not the final pattern serializer.

Repeated-pattern recognition emits:

- canonical editable voice-first notation text
- sidecar timing metadata in `CapturedPatternResult`, including subdivision,
  feel, and note-value overrides when available

The notation language intentionally does not gain inline duration syntax for
capture. Mixed subdivision evidence must be represented through render/save
metadata where available.

## Render Document Contract

The renderer accepts render-ready JSON, not notation text.

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
1n
2n
4n
8n
16n
32n
```

Supported render voices:

```text
hihat
openHiHat
ride
crash
snare
tom1
tom2
floorTom
kick
```

Render document parsing behavior:

- `measures` must be a non-empty array.
- each `measure.notes` must be a non-empty array in the Web parser
- non-rest notes must have a non-empty valid `voices` array
- rest notes ignore voices and render at the rest position
- `subdivision` defaults to `8n`
- `feel` defaults to `straight`
- `timeSignature` defaults to `4/4`
- `repeatCount` must be a positive integer when present
- sticking labels are uppercased
- boolean flags are true only when the field is exactly `true`

The Dart model can construct an empty measure for empty parsed text; the
Flutter WebView host short-circuits empty renderable documents before calling
the Web renderer.

## Rendering Behavior

Current Web renderer behavior:

- `openHiHat` renders at the closed hi-hat staff position with an x-notehead
  and an open-circle marker above the notehead.
- `hihat`, `crash`, and `ride` use x-noteheads.
- `tom1`, `tom2`, `floorTom`, `snare`, and `kick` use normal noteheads.
- default stem mode is `single`, which renders all notes up-stem as one compact
  rhythmic voice.
- `stemMode: "mapped"` uses the first mapped voice's stem direction.
- `feel: "triplet"` creates tuplets over groups of three `8n` notes or groups
  of six `16n` notes.
- accents render as `>` annotations above the note.
- ghost notes render with notehead parentheses when VexFlow supports them.
- flam render documents attach a grace-note group when VexFlow supports it.
- sticking labels render above the accent annotation row unless
  `showSticking: false`.
- multi-voice sticking labels are simplified for display: one-character labels
  are kept; longer labels prefer `R`, then `L`, then `K`, then `F`.
- selection metadata is based on flattened event indexes, measure indexes, and
  measure-note indexes.

The open hi-hat marker is anchored to the actual open-hi-hat notehead geometry,
including inside chords. It is not positioned by a fixed staff-origin offset.

## Legacy And Compatibility Paths

The following are current code paths but are not strict voice-first notation
syntax:

- `PatternSequenceV1.parse(...)` accepts legacy compact tokens `R`, `L`, `K`,
  `F`, `X`, and `_` for practice-item sequence compatibility.
- Practice Session and Pattern Screen can construct `DrumSheetNotationNote`
  lists directly from legacy `PracticeItemV1.sequence`, accent indexes, ghost
  indexes, voice assignments, notation subdivision, and note-value overrides.
- `web/sheet_notation/demo.js` accepts compact demo patterns and bracketed
  voice/duration override forms such as `[T1:L]` and `[16:R]`.
- Render documents can represent rests, flams, ties, and per-note values even
  though the strict voice-first text grammar cannot author those inline.

These paths may feed rendering or tests, but they must not be cited as the
authored lesson notation grammar.

## Implementation Sources

Text language and Flutter model:

- `lib/features/practice/widgets/sheet_notation_display.dart`

Lesson authoring and validation:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`
- `lib/features/coach/lesson_notation_document.dart`
- `assets/content/index.yaml`
- `assets/content/lessons/<level>/<skill>/<lesson>.yaml`

MIDI capture:

- `lib/features/midi/midi_pattern_capture.dart`
- `lib/features/midi/drum_kit_mapper.dart`
- `lib/features/midi/midi_input_models.dart`

Audio, Guided Practice, and LED transport:

- `lib/features/practice/pattern_audio_service.dart`
- `lib/features/practice/pattern_led_playback_output.dart`
- `lib/features/practice/sticking_cue.dart`
- `lib/features/guided_practice/guided_practice_sequence_builder.dart`
- `lib/features/midi/drum_voice_led_command_mapper.dart`
- `lib/features/midi/led_frame_command_encoder.dart`
- `lib/features/midi/led_controller_protocol.dart`

Web render runtime:

- `web/sheet_notation/document.js`
- `web/sheet_notation/renderer.js`
- `web/sheet_notation/duration.js`
- `web/sheet_notation/voice_mapping.js`
- `web/sheet_notation/types.d.ts`
- `web/sheet_notation/app_host.html`

Legacy/demo adapter:

- `web/sheet_notation/demo.js`

Generated file:

- `web/sheet_notation/app_renderer.js`

Do not edit `web/sheet_notation/app_renderer.js` by hand. Regenerate it with:

```sh
npm run build:sheet-notation-app
```

## Contract Tests

Current behavior is covered primarily by:

- `test/sheet_notation_display_test.dart`
- `test/lesson_plan_loader_test.dart`
- `test/midi_pattern_capture_test.dart`
- `test/serial_led_controller_test.dart`
- `test/pattern_led_playback_output_test.dart`
- `test/sheet_notation/sheet_notation.test.mjs`
