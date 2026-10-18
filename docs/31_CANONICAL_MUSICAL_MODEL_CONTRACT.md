# Canonical musical model contract — schema 1

Status: Pass 2 foundation, opt-in only. No existing consumer uses this model yet.

## Ownership and types

`lib/core/music/canonical_musical_document.dart` defines immutable value objects:

- `CanonicalMusicalDocument`: explicit schema version, meter, deterministically
  ordered events, measure boundaries, phrase groups and tuplet groups.
- `TimedMusicalEvent`: stable caller-supplied ID, onset, performed duration,
  written duration, rhythmic layer ID, and either strikes or an explicit rest.
- `InstrumentStrike`: existing `DrumVoiceV1` instrument identity, optional hand,
  normal/accent/ghost articulation, and immutable namespaced string metadata.
- `MusicalMeasure`: ID, onset, actual duration, meter and explicit incomplete flag.
- `PhraseGroup`: ID, ordered event references, optional label/display intent.
- `TupletGroup`: ID, ordered event references, actual:normal ratio and explicit
  partial-group flag. `scaleDuration` applies the ratio exactly.
- `MusicalTime` and `MusicalTimeSignature`: exact arithmetic and meter validation.

The instrument vocabulary reuses the existing domain enum. Sheet-only stroke and
voice types stay in the existing notation layer; the adapter maps them explicitly.
This separate model has a migration purpose: it can represent exact timing and
simultaneous per-instrument strikes that legacy `PatternTokenV1` cannot encode.
It neither owns authored-text grammar nor creates another text parser.

All collections are defensively copied and exposed as unmodifiable lists/maps.
Constructors validate with runtime errors, not assertions alone. Invalid direct
model construction throws `ArgumentError`; adapter failures return diagnostics.

## Time and invariants

One unit is one quarter-note beat, independent of tempo. Whole/half/quarter/
eighth/sixteenth/thirty-second values are 4, 2, 1, 1/2, 1/4, 1/8 units.
`MusicalTime` stores reduced `BigInt` numerator/positive denominator pairs.
Addition, subtraction, multiplication, division and ordering are exact, including
on web; no floating-point value is authoritative. The arithmetic type allows
negative intermediate differences, but event/measure onsets must be nonnegative
and durations must be positive. Zero denominators and division by zero fail.

Schema 1 requires:

- Unique nonempty event IDs and deterministic onset/layer/ID ordering.
- Nonempty layers; a sounding event has strikes, and a rest has none.
- Nonempty documents with contiguous measure boundaries starting at zero.
- Positive meter numerator and a positive power-of-two denominator.
- One meter throughout a document; every measure agrees with it.
- Full measures equal their meter capacity. Short measures explicitly set
  `isIncomplete`; overflow and falsely marked full/incomplete measures fail.
- Every event fits within one measure. Each active layer in each measure covers
  its actual duration without overlaps or implicit gaps; use explicit rests.
  A layer may be inactive for an entire measure.
- Group IDs are unique across phrase/tuplet groups; references exist, are unique
  within each group and follow document event order.

Event IDs are independent of timing and grouping. Direct callers retain IDs when
editing existing events. The adapter creates deterministic source-scoped IDs
from measure/note positions. These are stable for repeat conversion of unchanged
source structure, **not** guaranteed across insertion, deletion or rebar operations.
Cross-edit identity reconciliation belongs to a future editing/integration pass.

## Phrase grouping versus tuplets

Phrase groups have no role in duration calculation. They may cross beats,
measures and layers, and may overlap other phrase groups. Five ordinary
sixteenths labeled “5” still occupy exactly **5/4 quarter-note beats**.

A tuplet applies `normal / actual` to each member's written duration. Five
sixteenths at 5:4 each occupy `(1/4) * (4/5) = 1/5` beats, totaling exactly
**one quarter-note beat**. The document validates supplied performed durations
against this relationship; attaching a group cannot silently retime immutable
events. Construct durations with `TupletGroup.scaleDuration` or equivalent exact
arithmetic. Onsets and neighboring boundaries must already agree.

Tuplet members must be contiguous in one rhythmic layer. Complete groups have
`actual` member events; explicitly incomplete groups have fewer. Nested or
overlapping tuplets are rejected in schema 1. Tuplet ratios are never inferred
from phrase labels, member counts, spaces or legacy grouping metadata.

