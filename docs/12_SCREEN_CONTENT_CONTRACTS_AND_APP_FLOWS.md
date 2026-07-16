# 12 - Screen Content Contracts And App Flows

## Purpose

This document defines the active screen/content/flow contract for the MVP
teaching flow.

If a control or block cannot be justified by a defined MVP flow in this
document, it should not be reachable in the active teaching UI.

Communication rules for student-facing text are defined in:

- [13_COMMUNICATION_STYLE_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/13_COMMUNICATION_STYLE_CONTRACT.md)

The lesson YAML/data contract is defined in:

- [20_LESSON_YAML_DATA_ARCHITECTURE.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/20_LESSON_YAML_DATA_ARCHITECTURE.md)

## Current MVP Rule

The current product is a simple drum teaching MVP.

Active teaching flow:

```text
Choose Level -> Choose Skill -> Lesson Detail -> Progressive Exercises
```

Active app-owned screens:

1. Level list
2. Skill list for selected level
3. Lesson list when a skill has multiple lessons
4. Lesson Detail

Deferred screens and systems:

- Matrix
- full Practice system
- Library
- detailed Progress
- Practice Item editor
- Session Summary
- Settings
- Startup Splash
- live practice sessions
- assessment
- detailed progress analytics
- recommendations
- user notation authoring

## Core Rule

Every active screen needs:

1. a clear job
2. a small set of valid states
3. a small set of valid actions
4. evidence that supports those actions

No active screen should contain:

- filler cards
- internal implementation copy
- controls that belong to deferred practice/product systems
- duplicate lesson metadata with no new value
- raw notation strings where rendered sheet notation is expected
- patterns as the primary student-facing concept

Developer and hardware diagnostic access:

- MIDI Input Diagnostic is a developer-facing hardware tool, not a student
  teaching flow.
- Every navigable app screen must keep MIDI Input Diagnostic reachable through a
  consistent toolbar/header action, except the diagnostic screen itself.

## Notation Rules

- lesson YAML stores authored Drumcabulary notation strings inside exercise notation
- users do not author or edit notation strings in MVP
- lesson content may use explicit voice override notation when an example depends on specific kit voices
- notation metadata may include `subdivision`, `time_signature`, and `repeat_count`
- omitted time signatures default to `4/4`
- `subdivision: triplet` is timing/display metadata and should render standard triplet grouping marks without creating new Drumcabulary text tokens
- repeated written notation should render with an end-repeat bar when `repeat_count` is authored; do not add a separate repeat-count text label in MVP
- the shared sheet-notation renderer is the display path for lesson notation examples
- sticking/limb labels render only when authored
- rendered notation may expose an ear-icon preview that plays the displayed notes through the existing sample engine
- while notation preview is playing, the notation surface should highlight the active rhythmic event with the shared rounded selection treatment aligned to rendered note positions
- lesson detail exposes a persistent footer BPM control for notation preview speed; authored exercise tempo remains guidance
- notation preview timing should preserve written bar speed across eighth, sixteenth, and triplet-eighth subdivisions
- notation preview playback and active-event highlighting should honor `repeat_count`
- notation preview audio should use the explicit mixer config for relative sample levels
- notation preview audio must stop on app inactive, hidden, paused, or detached lifecycle states instead of catching up missed notes on return
- renderer failures must be visible
- raw notation strings must not silently replace failed sheet rendering in app or PDF output
- PDF/export output should use the same notation rendering contract as on-screen lesson detail

## Flow A: Choose Level

1. User opens the app.
2. App opens directly to the level list.
3. The screen loads `assets/content/index.yaml` and all listed lesson files.
4. If the content validates, the level rows appear.
5. If content fails to load or validate, a visible error appears.

Owning screen:

- Level list

Required content:

- Beginner
- Intermediate
- Advanced
- practiced time per level
- completion indicator when most/all lessons in the level are complete

Allowed actions:

- tap a level

Forbidden content:

- bottom tabs
- authored path rows
- Matrix handoff
- full Practice handoff
- assessment state
- personalized recommendations

## Flow B: Choose Skill

