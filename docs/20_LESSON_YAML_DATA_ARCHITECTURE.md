# 20 - Lesson YAML Data Architecture

## Purpose

This document is the source of truth for MVP lesson content, authored YAML
structure, local progress data, and loader validation.

The active teaching architecture is:

```text
Level -> Skill -> Lesson -> Progressive Exercises
```

This document does not redefine Drumcabulary notation grammar. Notation grammar
is owned by:

- `docs/18_NOTATION_LANGUAGE_CONTRACT.md`

This document does not redefine rendering internals. Rendering is owned by:

- `docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md`

If another document describes Coach lesson YAML differently, treat this document
as authoritative and update the competing document.

## Product Boundary

The app is currently a simple drum teaching MVP. It should feel like a lesson
flow, not a content management browser.

Supported now:

- a bundled content index
- three high-level levels: beginner, intermediate, advanced
- skills derived from lessons within each level
- one lesson per YAML file
- progressive exercises inside each lesson
- exercise-owned notation blocks
- sectioned exercise notation when one exercise needs multiple timing contexts
- optional authored sticking labels
- existing notation preview audio and playhead
- print/export of lesson detail content
- simple local progress and practiced time

Not supported now:

- paths or authored curriculum graph files
- separate skills taxonomy files
- assessments or scoring
- AI coaching
- recommendations
- remote content loading
- user-authored lesson editing
- complex filtering
- progress fields inside YAML

Content YAML defines what exists. Local progress records what the user has done.

## Source Files

Primary content assets:

```text
assets/content/index.yaml
assets/content/lessons/<level>/<skill>/<lesson>.yaml
```

Current starter content:

```text
assets/content/
  index.yaml
  lessons/
    beginner/
      grooves/
        money-beat.yaml
    intermediate/
      grooves/
        money-beat-triplet-fills.yaml
      vocabulary/
        triplet-vocabulary-1.yaml
```

Asset registration:

- `pubspec.yaml`

Dart model, loader, and progress files:

- `lib/features/coach/lesson_plan.dart`
- `lib/features/coach/lesson_plan_loader.dart`
- `lib/features/coach/lesson_notation_document.dart`
- `lib/features/coach/lesson_progress.dart`

Primary UI/export consumers:

- `lib/features/today/today_screen.dart`
- `lib/features/coach/lesson_detail_screen.dart`
- `lib/features/coach/lesson_print_export_service.dart`
- `lib/features/coach/lesson_sheet_notation_svg_renderer.dart`
- `lib/features/practice/widgets/sheet_notation_display.dart`
- `lib/features/practice/pattern_audio_service.dart`

Primary tests:

- `test/lesson_plan_loader_test.dart`
- `test/lesson_progress_test.dart`
- `test/lesson_print_export_service_test.dart`
- `test/sheet_notation_display_test.dart`
- `test/pattern_audio_service_test.dart`

Migration note:

- The old single-file `assets/lessons/flow_foundations.yaml` asset is no
  longer the active lesson source.
- The discarded catalog/path-heavy architecture is not active. Do not re-add
  `catalog.yaml`, `skills.yaml`, or `paths/*.yaml` for this MVP direction.

## Adding Content

Adding a lesson should not require Dart code changes.

1. Create a lesson YAML file under `assets/content/lessons/<level>/<skill>/`.
2. Add the file path to the correct level in `assets/content/index.yaml`.
3. Keep the lesson `level` equal to the parent level in the index.
4. Keep the lesson `skill` non-empty.
5. Keep each exercise notation pattern valid under the existing notation
   grammar.

## Data Flow

```text
assets/content/index.yaml
  -> ContentIndex
  -> listed lesson YAML files
  -> LessonContentLibrary
  -> level list
  -> skill list for selected level
  -> ordered lessons for selected skill
  -> lesson detail
  -> exercise notation display, audio preview, print/export
```

`LessonContentLibrary` is the resolved runtime content set:

```text
LessonContentLibrary
  index: ContentIndex
  lessonsById: Map<String, Lesson>
  lessonsByLevelId: Map<String, List<Lesson>>
```

Lessons are ordered by `lesson.order` within a level/skill.

## Index YAML

`assets/content/index.yaml` binds levels to authored lesson files.

```yaml
content_index:
  version: 1
  levels:
    - id: beginner
      title: Beginner
      lesson_files:
        - lessons/beginner/grooves/money-beat.yaml

    - id: intermediate
      title: Intermediate
      lesson_files:
        - lessons/intermediate/vocabulary/triplet-vocabulary-1.yaml
        - lessons/intermediate/grooves/money-beat-triplet-fills.yaml

    - id: advanced
      title: Advanced
      lesson_files: []
```

Fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `content_index.version` | `ContentIndex.version` | yes | integer | Schema/content version. |
| `content_index.levels` | `ContentIndex.levels` | yes | list | Must not be empty. |
| `levels[].id` | `ContentLevel.id` | yes | string | Stable level ID. |
| `levels[].title` | `ContentLevel.title` | yes | string | Student-facing display title. |
| `levels[].lesson_files` | `ContentLevel.lessonFiles` | no | string list | Relative to `assets/content`. Empty is allowed. |

Authoring rules:

- Level IDs must be unique.
- Lesson files are loaded in the level where they are listed.
- A lesson's own `level` field must match the parent level in the index.

## Lesson YAML

Each lesson file has one `lesson` root.

```yaml
lesson:
  id: money-beat
  title: The Money Beat
  level: beginner
  skill: grooves
  order: 1
  estimated_minutes: 25
  overview: Learn the foundational 4/4 rock groove by adding one limb at a time.
  objective: Build the money beat gradually from hi-hat only to full groove.

  exercises:
    - id: hh-only
      title: Hi-Hat Only
      why: The hi-hat is the timekeeper. Get it steady before adding anything else.
      what: Play steady eighth notes on closed hi-hat.
      how: Count 1 and 2 and 3 and 4 and while keeping the notes even.
      tempo:
        start: 60
        target: 90
      notation:
        subdivision: 8
        time_signature: "4/4"
        repeat_count: 4
        pattern: "[HH:R][HH:R] [HH:R][HH:R] [HH:R][HH:R] [HH:R][HH:R]"
```

Fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `lesson.id` | `Lesson.id` | yes | string | Globally unique lesson ID. |
| `lesson.title` | `Lesson.title` | yes | string | Student-facing title. |
| `lesson.level` | `Lesson.level` | yes | string | Must match parent index level. |
| `lesson.skill` | `Lesson.skill` | yes | string | Skill bucket such as `grooves`, `timing`, or `vocabulary`. |
| `lesson.order` | `Lesson.order` | yes | positive integer | Ordering within level/skill. |
| `lesson.estimated_minutes` | `Lesson.estimatedMinutes` | yes | positive integer | Guidance only. |
| `lesson.overview` | `Lesson.overview` | yes | string | High-level lesson context. |
| `lesson.objective` | `Lesson.objective` | yes | string | What the lesson builds. |
| `lesson.exercises` | `Lesson.exercises` | yes | list | Progressive student-facing exercises. |

Do not present patterns as the primary student-facing concept. Patterns are
implementation details inside exercise notation.

## Exercise YAML

Exercises are the main authored teaching unit inside a lesson.

```yaml
- id: hh-snare-kick
  title: Add Kick
  why: The kick completes the basic money beat.
  what: Add kick on beats 1 and 3 while keeping snare on 2 and 4.
  how: Listen for an even hi-hat line over solid kick and snare placement.
  tempo:
    start: 60
    target: 100
  notation:
    subdivision: 8
    time_signature: "4/4"
    repeat_count: 4
    pattern: "[HH K:R][HH:R] [HH S:R][HH:R] [HH K:R][HH:R] [HH S:R][HH:R]"
```

Fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `id` | `LessonExercise.id` | no | string | If omitted, generated from title. Must be unique within lesson. |
| `title` | `LessonExercise.title` | yes | string | Student-facing exercise title. |
| `why` | `LessonExercise.why` | yes | string | Why the exercise matters. |
| `what` | `LessonExercise.what` | yes | string | What the student plays. |
| `how` | `LessonExercise.how` | yes | string | How to approach it. |
| `success` | `LessonExercise.success` | no | string | Optional success target displayed when authored. |
| `tempo.start` | `TempoTarget.start` | no | positive integer | Practice guidance. |
| `tempo.target` | `TempoTarget.target` | no | positive integer | Must be `>= start`. |
| `notation` | `ExerciseNotation` | yes | map | Single notation block or sectioned notation. |

Exercises should build gradually. A beginner groove lesson should add one limb
or one concept at a time before combining them.

## Exercise Notation

Each exercise owns its notation block.

Single-section form:

```yaml
notation:
  subdivision: 8
  time_signature: "4/4"
  repeat_count: 4
  sticking: "R R R R R R R R"
  pattern: "[HH:R][HH:R] [HH:R][HH:R] [HH:R][HH:R] [HH:R][HH:R]"
```

Sectioned form:

