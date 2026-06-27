# 17 - MVP Reset Handoff

## Purpose

Use this document to brief a new chat or contributor on the current Drumcabulary MVP reset.

The reset is intentionally narrow: Coach is now a simple drum teaching surface.
The app should help a user choose a level, choose a skill, open a lesson, work
through progressive exercises, hear the notation, and print the lesson. It
should not restore the broader practice/session/product systems during MVP
refinement.

Current date of this handoff: 2026-06-26.

---

## Current Branch And State

Current working branch:

- `feature/level-skill-lesson-architecture`

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

The active product is a Level -> Skill -> Lesson teaching MVP.

Primary goal:

- Make Coach useful as a structured, printable drum lesson flow.

The app currently prioritizes:

- YAML-authored lesson content
- level and skill selection
- progressive exercise cards
- readable lesson detail
- rendered sheet notation
- lightweight notation audio preview
- print/share handoff with rendered notation

The app should avoid:

- live practice sessions
- detailed progress analytics
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
- `docs/18_NOTATION_LANGUAGE_CONTRACT.md`
- `docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md`
- `docs/20_LESSON_YAML_DATA_ARCHITECTURE.md`

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

### Levels And Skills

File:

- `lib/features/today/today_screen.dart`

Current behavior:

- Loads `assets/content/index.yaml` and all listed lesson YAML files.
- Shows Beginner, Intermediate, and Advanced level rows.
- Shows practiced time and a simple level completion indicator when available.
- Tapping a level shows skills derived from lessons in that level.
- Tapping a skill opens the only lesson directly or shows ordered lesson rows.
- Load or validation errors are visible.

Important contract:

- Do not show raw notation strings in list rows.
- Do not add authored paths, recommendations, assessment, or full practice
  session actions here.

### Lesson Detail

File:

- `lib/features/coach/lesson_detail_screen.dart`

Current behavior:

- Shows lesson title, level, skill, overview, objective, estimated time,
  progressive exercise cards, and Print.
- Exercise cards show Why, What, How, notation, Hear It, Practice It, and
  Complete Exercise.
- Exercise notation renders sheet notation through the shared
  `DrumSheetNotationDisplay`.
- Rendered notation has an ear-icon preview action.
- Raw notation strings are intentionally not shown to users.
- Print uses existing `LessonPrintExportService`.

Important contract:

- Sheet rendering failures should be visible.
- Raw Drumcabulary strings must not silently replace failed sheet rendering.
- Do not add live transport, BPM controls, scoring, recommendation, or
  assessment copy.

---

## Lesson Content

Bundled content index:

- `assets/content/index.yaml`

Current starter lessons:

- `assets/content/lessons/beginner/grooves/money-beat.yaml`
- `assets/content/lessons/intermediate/vocabulary/triplet-vocabulary-1.yaml`
- `assets/content/lessons/intermediate/grooves/money-beat-triplet-fills.yaml`

Lesson schema code:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`

Current schema concepts:

- `ContentIndex`
- `ContentLevel`
- `LessonContentLibrary`
- `Lesson`
- `LessonExercise`
- `ExerciseNotation`
- `ExerciseNotationSection`
- `TempoTarget`
- local `UserProgress`, `LessonProgress`, and `ExerciseProgress`

Schema expectations:

- Required fields are validated.
- Lessons are ordered by `lesson.order` inside level/skill.
- Each exercise owns one notation block.
- Notation can be single-section or sectioned.
- Sections can include `subdivision`, `time_signature`, `repeat_count`, and
  optional `sticking`.
- `subdivision: triplet` is timing/display feel, not a new notation token.
- `time_signature` defaults to `4/4` when omitted.
- `repeat_count` drives notation repeat bars and local preview repetition.
- Sticking renders only when authored.
- Notation grammar, token meaning, voice labels, duration labels, grouping
  behavior, triplet behavior, and render-document rules are owned by
  `docs/18_NOTATION_LANGUAGE_CONTRACT.md`.

Content direction:

- Add or revise MVP lesson content through YAML.
- Keep the path beginner-friendly and musically useful.
- Prefer lesson/exercise wording over app-internal terminology.
- Treat authored notation as the source for rendered examples, not as user-editable content.

---

## Notation And Audio Preview

Current notation contract:

- `docs/18_NOTATION_LANGUAGE_CONTRACT.md` is the single source of truth for
  grammar, token meaning, metadata, voice labels, duration labels, grouping,
  triplet behavior, render-document rules, and valid/invalid examples.
- `docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md` is the single source of truth
  for the current YAML-to-screen/PDF/audio rendering pipeline.

---

## Print / Export

Current behavior:

- Lesson Detail has a Print action.
- Export behavior and rendering failure policy are defined in
  `docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md`.

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
We are working in /Users/terryknoblock/Development/flutter-projects/drumcabulary on branch feature/level-skill-lesson-architecture.

Please read docs/17_MVP_RESET_HANDOFF.md first, then the active contracts docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md, docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md, and docs/20_LESSON_YAML_DATA_ARCHITECTURE.md.

Current direction: Drumcabulary is being reset to a narrow Level -> Skill -> Lesson teaching MVP. The app loads assets/content/index.yaml, then the lesson files listed under each level. Active screens are level list, skill list, optional lesson list, and lesson detail. Lesson detail shows progressive exercise cards with Why, What, How, rendered notation, Hear It, Practice It, Complete Exercise, and Print.

Do not restore authored paths, live practice sessions, assessments, scoring, recommendations, Matrix, Library, Settings, editable notation, or broad app navigation unless explicitly asked. Keep changes contract-driven: update the active docs first if behavior or scope changes, then implement, then verify.

Key files:
- assets/content/index.yaml
- assets/content/lessons/beginner/grooves/money-beat.yaml
- assets/content/lessons/intermediate/vocabulary/triplet-vocabulary-1.yaml
- assets/content/lessons/intermediate/grooves/money-beat-triplet-fills.yaml
- lib/features/today/today_screen.dart
- lib/features/coach/lesson_detail_screen.dart
- lib/features/coach/lesson_plan.dart
- lib/features/coach/lesson_plan_loader.dart
- lib/features/coach/lesson_progress.dart
- lib/features/coach/lesson_notation_document.dart
- lib/features/coach/lesson_print_export_service.dart
- lib/features/practice/widgets/sheet_notation_display.dart
- lib/features/practice/pattern_audio_service.dart
- web/sheet_notation/app_host.html

Current starter content has Beginner / Grooves / The Money Beat, Intermediate / Vocabulary / Triplet Vocabulary 1, and Intermediate / Grooves / Money Beat + Triplet Fills.

Before changing UI or flow, classify the work against the active MVP contract. Prefer YAML content changes for lesson content. Do not show patterns as the main student-facing concept. Do not show raw notation strings to users where rendered notation is expected. Renderer failures should be visible. Audio preview is local to notation examples only; no full practice transport or scoring.

When done, run the relevant focused tests and usually flutter analyze. For notation work also run npm run test:sheet-notation.
```
