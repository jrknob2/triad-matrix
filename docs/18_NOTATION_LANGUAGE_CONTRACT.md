# 18 - Notation Language Contract

## Purpose

This is the single source of truth for the Drumcabulary notation language.

Other files may implement, render, test, or demonstrate the language, but they
should not redefine it. When the notation language changes, update this file
first, then update parser, renderer, lesson content, and tests to match.

## Current Product Boundary

The current product is a Coach lesson-plan MVP.

Notation is authored by lesson/content authors in YAML and by a small internal
authoring tool. The notation language must support compact lesson examples,
sheet rendering, audio preview, print/export, MIDI Pattern Capture, Guided
Practice, and LED cues.

## Core Model

The notation language is voice-first.

- drum voice is the required root
- sticking is optional
- absent sticking is semantically absent
- sticking is never inferred from the drum voice
- stroke sequences are ordered and sequential
- accents and ghosting apply to individual strokes
- simultaneous voices share one bracketed rhythmic event

Canonical form:

```text
[VOICE[:STROKE_SEQUENCE]]
```

Examples:

```text
[S]
[HH]
[OHH]
[K]
[S:R]
[S:LRLR]
[S:(L)(L)^R]
[HH K]
[HH:R S:L]
[OHH:R K]
```

Old sticking-first notation such as `RLRL`, `K`, `^R`, `(L)`, `[HH K:R]`, and
`[T1:R]` is obsolete for authored lesson notation and must not parse in strict
mode.

## Pattern Metadata

Pattern metadata belongs beside the notation string in YAML.

This section describes notation-level timing/display metadata only. Lesson and
exercise discovery metadata is owned by `docs/29_LESSON_METADATA_CONTRACT.md`.

Supported metadata:

- `subdivision`
- `time_signature`
- `repeat_count`

Supported `subdivision` values:

- `8`
- `16`
- `triplet`
- `16_triplet`

Triplet timing is metadata, not syntax. Grouping spaces do not create tuplets.

## Voice Vocabulary

Supported canonical author-facing voice labels:

| Label | Voice |
| --- | --- |
| `K` | kick |
| `S` | snare |
| `HH` | closed hi-hat |
| `OHH` | open hi-hat |
| `T1` | tom 1 |
| `T2` | tom 2 |
| `FT` | floor tom |
| `CR` | crash |
| `RD` | ride |

`HH` means closed hi-hat.

`OHH` means open hi-hat. It is a first-class notation, semantic, playback, MIDI,
selection, and Guided Practice voice. It is not an accent, articulation, or
playback-only flag on `HH`.

The renderer may accept existing long-form aliases internally, but serialization
must use the canonical labels above.

## Stroke Sequences

A stroke sequence is an ordered list of stroke tokens.

Supported tokens:

| Token | Meaning |
| --- | --- |
| `R` | normal right-hand stroke |
| `L` | normal left-hand stroke |
| `^R` | accented right-hand stroke |
| `^L` | accented left-hand stroke |
| `(R)` | ghosted right-hand stroke |
| `(L)` | ghosted left-hand stroke |

Examples:

```text
[S:LRLR]
[S:(L)(L)^R]
[OHH:RRRR]
```

Accent and ghosting belong to individual strokes. Forms such as `[^S:R]` and
`[(S):L]` are invalid. Use `[S:^R]` and `[S:(L)]`.

## Grammar

Equivalent grammar:

```text
pattern          := event+
event            := "[" voiceSpec (separator voiceSpec)* "]"
voiceSpec        := voice [":" strokeSequence]
strokeSequence   := stroke+
stroke           := hand | "^" hand | "(" hand ")"
hand             := "L" | "R"
separator        := one or more spaces or commas
```

Rules:

- voice is required
- sticking is optional
- colon introduces a non-empty stroke sequence
- a voice without a colon is valid
- no sticking must not default to R or L
- unknown voices fail validation
- malformed stroke sequences fail validation
- old unqualified LRK patterns fail validation

Valid:

```text
[HH K]
[HH]
[HH S]
[OHH K]
[S:(L)(L)^R]
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
RLRL
K
```

## Multi-Stroke Expansion

A stroke sequence represents consecutive strokes on the same voice.

Examples:

```text
[S:LRLR]
```

expands to four sequential snare events.

```text
[S:(L)(L)^R]
```

expands to three sequential snare events: ghost left, ghost left, accented
right.

The existing pattern subdivision supplies the rhythmic value of each expanded
stroke. The notation language does not create a second timing system.

## Simultaneous Sequence Alignment

Every voice specification inside one bracket must expand to the same stroke
count.

- a voice with no sticking has a stroke count of one
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

1. HH R + S L
2. HH R + S R
3. HH R + S L
4. HH R + S R

## Open Hi-Hat Rendering

`OHH` renders as a hi-hat x-notehead at the existing hi-hat staff position plus
a small open-circle marker above the notehead.

`HH` renders as the same x-notehead without the open marker.

The marker must remain associated with the note during wrapping, selection, and
hit testing. It must not be clipped.

## Serialization

Serialization uses canonical voice-first syntax:

```text
[S]
[HH]
[OHH]
[K]
[S:R]
[S:LRLR]
[S:(L)(L)^R]
[HH K]
[OHH:R K]
```

Rules:

- omit the colon when sticking is absent
- never serialize a trailing colon
- preserve stroke order
- serialize accents as `^R` and `^L`
- serialize ghosts as `(R)` and `(L)`
- serialize open hi-hat as `OHH`
- never collapse `OHH` to `HH`
- use canonical spacing

