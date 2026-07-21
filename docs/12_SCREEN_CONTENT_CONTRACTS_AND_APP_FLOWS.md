# 12 - Screen Content Contracts And App Flows

## Purpose

This document defines screen content guardrails and retains older MVP flow notes
for historical context.

Current navigation and app-flow ownership live in
`docs/28_APP_FLOW_CONTRACT.md`. If the flow sections in this document conflict
with `docs/28_APP_FLOW_CONTRACT.md`, use `docs/28_APP_FLOW_CONTRACT.md`.

For current app-wide navigation ownership, including Settings, Hardware & MIDI,
temporary MIDI Capture placement, Pattern Editor direction, and developer
diagnostics, use:

- [28_APP_FLOW_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/28_APP_FLOW_CONTRACT.md)

If a control or block cannot be justified by the current flow contract in
`docs/28_APP_FLOW_CONTRACT.md`, it should not be reachable in the active
student UI.

Communication rules for student-facing text are defined in:

- [13_COMMUNICATION_STYLE_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/13_COMMUNICATION_STYLE_CONTRACT.md)

The lesson YAML/data contract is defined in:

- [20_LESSON_YAML_DATA_ARCHITECTURE.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/20_LESSON_YAML_DATA_ARCHITECTURE.md)

Lesson and exercise metadata semantics are defined in:

- [29_LESSON_METADATA_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/29_LESSON_METADATA_CONTRACT.md)

## Current Product Rule

The current product is a simple drum teaching and practice app.

Active teaching flow:

```text
Home -> Explore -> Lesson Detail -> Progressive Exercises
```

Active app-owned screens:

1. Home
2. Explore
3. Lesson Detail
4. Practice Insights
5. Author
6. Settings

Flow-level ownership for these screens is defined in
`docs/28_APP_FLOW_CONTRACT.md`.

Deprecated or developer-only normal-navigation surfaces:

- Matrix
- full standalone Practice system
- Practice Item editor
- Session Summary
- Startup Splash
- assessment
- detailed progress analytics
- recommendations
- raw MIDI diagnostics

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

Metadata rules:

- Content Metadata, System Metadata, and User Metadata must not be mixed.
- Explore and search consume effective lesson/exercise metadata.
- Lesson Detail should show only metadata that helps the current exercise or
  lesson task; it should not dump every metadata category.
- User progress state such as Status, Favorite, Best BPM, and Last Practiced
  must never be stored as content metadata.

Developer and hardware diagnostic access:

- MIDI Input Diagnostic is a developer-facing hardware tool, not a student
  teaching flow.
- Developer diagnostics may be reachable through a developer/debug route, but
  raw MIDI diagnostics must not appear as normal student cards.

## Notation Rules

- lesson YAML stores authored Drumcabulary notation strings inside exercise notation
- Lesson Detail does not expose editable notation strings. Authoring surfaces
  may expose source notation where explicitly defined by the app-flow contract.
- lesson content may use explicit voice override notation when an example depends on specific kit voices
- notation metadata may include `subdivision`, `time_signature`, and `repeat_count`
- omitted time signatures default to `4/4`
- `subdivision: triplet` is timing/display metadata and should render standard triplet grouping marks without creating new Drumcabulary text tokens
- repeated written notation should render with an end-repeat bar when `repeat_count` is authored; do not add a separate repeat-count text label in MVP
- the shared sheet-notation renderer is the display path for lesson notation examples
- sticking/limb labels render only when authored
- rendered notation may expose an ear-icon preview in standalone contexts, but
  Lesson Detail suppresses that local control because its footer owns Hear It
- while notation preview is playing, the notation surface should highlight the active rhythmic event with the shared rounded selection treatment aligned to rendered note positions
- lesson detail exposes BPM controls in the fixed practice footer; authored
  exercise tempo remains guidance
- notation preview timing should preserve written bar speed across eighth, sixteenth, and triplet-eighth subdivisions
- notation preview playback and active-event highlighting should honor `repeat_count`
- notation preview audio should use the explicit mixer config for relative sample levels
- notation preview audio must stop on app inactive, hidden, paused, or detached lifecycle states instead of catching up missed notes on return
- renderer failures must be visible
- raw notation strings must not silently replace failed sheet rendering in app or PDF output
- PDF/export output should use the same notation rendering contract as on-screen lesson detail

## Historical Flow A: Choose Level

The following Level/Skill flow sections are retained as historical MVP context.
Current discovery is metadata-driven Explore, defined in
`docs/28_APP_FLOW_CONTRACT.md` and `docs/29_LESSON_METADATA_CONTRACT.md`.

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

## Historical Flow B: Choose Skill

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

## Historical Flow C: Choose Lesson

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
4. A compact exercise navigator renders all exercises in authored order.
5. One active exercise card renders Goal, Focus, and Tip.
6. User can adjust lesson preview BPM from the fixed practice footer.
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
- useful metadata chips where they help the current lesson task
- overview
- objective
- MIDI and LED hardware status chips where supported
- compact exercise navigator
- one active exercise card
- Goal, Focus, and Tip for the active exercise
- wrapped rendered notation for the active exercise
- fixed footer with BPM controls and Practice It, Guided Practice, Hear It, and
  Play Along actions
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
- Goal, Focus, and Tip content derived from the exercise teaching fields
- rendered notation examples
- tempo guidance when authored

Forbidden content:

- raw notation fallback in place of failed rendering
- practice-session data
- scoring data
- recommendation copy

## Historical Level List Contract

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

## Historical Skill List Contract

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
- MIDI and LED status chips where supported
- exercise navigator in authored order
- one active exercise card
- Goal, Focus, and Tip for the active exercise
- wrapped rendered notation for the active exercise
- fixed footer with the four practice-mode actions and BPM control for rendered
  notation preview speed
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
