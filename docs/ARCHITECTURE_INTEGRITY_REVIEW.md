# Architecture Integrity Review

Date: 2026-10-17  
Branch: `feature/level-skill-lesson-architecture`  
Reviewed revision: `68de4af`

Investigation only. No implementation corrections were made.

## Summary

Authored text survives the current editor and draft-creation paths, and the
sheet-notation parser preserves simultaneous voices and aligned stroke sequences.
However, `PatternSequenceV1` is a lossy legacy projection, not a complete canonical
representation of current notation. Multiple independently supplied representations
can disagree. A controller save that omits authored text can overwrite it with that
lossy projection. Default playback ignores grouping and uses token-count heuristics.

Existing relevant tests pass. These results do not establish that every valid
authored pattern survives every save, reload, or playback route.

## Contract interpretation

- `docs/06_APP_SPEC.md:5-16` explicitly labels its old navigation/deferred-system
  descriptions historical. Restored authoring, hardware, and playback are not
  treated as regressions against that obsolete scope.
- `docs/06_APP_SPEC.md:24-29` identifies bundled lesson YAML and the shared renderer
  as source of truth, delegating grammar to documents 18 and 19. This supports
  preserving authored notation rather than replacing it with a sticking sequence.
- `docs/16_PATTERN_AND_PRACTICE_CONTEXT_CONTRACT.md:5-15` separates playable pattern
  text from practice behavior. Lines 37-41 require compact readouts to preserve
  authored groups, dynamics, overrides, and spaces. Lines 48-62 require uppercase
  normalization at editing/saving boundaries without continuous grouping rewrites.
- The saving rule at `docs/16_PATTERN_AND_PRACTICE_CONTEXT_CONTRACT.md:157-160`
  requires validation through the editor/preview grammar. Grammar details are
  delegated to document 18, not independently defined by documents 06 or 16.
- Neither requested contract requires display grouping to determine playback
  duration. Ignoring grouping is confirmed behavior and an API/compatibility
  concern; automatically making grouping control timing would need a deliberate
  compatibility decision.

## Current representation pipeline

| Layer | Representation and ownership | References |
| --- | --- | --- |
| Authored content | `PatternItem.pattern` is text; runtime `PracticeItemV1` stores both text and a legacy sequence, plus parallel dynamics/voice/value metadata | `lib/core/practice/practice_domain_v1.dart:549-565`, `:867-977` |
| Legacy parse | One token kind per position; brackets yield at most one recognized character | `lib/core/practice/practice_domain_v1.dart:262-265`, `:341-405` |
| Semantic notation | Bracketed voice specs preserve multiple voices and expand aligned strokes into separate notes | `lib/features/practice/widgets/sheet_notation_display.dart:1721-1802` |
| Author save | Rich parser validates text; mapper derives legacy tokens and one primary voice; original normalized text is supplied separately | `lib/features/library/pattern_screen.dart:918-977`; `lib/features/library/exercise_authoring_mapper.dart:25-56` |
| MIDI draft | Same rich-parser-to-legacy-projection approach | `lib/state/app_controller.dart:2246-2289` |
| Storage | JSON stores both authored text and token symbols; reload prefers stored tokens for sequence and text for pattern | `lib/state/persistence/app_state_store.dart:279-360` |
| Sheet preview playback | Semantic notes produce explicit timing spans and additional simultaneous voices | `lib/features/practice/widgets/sheet_notation_display.dart:1324-1436` |
| Legacy session playback | Stored tokens/timing/primary voices plus additional voices reparsed from text by note index | `lib/features/practice/practice_session_screen.dart:1290-1366` |

## Confirmed discrepancies and implementation concerns

### 1. High: optional-pattern save can destroy authored notation

`savePracticeItemEdits` sets `nextSequence = sequence ?? existingItem.sequence`,
then `nextPattern = pattern ?? nextSequence.canonicalText`
(`lib/state/app_controller.dart:1958-1959`). Omitting both optional fields while
changing a title replaces saved notation with flattened token symbols. This
violates authored-text preservation and can also reset timing because the method
interprets the replacement as a structure change (`:1964-1981`).

**Executed reproduction:** create a draft from `[HH K] [S]`, then call the save
method with its existing dynamics/voices and a new title, omitting pattern and
sequence. The resulting pattern is `KR`. Brackets, authored spaces, and voice
information are lost. This is a verified API defect, not a reproduced failure of
the current editor: that editor supplies both fields (`pattern_screen.dart:968-969`).