`parse(serialize(parse(source)))` must preserve semantic meaning.

## Playback

Voice determines playback sound.

- `HH` maps to closed hi-hat playback semantics.
- `OHH` maps to open hi-hat playback semantics.
- If an open-hi-hat sample is unavailable, playback may temporarily use the
  closed hi-hat audio asset, but the semantic voice must remain distinct.

Sticking must never determine the playback voice.

## Guided Practice

Guided Practice derives expected events from the same parsed notation and
playback semantic events used by lesson preview.

Examples:

- `[HH K]` creates one simultaneous expected event: closed hi-hat + kick, no
  sticking cues.
- `[OHH K]` creates one simultaneous expected event: open hi-hat + kick, no
  sticking cues.
- `[OHH:R K]` creates one simultaneous expected event with right-hand sticking
  metadata only on the open hi-hat.
- `[S:(L)(L)^R]` creates three sequential expected snare events.

No hand is inferred from voice.

## LED Output

The physical LED hardware owns all rendering, animation, brightness, and
endpoint indicator behavior. The app emits only semantic voice and stroke cues;
it never addresses pixels or left/right output channels directly.

Closed and open hi-hat remain distinct in cue frames:

- `HH` maps to the controller voice `HIHAT`.
- `OHH` maps to the controller voice `OHH`.

Direct live MIDI hit commands remain backward-compatible voice flashes, so both
closed and open hi-hat live hits still use `HIHAT\n` in that direct-hit path.

Atomic cue frames use the controller protocol. Every frame must include exactly
one animation primitive before any committed frame end:

```text
FRAME_BEGIN
ANIMATION,<TYPE>,...
CUE,<VOICE>,<STROKE_SEQUENCE>
FRAME_END
```

Flutter owns educational modes and maps them to controller rendering
primitives:

| App behavior | Controller primitive | Default timing |
| --- | --- | --- |
| Guided Practice | `ANIMATION,SOLID,55` | 55 ms retrigger |
| Hear It | `ANIMATION,FLASH,220` | 220 ms decay |
| Play Along | `ANIMATION,FADE_IN,250,180` | 250 ms lead, 180 ms decay |

The controller never receives educational mode names such as Guided Practice,
Hear It, or Play Along. Bare frames without `ANIMATION` are invalid.

The third field uses the same semantic stroke notation as the voice-first
notation language:

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
and `(R)^L` means a dim right cue with accented left cue. Sequential notation
strokes normally expand into separate playback or Guided Practice events and
therefore produce separate cue frames.

Only canonical semantic stroke syntax is valid in cue frames. Direct live MIDI
hit commands such as `SNARE`, `KICK`, and `HIHAT` remain supported and are not
cue frames.

No sticking remains semantically absent in notation, capture, and playback
models. Because the controller requires a stroke field for every frame cue, LED
cue generation resolves absent sticking at the transport boundary to the app's
configured default stroke, currently normal right-hand `R`. This default is not
written back into authored notation.

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

MIDI Pattern Capture emits voice-first notation.

Examples:

```text
[HH]
[OHH]
[S]
[S:^R(L)(L)]
[HH K]
[OHH K]
```

The LEKATO/General MIDI map distinguishes closed hi-hat note 42 and open
hi-hat note 46. When the hardware provides `hiHatOpen`, capture emits `OHH`.

MIDI capture uses velocity to classify captured hand-played voices as normal,
accented, or ghosted. Normal hits omit sticking. Accented and ghosted hits are
emitted as semantic stroke notation so captured expressive phrases remain
voice-first, such as `[S:^R(L)(L)]`. The initial capture thresholds are velocity
`<= 63` for ghost strokes and `>= 100` for accented strokes. The current default
hand assignment is a capture heuristic: accents use `R`, ghosts use `L`. These
thresholds and hand defaults are capture configuration, not notation grammar.

Pattern capture is framed by user-selected musical metadata: time signature,
pattern length in measures, tempo mode, fixed BPM when used, count-in length,
and whether capture should stop automatically when a repeated cycle is
recognized. Capture analyzes a raw hit timeline after MIDI input is collected;
the MIDI callback must not be the final pattern serializer.

Repeated-pattern recognition emits two artifacts:

- the canonical editable voice-first notation string
- sidecar rhythmic metadata supported by the app model, such as time signature,
  default subdivision, and per-note note-value overrides

The notation language intentionally does not gain inline duration syntax for
capture. Mixed subdivision evidence must be represented through render/save
metadata where available. When the current sidecar model cannot fully represent
mixed straight/triplet feel, capture should preserve the editable notation and
surface the limitation rather than inventing ambiguous notation syntax.

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

## Implementation Sources

Language-facing implementation files:

- `lib/features/practice/widgets/sheet_notation_display.dart`
- `web/sheet_notation/document.js`
- `web/sheet_notation/renderer.js`
- `web/sheet_notation/duration.js`
- `web/sheet_notation/voice_mapping.js`
- `web/sheet_notation/types.d.ts`

Lesson authoring source:

- `assets/content/index.yaml`
- `assets/content/lessons/<level>/<skill>/<lesson>.yaml`

Generated file:

- `web/sheet_notation/app_renderer.js`

Do not edit `web/sheet_notation/app_renderer.js` by hand. Regenerate it with:

```sh
npm run build:sheet-notation-app
```