```yaml
notation:
  sections:
    - title: Money Beat
      subdivision: 8
      time_signature: "4/4"
      repeat_count: 3
      pattern: "[HH K:R][HH:R] [HH S:R][HH:R] [HH K:R][HH:R] [HH S:R][HH:R]"
    - title: Triplet Fill
      subdivision: triplet
      time_signature: "4/4"
      repeat_count: 1
      sticking: "R L K R L K R L K R L K"
      pattern: "RLK RKL R(L)(L) [XK]"
```

Section fields:

| YAML field | Dart field | Required | Type | Notes |
| --- | --- | --- | --- | --- |
| `title` | `ExerciseNotationSection.title` | no | string | Optional section label. |
| `pattern` | `ExerciseNotationSection.pattern` | yes | string | Drumcabulary pattern text. |
| `subdivision` | `ExerciseNotationSection.subdivision` | no | scalar | `8`, `16`, `triplet`, `16_triplet`, etc. |
| `time_signature` | `ExerciseNotationSection.timeSignature` | no | scalar | Defaults to `4/4`. |
| `repeat_count` | `ExerciseNotationSection.repeatCount` | no | positive integer | Written repeat metadata. |
| `sticking` | `ExerciseNotationSection.sticking` | no | scalar | Optional authored sticking labels. |

Rules:

- Sections are YAML/model concepts, not notation syntax.
- Do not encode sections inside the notation language.
- If `sticking` exists, render it.
- If `sticking` does not exist, do not invent or render sticking.
- Do not add `show_sticking` or `hide_sticking`.
- Triplets remain metadata via `subdivision: triplet` or `subdivision: 16_triplet`.
- Do not infer triplets from grouping spaces.
- Grouping spaces are phrasing aids only.

## Progress Model

Progress is local user state and is never stored in YAML.

Statuses:

```text
not_started
in_progress
completed
```

Tracked objects:

- `UserProgress`
- `LevelProgressSummary`
- `LessonProgress`
- `ExerciseProgress`

Tracked fields include:

- lesson status
- exercise status
- started/opened/practiced/completed timestamps
- practiced seconds per lesson
- practiced seconds per exercise
- practiced seconds per level

Rules:

- Opening a lesson marks the lesson `in_progress`.
- Starting Practice It marks the exercise `in_progress`.
- Completing an exercise marks that exercise `completed`.
- Completing all exercises in a lesson marks the lesson `completed`.
- Level status is derived from lesson progress.
- Level completion indicator is shown when all or most lessons are complete.
- Practice It starts a simple timer; it is not scoring or assessment.

Current persistence:

- `FileLessonProgressStore`
- local JSON file named `lesson_progress_v2.json`
- app documents directory via `path_provider`

Tests may use:

- `MemoryLessonProgressStore`

## Loader Validation

The loader should reject obvious authoring mistakes and provide useful errors.

Validation includes:

- `content_index` root shape
- non-empty level list
- unique level IDs
- listed lesson assets load successfully
- unique lesson IDs
- lesson level matches parent index level
- lesson skill is present
- positive lesson `order`
- positive `estimated_minutes`
- unique exercise IDs within each lesson
- positive tempo values
- tempo target `>=` tempo start
- positive `repeat_count`
- single-section notation pattern strings parse
- sectioned notation pattern strings parse

Unknown YAML keys are not rejected unless the loader style changes broadly.

## UI Contract

The content model supports this MVP screen flow:

```text
Choose Level -> Choose Skill -> Choose Lesson -> Lesson Detail
```

If a selected skill has one lesson, the UI may open that lesson directly.
If it has multiple lessons, show an ordered lesson list.

Lesson Detail should show:

- title
- overview
- objective
- estimated minutes
- progressive exercise cards
- each exercise's Why, What, and How
- rendered notation
- Hear It
- Practice It / Complete Exercise
- Print

Lesson Detail should not show a separate pattern browser.

## Migration Notes

Old single-file plan:

```text
assets/lessons/flow_foundations.yaml
  -> lesson_plan.lessons[]
```

Discarded path-heavy direction:

```text
assets/content/catalog.yaml
assets/content/skills.yaml
assets/content/paths/*.yaml
assets/content/lessons/*.yaml
```

Active MVP direction:

```text
assets/content/index.yaml
assets/content/lessons/<level>/<skill>/<lesson>.yaml
```

Important migration changes:

- lesson order now lives on `lesson.order`
- skill is a simple lesson field
- patterns are no longer top-level student-facing content
- exercise notation owns the pattern text
- sectioned notation belongs to an exercise
- progress moved to local state only

## Intentional Limitations

- No remote content.
- No authored paths.
- No separate skill taxonomy.
- No scoring or assessment.
- No recommendations.
- No AI coach.
- No user notation editing in Coach.
- No BPM adjustment controls yet.
- No complex progress analytics.
