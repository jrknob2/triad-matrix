# 17 - MVP Reset Handoff

## Purpose

Use this document to brief a new chat or contributor on the current Drumcabulary MVP reset.

The reset is intentionally narrow: Coach is now a content-first, print-first lesson-plan surface. The app should help a user read, hear, and print authored lessons. It should not restore the broader practice/session/product systems during MVP refinement.

Current date of this handoff: 2026-06-23.

---

## Current Branch And State

Current working branch:

- `feature/lesson-mvp-trim`

At the time this document was created, the branch was clean before adding this handoff file.

Normal verification commands:

- `flutter analyze`
- `flutter test`
- `npm run test:sheet-notation`
- `npm run build:sheet-notation-app`

Recent verification has passed for the current MVP surface and notation/audio preview work.

Known recurring test output:

- PDF tests may print Helvetica Unicode warnings from `dart_pdf`; those warnings are known and not currently treated as failures.

---

## Product Direction

The active product is a lesson-plan MVP.

Primary goal:

- Make Coach useful as a structured, printable drum lesson path.

The app currently prioritizes:

- YAML-authored lesson content
- ordered lesson list
- readable lesson detail
- rendered sheet notation
- lightweight notation audio preview
- print/share handoff with rendered notation

The app should avoid:

- live practice sessions
- progress tracking
- assessment
- recommendation engines
- user notation authoring
- broad app navigation
- bottom tabs or app sections outside the lesson plan

Active contract docs:

- `docs/07_SCREEN_SPEC.md`
- `docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md`
- `docs/13_COMMUNICATION_STYLE_CONTRACT.md`
- `docs/15_MVP_TRIAGE_AND_PASS_ORDER.md`

Use those documents as source of truth before changing UI or flow behavior.

---

## Active Screens

### App Shell

File:

- `lib/features/app/app_shell.dart`

Current behavior:

- Shows a simple app header titled `Coach`.
- Body is `TodayScreen`, which currently owns the lesson plan list.
- Bottom navigation and broader app chrome are not active in the MVP.

### Lessons

File:

- `lib/features/today/today_screen.dart`

Current behavior:

- Loads `Flow Foundations` from the bundled YAML asset.
- Shows plan title and subtitle.
- Shows one compact ordered list of lessons.
- Each row shows lesson number, title, objective, estimated minutes, and primary pattern title/role.
- Tapping a row opens `Lesson Detail`.
- Load or validation errors are visible.

Important contract:

- Do not show raw notation strings in lesson list rows.
- Do not add practice/progress/session actions here.

### Lesson Detail

File:

- `lib/features/coach/lesson_detail_screen.dart`

Current behavior:

- Shows lesson title, objective, skill focus, estimated time, patterns, exercises, coaching notes, mastery target, and Print.
- Pattern rows render sheet notation through the shared `DrumSheetNotationDisplay`.
- Pattern rows have an ear-icon preview action.
- Raw notation strings are intentionally not shown to users.
- Print uses existing `LessonPrintExportService`.

Important contract:

- Sheet rendering failures should be visible.
- Raw Drumcabulary strings must not silently replace failed sheet rendering.
- Do not add live transport, BPM controls, completion state, or assessment copy.

---

## Lesson Content

Bundled lesson plan asset:

- `assets/lessons/flow_foundations.yaml`

Current plan:

1. `Groove Foundation`
2. `The Money Beat`
3. `Accents and Ghosts`
4. `Simultaneous Hits`
5. `Five-Note Groupings`
6. `Groove to Fill Flow`
7. `Triplet Feel`
8. `Subdivision Transitions`
9. `Triplet Vocabulary 1`