**Minimal correction:** preserve existing authored text when neither structural
argument is supplied. Make sequence-only replacement an explicit compatibility
operation, with a documented policy rather than implicit text regeneration.

### 2. High: the canonical sequence cannot preserve current bracket semantics

`PatternTokenV1` stores only a token kind. The bracket parser takes the substring
after the first colon, scans for the first `R/L/K/F/X/_`, and discards everything
else (`practice_domain_v1.dart:355-365`, `:392-405`). It does not store a voice set,
per-voice sticking, original bracket text, or aligned stroke expansion.

Executed examples:

| Input | Legacy `canonicalText` / positions | Rich parser note count |
| --- | --- | --- |
| `[HH]` | empty / 0 | 1 |
| `[S]` | empty / 0 | 1 |
| `[CR K]` | `R` / 1 | 1, with crash and kick |
| `[S:RLRL]` | `R` / 1 | 4 |
| `[HH:RR S:LL]` | `R` / 1 | 2, each with both voices |

The `R` in `[CR K]` is taken from the voice label, not an authored hand cue.
Unrecognized bracket bodies can silently yield no token instead of failing.
`canonicalText` and `toDisplayText` cannot reconstruct authored notation
(`practice_domain_v1.dart:408-423`). This is a confirmed representation mismatch,
not proof that the current editor loses these events: its rich-parser mapper
preserves event counts while keeping original text separately.

**Minimal correction:** treat this sequence as a legacy projection. Route valid
voice-first input through the existing semantic parser at all relevant entry
points; never regenerate authored text from that projection. Share a projection
adapter rather than adding another bracket scanner. A richer domain event model
is a possible later design change, not necessary for the first preservation fix.

### 3. Medium: text/sequence consistency is not enforced

The constructor accepts independent `pattern` and `sequence`; its only related
assertion checks an optional `noteCount`, not agreement with text
(`practice_domain_v1.dart:950-966`). `copyWith(sequence: ...)` retains old text;
`copyWith(pattern: ...)` without a sequence invokes the lossy parser
(`:1010-1026`). These are confirmed API behaviors with inconsistent invariants.

Persistence independently stores both and trusts tokens on reload
(`app_state_store.dart:284-287`, `:316-335`). In addition, supplying only new text
to `savePracticeItemEdits` retains the existing sequence (`app_controller.dart:1958`).
Consequently, text/notation can describe different event counts from playback
and index-aligned markings. No executed real-database corruption was established.

**Minimal correction:** define authored text as authoritative for authored items;
derive and validate projections together when text changes. Validate supplied
projections semantically, without claiming the legacy token kinds encode every
voice. Preserve the legacy unbracketed-input path explicitly.

### 4. Medium: default playback ignores the grouping argument

`buildPlan` chooses pulse metadata first, nonempty explicit spans second, and
derived pulses otherwise (`pattern_playback_scheduler.dart:42-53`). It never
passes the caller's grouping to `_planFromAutoTiming`. That grouping-aware helper
exists at `:85-124`, but its fallback callers pass `PatternGroupingV1.none`
(`:156-160`, `:233-237`).

Default pulses begin at zero, split any six-token phrase at three, and recognize
seven-token repeated triads plus a tag (`:242-267`). Other nonempty lengths have
one pulse, so eight tokens consume one beat irrespective of four-note grouping.
An executed probe confirmed eight tokens with `none` and `fourNote` both produce
one beat. `PatternTimingModeV1.autoByGrouping` therefore misnames the actual policy
(`practice_domain_v1.dart:35`, `:503-513`).

This conflicts with the API's apparent grouping behavior and the default timing
comment's broad legacy-safety claim (`practice_domain_v1.dart:888-893`), but is not
an established violation of document 16's separation of grouping and timing.
The current tests intentionally assert several of these pulse defaults.

**Minimal correction:** first document and test the intended default policy.
Prefer explicit timing metadata for authored rhythmic intent. Do not reconnect
the old grouping helper blindly: that would change audible durations for saved
items and existing tests.

## Potential issues requiring runtime verification

1. **Session/preview disagreement:** sheet preview derives spans from displayed
   note values and pads the last note to the measure (`sheet_notation_display.dart:1380-1408`),
   while legacy sessions consume stored timing (`practice_session_screen.dart:1293-1335`).
   Compare audible duration, highlights, metronome, and looping for the same
   authored phrase on reachable routes. No device playback comparison was run.