1. User taps a level.
2. Skill list opens for that level.
3. Skills are derived from lessons listed under that level.
4. Only skills with at least one lesson are shown.
5. User taps a skill.

Owning screen:

- Skill list

Required content:

- selected level title
- skill title
- simple lesson/progress summary if available

Allowed actions:

- back to level list
- tap a skill

Forbidden content:

- empty skills
- complex filters
- recommendations
- skill taxonomy editor

## Flow C: Choose Lesson

1. User taps a skill.
2. If the skill has one lesson, the app may open the lesson directly.
3. If the skill has multiple lessons, show ordered lesson rows.
4. Lesson order comes from `lesson.order`.

Owning screen:

- Lesson list for selected skill

Required content:

- lesson title
- overview or objective
- estimated minutes
- local status if available

Allowed actions:

- back to skill list
- tap a lesson

Forbidden content:

- hard-coded lesson order
- authored paths
- pattern rows
- assessment or score state

## Flow D: Read And Practice Lesson

1. User opens a lesson.
2. Opening a not-started lesson marks it `in_progress` locally.
3. Lesson overview/objective renders.
4. Progressive exercise cards render in authored order.
5. Each exercise explains Why, What, and How.
6. User can adjust lesson preview BPM from the footer.
7. User can hear notation, start Practice It, start Guided Practice when
   hardware is connected, complete an exercise, print, or go back.
8. During Guided Practice, the rendered notation highlights the current expected
   note or simultaneous note group.
9. Guided Practice loops the exercise sequence continuously and remains active
   until the user stops it or hardware disconnects.

Owning screen:

- Lesson Detail

Required content:

- lesson title
- level and skill
- overview
- objective
- estimated minutes
- progressive exercise cards
- each exercise's Why, What, and How
- rendered notation
- Hear It action
- footer BPM control for Hear It preview speed
- Practice It action/timer entry point
- Guided Practice action when MIDI input and LED output are connected
- current expected notation highlight during Guided Practice
- Stop Guided Practice action while Guided Practice is running
- Complete Exercise action
- Print action

Forbidden content:

- top-level pattern list as the main student concept
- full practice transport controls
- assessment prompts
- scoring
- editable notation fields
- detailed progress analytics
- recommendation copy

## Flow E: Print Lesson

1. User opens Lesson Detail.
2. User taps Print.
3. App uses the existing print/share export infrastructure.
4. Exported content includes rendered notation for the lesson exercises.
5. If notation rendering fails, the failure is visible during development.

Owning screens:

- Lesson Detail
- platform print/share handoff

Required content:

- lesson identity
- overview/objective
- progressive exercises
- Why, What, and How
- rendered notation examples
- tempo guidance when authored

Forbidden content:

- raw notation fallback in place of failed rendering
- practice-session data
- scoring data
- recommendation copy

## Level List Contract

Level list answers:

- what level should I start from?
- how much have I practiced in each level?
- is this level mostly/all complete?

Level list must show:

- level title
- practiced time
- completion summary
- clear load errors

Level list must not show:

- path rows
- advanced content filtering
- settings controls
- detailed analytics

## Skill List Contract

Skill list answers:

- what skill areas are available in this level?
- where should I go next inside the selected level?

Skill list must show:

- selected level title
- skills that have lessons
- lesson counts or simple progress when available

Skill list must not show:

- empty skills
- global skill taxonomy editing
- recommendations
- notation examples

## Lesson Detail Contract

Lesson Detail answers:

- what does this lesson teach?
- how do the exercises build gradually?
- what should I listen to, practice, complete, or print?

Lesson Detail must show:

- title
- overview
- objective
- estimated time
- exercise cards in order
- Why, What, and How for each exercise
- rendered notation for each exercise
- ear-icon preview controls for rendered notation
- persistent footer BPM control for rendered notation preview speed
- active-event notation highlight during preview using the shared rounded selection treatment
- current expected note/group highlight over rendered notation during Guided Practice
- Practice It / Complete Exercise controls
- Guided Practice / Stop Guided Practice controls when supported
- print action

Lesson Detail must not show:

- a separate pattern browser
- player transport
- full practice session controls
- detailed progress analytics
- assessment language
- fallback raw notation when sheet rendering fails