## One-way conversion

`lib/features/practice/sheet_to_canonical_adapter.dart` accepts an existing
`DrumSheetNotationDocument`, not pattern text or `PracticeItemV1` tokens.
`DrumSheetPatternParser` remains the authoritative authored-text parser.

The adapter:

1. Validates meter, source identity, measures and source note semantics.
2. Preserves every source voice in a single simultaneous event and maps optional
   voice-specific hand/articulation without inventing hand assignments. Expanded
   stroke sequences are already separate notes in the source document.
3. Uses explicit note values when present, otherwise the document subdivision.
   Written durations preserve those resolved rhythmic values; source formatting
   choices such as an explicit value equal to the default are not distinguished.
4. Supports existing triplet feel exactly: eighth, sixteenth and thirty-second
   notes scale by 2/3; quarter and longer notes remain ordinary. Derived 3:2 ratio
   groups partition consecutive equal-value triplet runs in each measure into
   threes, with residual groups explicitly partial. These groups record the
   global feel's timing ratio, not an assertion of authored phrase/bracket intent.
5. Preserves supplied measure boundaries. Short measures produce an
   `incomplete_measure` warning and retain actual duration; no implicit rests,
   last-note stretching, preview padding, rebar or truncation is performed.
6. Leaves phrase groups empty: their authored membership is not available in the
   source document. It does not infer them from stroke counts or note spacing.

Structured per-voice strokes are authoritative. Source aggregate accent/ghost
flags are summaries and never spread to unassigned voices. Inconsistent summary
flags/sticking return diagnostics. Legacy single-voice L/R plus aggregate
articulation is supported; multi-voice unassigned sticking/dynamics is rejected
when its distribution is ambiguous.

`CanonicalConversionResult` contains an immutable diagnostic list and either a
complete document or null. Errors never return a partial musical document.
Diagnostics have stable codes, severity and source measure/note indexes where
applicable. They cover invalid meter/document, invalid source identity,
unsupported repeats, unsupported ties/flams, conflicting rests, duplicate voices,
invalid voice mappings, ambiguous/conflicting sticking or articulation, empty
measures and overflow. An empty document is an error. Incomplete measures are
warnings, so conversion can still succeed.

## Limits and future integration boundaries

No changes are made to VexFlow, SVG, YAML, rendering, playback scheduling, Guided
Practice, LEDs, authored pattern storage or Pass 1 preservation behavior.
`PatternTimingV1` float spans/pulses are not converted: they are not authoritative
source data for this adapter. There is no reverse conversion or migration.

Schema 1 does not support ties/sustains, flam grace timing, repeat arrangements,
nested tuplets, meter changes, empty scores, cross-measure sustained events or
identity reconciliation across edits. Unsupported source data is diagnosed,
not approximated. Articulation extensions have immutable string metadata, but
unknown techniques require explicit future consumer interpretation.

Future consumers must opt in through reviewed adapters and compare canonical
results against their existing behavior before migration. In particular, the
existing preview's measure padding and the legacy scheduler's pulse heuristics
remain distinct; this foundation does not promise a matching playback timeline.

## Pass 2 validation

- New model/adapter coverage: **42 tests passed**, including exact 5:4 timing,
  ordinary five-note phrasing, group validation, immutable collections and
  conversion diagnostics.
- Combined new tests plus Pass 1 preservation, existing canonical sequence,
  scheduler, sheet notation, selection, controller persistence-snapshot,
  formatter, audio and LED regressions: **142 passed**.
- JavaScript sheet-notation suite: **61 passed**.
- Static analysis of the four new Dart files: **no issues**.
- Full `flutter test`: **315 passed, 3 failed**. All three failures are existing
  widget tests reporting `shaders/ink_sparkle.frag`: “Unsupported runtime stages
  format version. Expected 2, got 1.” They occur in MIDI Capture's record-reset
  test, Session Summary's Play It Again test, and Insights' breadcrumb drill-in
  test. Those tests and their production paths do not import the new model or
  adapter. No SDK/cache workaround or unrelated widget change was made.

Tests are in `test/canonical_musical_model_test.dart` and
`test/sheet_to_canonical_adapter_test.dart`. The existing Pass 1 regression tests
remain unchanged. No Pass 3 work was undertaken.