2. **Index drift:** session additional voices are recovered from a separate rich
   parse and joined to stored primary voices by index (`practice_session_screen.dart:1342-1366`).
   Test items loaded through legacy parsing, especially `[HH] [S]` and expanded
   stroke groups. The correctly mapped current editor path may avoid this drift.
3. **Per-voice dynamics/sticking:** the compatibility mapper stores aggregate
   dynamics and one primary voice (`exercise_authoring_mapper.dart:11-56`). Verify
   mixed per-voice markings across editor preview, saved-item playback, and LEDs;
   the richer sheet-preview audio path carries additional sticking metadata.
4. **Real persistence:** test the actual Isar JSON codec and reopening, including
   old records without tokens/pattern/timing and inconsistent dual representations.
   Existing fake-store restoration bypasses that codec.
5. **Exact whitespace:** compact readouts use `item.pattern.trim()`
   (`lib/features/app/app_formatters.dart:150-152`), preserving interior spaces but
   removing leading/trailing whitespace. This is a literal narrowing of document
   16's exact-text rule; editor save also trims text. Decide whether boundary
   whitespace is intentionally normalized before treating it as a product defect.

## Existing protection and missing regression coverage

| Behavior | Existing protection | Missing regression tests |
| --- | --- | --- |
| Legacy sequence/rests | `test/pattern_sequence_phase1_test.dart:6-44` checks positions, symbols, rests, and rejection of B | Cross-parser voice-only events, invalid bracket bodies, expansion counts, multiple voice assignments |
| Authored text preservation | `test/pattern_sequence_phase1_test.dart:73-97` preserves separate text; `test/app_formatters_test.dart:50` checks authored compact readout | Metadata-only controller save; sequence-only/text-only updates; no grouping rewrite with authored interior spaces |
| Rich group semantics | `test/sheet_notation_display_test.dart:12-86` tests optional sticking, simultaneous voices and aligned sequences; serialization at `:142-173` | Full editor save/reopen and subsequent playback of the same multi-voice/multi-stroke phrase |
| Source selection | `test/pattern_selection_sync_test.dart:6-36` protects source ranges and ghost groups | Selection and source mapping across expanded stroke groups after edits |
| Default timing | All six tests in `test/pattern_playback_scheduler_test.dart` protect current 3/4/5/6-token, triad-tag, and explicit-pulse defaults | Nonempty grouping vs none, eight-plus-token phrases, grouping remainder, pulse-vs-span precedence, incomplete/overlapping spans, active-index boundaries |
| Explicit timing/audio | `test/pattern_audio_service_test.dart:261` checks simultaneous cue offsets; `:293` explicit span offsets | Authored text through persistence to final audio plan; compare preview and saved-session timing |
| Hardware cue groups | `test/pattern_led_playback_output_test.dart` covers simultaneous cue grouping, start gates and partial-group feedback | Actual saved-pattern pipeline into audio/LED events; real-device timing |
| Saved drafts | `test/app_controller_hardening_test.dart:148-265` checks draft validation, text preservation, fake-store reload, stable IDs | Real JSON/Isar round trip; missing-token migration; inconsistent text/tokens; multivoice/expanded strokes and parallel metadata after reload |

The “grouped simple drills” audio test (`pattern_audio_service_test.dart:7`) uses
three tokens, so the default pulse heuristic yields the expected result even
without consulting grouping. It does not establish grouping support.
`test/helpers/fake_app_state_store.dart:3-25` stores snapshot objects directly;
its reload tests do not exercise `IsarAppStateStore` serialization.

## Verification results

Executed existing tests:

```sh
flutter test test/pattern_sequence_phase1_test.dart test/pattern_playback_scheduler_test.dart test/sheet_notation_display_test.dart test/pattern_selection_sync_test.dart test/app_controller_hardening_test.dart test/pattern_audio_service_test.dart test/pattern_led_playback_output_test.dart
flutter test test/app_formatters_test.dart
npm run test:sheet-notation
```

- First Flutter command: **88 passed**, exit 0.
- Formatter Flutter command: **4 passed**, exit 0.
- JavaScript notation suite: **61 passed**, exit 0.
- No failures in these existing tests; no full-suite or native app/device run.