Lesson schema code:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`

Current schema concepts:

- `LessonPlan`
- `Lesson`
- `LessonPattern`
- `LessonExercise`
- `TempoTarget`
- `FlowStep`

Schema expectations:

- Required fields are validated.
- Lessons are ordered by `number`.
- Patterns can include `subdivision`, `time_signature`, and `repeat_count`.
- Pattern `subdivision: triplet` is timing/display feel, not a new notation token.
- Pattern `time_signature` defaults to `4/4` when omitted.
- Pattern `repeat_count` drives notation repeat bars and local preview repetition.
- Exercises can include subdivision, subdivision sequence, tempo, and flow.
- Flow steps reference lesson-local pattern ids.

Content direction:

- Add or revise MVP lesson content through YAML.
- Keep the path beginner-friendly and musically useful.
- Prefer lesson/exercise wording over app-internal terminology.
- Treat authored notation as the source for rendered examples, not as user-editable content.

---

## Notation And Audio Preview

Primary Flutter widget:

- `lib/features/practice/widgets/sheet_notation_display.dart`

Web renderer host:

- `web/sheet_notation/app_host.html`

Renderer implementation:

- `web/sheet_notation/renderer.js`
- `web/sheet_notation/app_renderer.js`

Current notation contract:

- Lesson YAML stores Drumcabulary notation strings.
- Users do not author notation strings in MVP.
- Existing explicit voice override notation may be used in YAML when examples need specific kit voices, such as hi-hat, snare, kick, or crash.
- Pattern metadata owns the rendering/playback feel: `subdivision`, `time_signature`, and `repeat_count`.
- Triplet examples use `subdivision: triplet` and render with standard triplet grouping marks.
- Time signatures render as actual time signatures; omitted values default to `4/4`.
- Repeated written patterns render with repeat bars and an `Nx` label.
- The shared sheet notation renderer is the display path on screen and in PDF/export.

Examples of current authored notation:

- `[RK] R [RL] R [RK] R [RL] R`
- `[XK]`
- `[HH K:R] [HH:R] [HH S:R] [HH:R]`
- `R(L)(L) RLK`

Audio preview:

- Uses the existing `PatternAudioService`.
- Triggered from an ear icon near rendered notation.
- Not a full practice player.
- No visible transport controls, BPM controls, session state, or tracking.

Current mixer defaults:

- kick: `1.0`
- normal non-cymbal: `0.8`
- normal cymbal: `0.8`
- ghost: `0.1`
- accent: `1.0`
- kick ignores ghost marking.

Current playback behavior:

- Preview prepares only samples required by the selected notation.
- Stale delayed cue callbacks are skipped to avoid catch-up bursts.
- Preview stops when the app becomes inactive, hidden, paused, or detached.
- Preview uses a fixed local BPM for now; exercise tempo is displayed as lesson guidance, not used as a live speed control.
- Eighth, sixteenth, and triplet-eighth patterns share the same written-bar cursor speed at the fixed preview BPM.
- Pattern `repeat_count` is honored by preview audio and playhead movement.
- Playhead continues through line/bar ends before wrapping or looping.

Remaining caveat:

- Audio preview smoothness should still be checked on device/simulator by ear. Timer-based one-shot sample playback is adequate for MVP preview, but it is not a production-grade sequencer.

---

## Print / Export

Files:

- `lib/features/coach/lesson_print_export_service.dart`
- `lib/features/coach/lesson_sheet_notation_svg_renderer.dart`

Current behavior:

- Lesson Detail has a Print action.
- Export requires rendered notation SVGs.
- Missing rendered notation should fail visibly instead of falling back to raw notation strings.

Known caveat:

- PDF font warnings about Helvetica Unicode support are known.

Decision still open:

- Whether MVP print output should optimize for one lesson per page, compact handouts, or full lesson notes.

---

## Deferred Scope

Keep these out of MVP refinement unless the product direction explicitly changes:

- Matrix
- Practice
- Library
- Progress
- Practice Item
- Session Summary
- Settings
- Startup Splash
- live practice sessions
- start/stop player beyond local notation preview
- full BPM timing engine
- progress tracking
- assessment evaluator
- user-specific recommendations
- editable user notation
- full curriculum editor or CMS

Some deferred code still exists in the repo. Do not remove it casually, and do not route users into it from the MVP surface.

---

## Current Test Anchors

Lesson plan tests:

- `test/lesson_plan_loader_test.dart`
- `test/lesson_print_export_service_test.dart`

Notation tests:

- `test/sheet_notation_display_test.dart`
- `test/sheet_notation/*.test.mjs`

Audio preview / playback planning tests:

- `test/pattern_audio_service_test.dart`

Recommended checks after MVP surface changes:

- `flutter analyze`
- `flutter test test/lesson_plan_loader_test.dart`
- `flutter test test/lesson_print_export_service_test.dart`
- `flutter test test/sheet_notation_display_test.dart`
- `flutter test test/pattern_audio_service_test.dart`
- `npm run test:sheet-notation`
- `flutter test`

---

## Good Next Work

Highest-value next refinement areas:

1. Lesson content pass
   - tighten lesson order, language, exercises, coaching notes, and mastery targets
   - decide whether `The Money Beat` should become lesson 1 or stay after `Groove Foundation`

2. Notation display quality pass
   - verify multi-bar wrapping, spacing, and playhead behavior on iPhone simulator
   - make sure rendered notation is clear enough for a printable handout

3. Audio sample quality pass
   - current samples are placeholders
   - cymbals and hi-hat especially need better licensed samples
   - update `assets/audio/PROVENANCE.md` when replacing samples

4. Print layout pass
   - decide lesson page density
   - verify long lessons such as `Triplet Vocabulary 1`
   - keep rendered notation, not raw strings

5. Product naming decision
   - app header currently says `Coach`
   - active surface functionally behaves as `Lessons`
   - decide whether user-facing naming should be `Coach`, `Lessons`, or `Flow Foundations`

---

## Copyable Prompt For A New Chat

Use this prompt to continue in another chat:

```text
We are working in /Users/terryknoblock/Development/flutter-projects/drumcabulary on branch feature/lesson-mvp-trim.

Please read docs/17_MVP_RESET_HANDOFF.md first, then the active contracts docs/07_SCREEN_SPEC.md and docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md.

Current direction: Drumcabulary is being reset to a narrow Coach lesson-plan MVP. It is content-first and print-first. Active screens are Lessons and Lesson Detail. The app loads assets/lessons/flow_foundations.yaml, shows ordered lessons, renders lesson detail, renders sheet notation through the shared renderer, supports a lightweight ear-icon audio preview with playhead, and prints/export lessons with rendered notation.

Do not restore live practice sessions, progress tracking, assessment, recommendations, Matrix, Library, Settings, editable notation, or broad app navigation unless explicitly asked. Keep changes contract-driven: update the active docs first if behavior or scope changes, then implement, then verify.

Key files:
- assets/lessons/flow_foundations.yaml
- lib/features/app/app_shell.dart
- lib/features/today/today_screen.dart
- lib/features/coach/lesson_detail_screen.dart
- lib/features/coach/lesson_plan.dart
- lib/features/coach/lesson_print_export_service.dart
- lib/features/practice/widgets/sheet_notation_display.dart
- lib/features/practice/pattern_audio_service.dart
- web/sheet_notation/app_host.html

Current lesson plan has 9 lessons: Groove Foundation, The Money Beat, Accents and Ghosts, Simultaneous Hits, Five-Note Groupings, Groove to Fill Flow, Triplet Feel, Subdivision Transitions, Triplet Vocabulary 1.

Before changing UI or flow, classify the work against the active MVP contract. Prefer YAML content changes for lesson content. Do not show raw notation strings to users where rendered notation is expected. Renderer failures should be visible. Audio preview is local to notation examples only; no practice transport or session state.

When done, run the relevant focused tests and usually flutter analyze. For notation work also run npm run test:sheet-notation.
```