Three temporary diagnostic tests in
`/private/tmp/drumcabulary_integrity_probe_test.dart` also passed, asserting the
observed lossy parse, ignored grouping, and metadata-save overwrite described
above. These are executed reproductions of defects/behavior, not newly added
repository regression tests. Passing a diagnostic that asserts a defect does
not mean the behavior satisfies the contracts. The diagnostic run required SDK
cache write access outside the repository after a sandbox denial.

## Minimal correction order and compatibility risks

1. Add preservation regressions and fix the omitted-pattern save fallback.
2. Define one semantic parse/projection boundary for authored text, then validate
   constructor/update/load invariants at appropriate boundaries. Keep compatibility
   for generated and old unbracketed sticking records.
3. Add real serialization fixtures before changing load precedence or repairing
   token arrays. Preserve source text and record diagnostics for inconsistent data.
4. Specify the timing policy and lock it with tests before changing scheduler
   defaults. Prefer explicit spans/pulses where musical durations are known.

Migration risks:

- Replacing authoritative text with `canonicalText` permanently loses voices,
  dynamics and phrasing. Already-overwritten text cannot be recovered from token
  symbols alone; backups or original authored sources may be needed.
- Rebuilding tokens from rich text can change position counts, invalidating
  stored accent/ghost indexes, voice/value arrays, pulses, and timing spans.
  Reconcile these together rather than changing only the token list.
- Some records intentionally pair rich text with a lossy but correctly sized
  legacy projection. Bytewise equality with reserialized text is not a valid
  consistency test. Older plain sticking input also needs a separate fallback.
- Changing automatic timing changes cycle duration, metronome pulses, highlight
  positions, audio and LED schedules without modifying saved text. Preserve or
  explicitly migrate old timing semantics; do not infer timing from display
  grouping merely because the legacy enum name suggests it.
- Existing JSON has no per-item pattern representation version in the reviewed
  item map (`app_state_store.dart:279-306`). Introduce explicit version handling
  if repair semantics cannot be safely distinguished from legacy records.

No corrections, migrations, or new repository tests were implemented in this pass.

## Pass 1 implementation: notation preservation invariant

The investigation above records the pre-fix revision. Pass 1 changes only the
controller save boundary and adds focused regression coverage.

`PracticeItemV1.pattern` is authoritative authored musical content.
`PatternSequenceV1`, token symbols, and `canonicalText` are derived compatibility
representations; they cannot reconstruct voice-first notation faithfully.

At `AppController.savePracticeItemEdits`:

- Explicit `pattern` text takes precedence, as in the current editor save flow.
- If text is omitted and the sequence is unchanged (or omitted), preserve the
  existing pattern exactly. Metadata edits must not regenerate musical content
  or cause an incidental structural change/timing reset.
- A changed sequence without replacement text may regenerate text only for
  legacy-only patterns containing the legacy symbols and space/hyphen separators.
- A changed sequence alone cannot replace rich notation. The method rejects that
  ambiguous operation before changing state; the caller must provide authored text.

The UI already validates with `DrumSheetPatternParser` and supplies text plus a
compatibility projection. Storage continues to write both fields independently;
reload retains authored text. This pass changes neither the schema nor the
meaning of legacy tokens, notation rendering, or playback timing.

Coverage in `test/notation_preservation_test.dart` verifies exact text preservation
for simultaneous voices, expanded strokes, accents, ghosts, structured multi-voice
sticking, interior spaces, title/description/tags/competency changes, launch tempo,
snapshot reload and subsequent saves. It also covers rejected ambiguous rich
sequence edits and permitted legacy sequence edits. Reload tests use the existing
fake snapshot store, not a native Isar database: real JSON/Isar round-trip coverage
remains a limitation. Existing inconsistent records, explicit mismatched text/token
pairs, text-only structural edits, and previously lost authored content are not
repaired by this pass.

Pass 1 validation:

- Before the fix, all six rich-notation metadata preservation cases failed
  (for example, `[HH K]` became `K`, and `[S:LRLR]` became `LRLR`). The ambiguous
  sequence-edit rejection test also failed because the old API accepted it.
- After the fix, all eight new tests passed. The combined controller, parser,
  selection, formatter, scheduler, audio, LED and preservation run passed
  **100 Flutter tests**. The JavaScript notation suite passed **61 tests**.
- `dart analyze lib/state/app_controller.dart test/notation_preservation_test.dart`
  reported no issues. No unrelated failures occurred in the final validation.
- No schema migration, rendering, or playback changes were made. Pass 2 was not
  started.
