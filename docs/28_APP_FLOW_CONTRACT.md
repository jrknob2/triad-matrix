# 28 - App Flow Contract

## Purpose

This is the active navigation and app-flow contract for UI improvement work.

Use this document when deciding:

- where a screen belongs
- which actions should be globally reachable
- whether a feature is part of the normal student flow, hardware setup, authoring, or developer diagnostics
- which older screens are active, deferred, or orphaned

This document is intentionally narrower than the visual style guides. It should
be included in chat context whenever the work is about app flow, screen
ownership, information architecture, or navigation.

## Related Docs

Read these as supporting context:

- `docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md`
- `docs/07_SCREEN_SPEC.md`
- `docs/06_APP_SPEC.md`
- `docs/25_DRUMMER_EDGE_UI_STYLE_GUIDE.md`
- `docs/26_ART_DIRECTION_GUIDE.md`
- `docs/29_LESSON_METADATA_CONTRACT.md`
- `docs/30_HOME_SCREEN_UX_CONTRACT.md`

Current warning: some older docs still describe Settings, Library, Practice,
Matrix, and Progress as deferred MVP systems. That is historically useful, but
not sufficient for current UI work because hardware setup, Guided Practice,
LEDs, and MIDI capture now exist in the working app. This document is the
flow-level tie-breaker until the older product docs are reconciled.

## Product Flow Principle

Drumcabulary should feel like:

```text
Choose what to learn -> understand it -> hear it -> practice it -> configure hardware only when needed
```

Hardware, MIDI, serial LEDs, capture, diagnostics, and editing are supporting
systems. They should not become the first thing a drummer has to understand.

## Current Top-Level Shape

The implemented app currently opens into a single shell:

```text
AppShell
  -> Home
      -> Continue Practice
      -> Progress
      -> Up Next
  -> Explore
      -> Search lessons and exercises
      -> Filter by metadata
      -> Sort results
      -> Lesson Detail
  -> Practice Insights
  -> Author
      -> MIDI Capture
      -> Create Exercise draft
      -> Pattern Library
      -> Pattern Editor
  -> Settings
      -> Hardware & MIDI
```

The root shell uses responsive top-level navigation:

- desktop/tablet width: navigation rail
- phone width: bottom navigation

The current first screen is `Home`, backed by `TodayScreen`.

## Active Normal Student Flow

### Flow A: Open App

```text
Launch app -> Home
```

The user should immediately see what to practice next, not setup, diagnostics,
or authoring.

Home answers:

- What was I practicing?
- How much progress have I made?
- What should I work on next?
- What did I do recently?
- Are my practice devices connected?

Returning-user Home hierarchy:

1. Greeting
2. Device Status
3. Keep Practicing This
4. Progress
5. Up Next

First-light Home hierarchy:

1. Welcome to Drumcabulary
2. Explore Lessons
3. Record Exercise
4. Set Up Hardware, only as a support action

`docs/30_HOME_SCREEN_UX_CONTRACT.md` owns detailed Home content rules,
including device chips, section labels, metric scope, and first-light behavior.

Not allowed as primary first-screen content:

- raw MIDI diagnostics
- serial logs
- notation source editing
- pattern capture
- hardware setup dashboards
- empty charts
- zero-value analytics

### Flow B: Find Lesson

```text
Explore -> Search and filter -> Lesson Detail
```

Explore is a fast metadata-driven search surface, not a file browser, lesson
hierarchy, folder tree, or recommendation dashboard.

Rules:

- Search must match lesson titles, exercise titles, subtitles, summaries,
  teaching descriptions, and effective Content Metadata. Notation keywords and
  author keywords are future search inputs.
- The default Explore view keeps filters collapsed. Search, active filter
  badges, Add Filter, results count, sorting, and results are the permanent
  elements.
- Add Filter expands an inline panel containing metadata groups defined by
  `docs/29_LESSON_METADATA_CONTRACT.md`.
- Primary MVP filters are Fundamentals, Musical Vocabulary, Musical Context,
  Difficulty, Time Signature, and Status.
- Secondary filters are Objectives, Equipment, Feel, and Subdivision.
- Multiple chips may be active at once. Filters intersect across groups.
- Active filters appear as removable badges directly under Search. Clear All is
  available only when filters are active.
- Status is User Metadata and is single-select. In Progress and Completed may
  be used alone. Not Started is available only after search or another metadata
  filter narrows the catalog.
- Results are lightweight lesson cards with title, short description, metadata
  chips, generated or fallback duration, difficulty, and a save/favorite
  affordance.
- Result thumbnails use musical type icons: notes for lessons and a snare with
  sticks for exercises. Thumbnail color follows the result difficulty color.
- Sorting stays simple: Relevance, Alphabetical, Newest, Shortest, and Longest.
- Explore must not add nested browse-by flows, tree controls, learning paths,
  or recommendation systems.

### Flow C: Read, Hear, And Practice Lesson

```text
Lesson Detail -> Hear It
Lesson Detail -> Practice It
Lesson Detail -> Guided Practice
Lesson Detail -> Play Along
Lesson Detail -> Print Lesson
```

Lesson Detail is the main work surface.

It owns:

- lesson explanation
- one active exercise at a time
- exercise step navigation
- MIDI and LED status chips that link to hardware setup where supported
- Goal, Focus, and Tip for the active exercise
- a fixed lesson practice footer with BPM controls
- rendered notation
- Hear It playback
- Practice It handoff
- Play Along handoff
- Guided Practice handoff
- completion/progress action where present
- print/export

Rules:

- Lesson Detail must not render every exercise as a fully expanded section.
- The corrected hierarchy is Lesson Header, Exercise Navigator, Active Exercise
  Header, Goal | Focus | Tip, wrapped notation, then a fixed footer containing
  BPM controls and Practice It | Guided Practice | Hear It | Play Along.
- The top exercise navigator is the exercise selection surface. Do not duplicate
  collapsed exercise rows below the active card.
- BPM controls do not live inside Tip. The footer owns tempo because Hear It and
  Play Along both consume it.
- Footer practice-mode cards share one compact fixed height. Secondary detail
  labels sit directly under the card description; cards must not force square
  proportions or pin labels to the bottom with empty space.
- The notation sheet must not repeat a Hear It header/control when the footer
  already owns Hear It.
- More Actions contains only secondary lesson actions such as Print Lesson.

It must not own:

- hardware device selection
- raw MIDI logs
- serial port discovery
- pattern authoring
- note-map editing as normal content

### Flow D: Guided Practice

```text
Lesson Detail -> Guided Practice -> Stop Guided Practice
```

Guided Practice is entered from a specific exercise, not from Settings or a
generic player.

Prerequisites:

- MIDI input connected
- LED controller connected
- exercise can produce expected events

Rules:

- Starting Guided Practice stays in Lesson Detail.
- The current expected event is shown through the shared notation selection.
- LEDs cue the same current event.
- The flow continues until the user stops it or hardware disconnects.
- Hardware disconnect should stop the guided session without taking the user out
  of the lesson.

## Settings Flow

Settings is a support area, not a student practice destination.

```text
Root navigation -> Settings
Settings -> Hardware & MIDI
```

Settings owns:

- default BPM
- default timer
- click preference
- sheet-music display preference
- system/light/dark appearance mode
- app accent color
- app data reset
- mock scenarios when enabled
- desktop-only hardware setup entry

System/light/dark appearance mode and accent color apply immediately when
changed and persist as profile settings. System mode follows the OS appearance.
Other Settings controls may continue to use the existing Save Settings flow.

Settings should not become:

- a pattern library
- a normal practice launcher
- a raw diagnostic dashboard
- a long-term MIDI capture workspace
- a MIDI capture workspace

## Shell Header

On desktop-capable builds, the app shell owns the persistent hardware status
controls and the root destination title area.

```text
Root shell header left  -> screen title + subtitle
Root shell header right -> MIDI Kit + LED Controller
```

Rules:

- show MIDI Kit and LED Controller status in the same top-right location on
  every root navigation destination
- show the current root destination title and subtitle on the left side of the
  same header row
- keep root header copy concise; subtitles should be short guidance phrases,
  not sentence-length descriptions
- render root header titles and subtitles as one line with ellipsis overflow so
  long copy never pushes screen content down during navigation
- the root destination body starts below the header; the header is not an
  overlay on top of a scroll view
- align the controls to the same right content edge as screen content
- keep the controls visually stable; individual screens must not reposition,
  resize, or duplicate them as page-level headers
- root screens must not draw duplicate title/subtitle content inside their
  scrollable body
- the shell header owns one normal card gap between the header row and the
  scrollable body
- tapping either control opens a quick hardware connection modal
- the quick modal contains only device selection, refresh, connect, disconnect,
  and concise connection state
- selecting a MIDI or LED device from the modal starts connection immediately;
  the separate Connect button remains a recovery/manual action for the selected
  device
- the quick modal does not contain tests, orientation settings, raw diagnostics,
  or capture controls
- Settings continues to own the full Hardware & MIDI screen

## Hardware & MIDI Flow

Hardware setup is desktop-only.

```text
Settings -> Hardware & MIDI
```

Hardware & MIDI owns:

- MIDI input discovery
- MIDI input connection
- concise MIDI input test
- serial LED controller discovery
- serial LED connection
- concise LED test
- LED orientation settings

It must not show normal-user raw diagnostic cards:

- discovery internals
- latest raw event
- event log
- raw note-map inspection
- raw serial command log

Those belong behind a developer diagnostic route or debug-only mode.

## Author MIDI Capture Foundation Flow

Current placement:

```text
Author -> MIDI Capture card
```

Purpose:

- establish the first piece of the exercise-authoring foundation flow
- record mapped MIDI hits into editable voice-first notation
- create an Exercise draft from captured notation

Current behavior:

- visible only on desktop-capable platforms
- uses the shared MIDI input service
- requires the MIDI device to be connected first
- records mapped MIDI hits
- flashes the shared LED controller for each recorded live hit when the LED
  controller is connected
- ignores Note Off and velocity-zero Note On events
- emits voice-first notation such as `[HH K]`, `[OHH]`, `[S]`, and
  `[S:^R(L)(L)]`
- writes generated notation into an editable text field
- renders the edited/generated notation with the shared notation preview
- does not show local MIDI or LED device status buttons; the shell hardware
  header is the single normal device-management entry point
- can Hear It from the current valid notation using the existing playback engine
- can Play Along from the same playback engine, using LED lead cues when the
  shared LED controller is connected
- Play Along starts by lighting the first expected voice or simultaneous voice
  group, waits for the student to play that group, then starts the existing
  playback timeline just after that first event
- wrong input before Play Along starts shows LED error feedback, and incomplete
  simultaneous input shows missing LED feedback without starting playback
- can start Guided Practice from the current valid notation when MIDI input and
  the shared LED controller are connected
- does not infer hand sticking from MIDI velocity
- estimates BPM from grouped onset intervals

The Author capture card must not create its own playback or guided-practice
timeline. Hear It, Play Along, and Guided Practice are entry points into the
same playback, MIDI, notation-selection, and LED services used elsewhere.

This is now part of Author. It is still a foundation flow, not the final full
lesson-authoring suite.

## Exercise Authoring Flow - First Implementation

The reusable authoring unit is an Exercise.

Domain ownership:

- Pattern: the Drumcabulary notation string.
- Exercise: one reusable practice unit that owns one Pattern plus title and
  teaching notes.
- Lesson: an ordered collection of exercise references.
- Curriculum: an ordered collection of lessons.

Current compatibility decision:

- User-authored Exercises are backed by saved `PracticeItemV1` records for now.
- The `PracticeItemV1.pattern` field is the canonical notation source.
- `PracticeItemV1.name` is the Exercise title.
- `PracticeItemV1.notes` is the first-version instruction/description field.
- Existing YAML lessons continue to embed `LessonExercise` objects until a
  separate lesson-content migration introduces stable exercise references.

Temporary capture-to-exercise flow:

```text
Author -> MIDI Capture
MIDI Capture -> Generate notation
MIDI Capture -> Create Exercise draft
Exercise Editor -> review/edit notation and metadata
Exercise Editor -> save
```

Rules:

- MIDI capture is only an input method. It must not persist raw MIDI as the
  primary authored content.
- Creating an Exercise from capture must create an unsaved in-memory draft first.
- Saving must be explicit.
- Reopening and saving an existing Exercise must update the same stable ID.
- The Exercise Editor should be cross-platform.
- Manual notation editing should work on iPhone.
- MIDI capture should be desktop-only and optional.
- Capture should feed the same editor source string, not a separate pattern
  system.
- Replace and Append should be explicit actions.

Do not create a separate desktop-only Exercise Editor just for MIDI capture.

## Developer Diagnostic Flow

Developer diagnostics are not normal production navigation.

Developer-only tools may include:

- raw MIDI bytes
- latest raw event
- bounded event log
- note-map inspection
- serial discovery details
- raw serial command logs

Rules:

- Keep diagnostics useful for hardware troubleshooting.
- Do not expose them as normal student cards.
- Do not make diagnostics the only way to access production hardware setup.

## Practice Insights Flow

Practice Insights is a top-level destination, but it is not Home.

Current implementation:

- hierarchical Curriculum Compass navigation
- one stable Progress compass view; there is no Practice Time / Exercises
  Completed selector on this screen
- radial per-spoke chart for every non-empty compass level, including one-node
  and two-node states
- one-node and two-node states must not fall back to list/card presentation;
  their children are still compass spokes
- compass levels:
  - top-level curriculum categories
  - category topic nodes
  - interacted lessons within a topic
  - interacted exercises within a lesson
- the temporary top-level taxonomy is:
  - Timing
  - Grooves
  - Rudiments
  - Technique
  - Coordination
  - Dynamics
  - Vocabulary
  - Reading
  - Musicianship
  - Improvisation
- Vocabulary must contain Triads as a child node
- every compass is generated from the active curriculum node's prepared children;
  renderer code must not hardcode spoke names
- Progress derives from descendant lessons using
  `ExerciseProgress.status == completed -> Exercise -> Lesson -> curriculum
  node`
- each compass point carries one derived `progressRatio`: completed exercises
  divided by available exercises in that node's descendant content
- practice time is not part of the chart formula; it remains supporting context
  in the selected-node summary
- if a node has no available exercises, its Progress ratio is zero
  and the summary uses a `No exercises yet` state
- zero Progress renders on an inner zero ring, not at the chart center
- one hundred percent Progress renders on the outer ring
- the center of the compass is visually calm and may contain a small Progress
  label only
- tapping a compass spoke selects a node
- tapping a compass spoke updates label selection and summary immediately, but
  compass rotation waits until the double-click window has passed so the second
  click target does not move
- after the double-click window passes without activation, the selected spoke
  smoothly rotates to 12 o'clock
- compass rotation applies to spokes, rings, the progress polygon, and
  hit-test geometry together
- compass labels move with their spokes but their text remains upright and
  readable
- selected compass nodes must be visually obvious through the label only:
  selected labels use active accent styling and stronger text treatment, while the
  spoke and progress polygon keep the normal compass styling
- drilling into a category requires an explicit action; selection alone must not
  navigate
- double-clicking a compass spoke data point or label activates the same action as
  the selected-node button:
  - curriculum, category, and topic nodes with visible child nodes drill into the
    next compass level
  - lesson nodes with visible child nodes drill into the exercise compass
  - exercise nodes open or practice the exercise when an exercise route is
    available
- the compass remains the primary navigation surface through lesson and exercise
  depth:
  - opening a topic shows lesson titles as compass spokes
  - opening a lesson shows exercise titles as compass spokes
  - only opening an exercise leaves the compass
- topics with lesson content and lessons with exercise content filter their
  compass children to content the user has meaningfully interacted with
- a lesson is meaningfully interacted with when existing persisted progress shows
  it has been opened, started, practiced, completed, or has at least one
  interacted exercise
- an exercise is meaningfully interacted with when existing persisted progress
  shows it has been started, practiced, or completed
- untouched lessons and exercises remain accessible through conventional
  browse-all actions rather than being forced into the compass
- no-content and no-interaction states are distinct:
  - no content: `No exercises are available yet.`
  - content exists but no interaction: `You have not practiced any exercises in
    this lesson yet.`
- visible compass points are capped by the configured maximum of 10
- when more than 10 interacted points exist, explicit Previous/Next pagination
  switches the visible set; filtering, ordering, and pagination live in the data
  provider, not the painter
- interacted lesson and exercise nodes are ordered by most recent persisted
  interaction, then greatest practiced duration, then curriculum order
- breadcrumbs show the full current curriculum position and allow return to any
  ancestor
- selected-node summary content cross-fades when the selected node changes
- selected-node metric values animate visually to their new values without
  mutating persisted progress values
- curriculum nodes with children use a contextual `Explore <Node>` action label
- topic browse-all actions use `Browse All Lessons` and open Explore with the
  selected node's lesson filter
- lesson browse-all actions use `View All Exercises` and open the existing
  lesson detail route only as an explicit catalog escape hatch
- selected lesson summaries use `Explore <Lesson>` to drill into the exercise
  compass; they must not also show a default `Open Lesson` action
- selected exercise summaries use `Practice Exercise` to leave the compass and
  open the existing exercise/practice experience
- selected-node summaries show exact values:
  - Progress as a percentage derived from completed/available exercises
  - practiced duration, preserving `< 1 min` for nonzero sub-minute practice
  - completed exercise count out of available exercise count
  - lessons touched where useful
- curriculum nodes may provide optional short descriptions for the selected-node
  summary; descriptions are presentation metadata, not analytics or
  recommendations
- zero-progress selected-node summaries use intentional starting-state copy such
  as `Not practiced yet`, `No completions yet`, or `No exercises yet` while
  retaining useful numeric totals
- Home links to it from the progress summary

Practice Insights must not imply skill mastery, weakness, rating, ability,
accuracy, or recommendations. It is a practice and curriculum-completion
portrait only.

V1 limitations:

- cumulative all-time practice only
- no date filtering
- no session history
- no trend analysis
- no recency data
- no accuracy data
- no mastery model
- no BPM achievement model
- one lesson maps to one primary skill
- all exercise time rolls into that lesson's primary skill
- all exercise completions roll into that lesson's primary skill
- current real lessons are attached to the temporary taxonomy through
  `Lesson.skill`
- Progress radius is based on each child node's own completed/available exercise
  total
- lesson/exercise compass levels are personalized activity views, not complete
  catalogs
- the taxonomy is temporary and exists to validate hierarchical navigation
- values may change if curriculum content changes

## Implemented But Not Active In Normal Flow

These screens or systems exist in code but should not be treated as active
normal navigation until their flow is explicitly restored:

- `PatternScreen`
- `FocusScreen` / saved pattern library surface
- `MatrixScreen`
- detailed `ProgressScreen`
- full `PracticeScreen`
- `PracticeSessionScreen`
- `SessionSummaryScreen`
- raw `MidiDiagnosticScreen`

When reintroducing any of these, update this flow contract first.

## Known Flow Gaps

1. Pattern/Exercise editing is reachable from Author, but the broader lesson
   authoring flow is still incomplete.
2. MIDI Capture is now the first Author foundation flow, but the broader
   Exercise Authoring flow still needs refinement.
3. Settings is reachable from the root app shell, but child screens need a clear
   rule for whether global settings should remain visible from nested routes.
4. Raw MIDI diagnostics need an intentional developer-only access rule.
5. Older product docs need reconciliation with the current hardware and guided
   practice reality.

## Decision Rules For UI Work

Use these when improving the UI:

- If the user is trying to learn or practice, keep them in Coach and Lesson
  Detail.
- If the user is connecting hardware, send them to Settings -> Hardware & MIDI.
- If the user is authoring notation, send them to Pattern Editor once that route
  is restored.
- If the user is troubleshooting bytes or device internals, send them to
  developer diagnostics.
- If a screen mixes these jobs, split the flow before polishing the layout.
- If a control cannot name its destination clearly, the flow contract is missing
  a decision.

## Chat Context Pack For Flow Work

For app-flow UI work, include:

```text
docs/28_APP_FLOW_CONTRACT.md
docs/30_HOME_SCREEN_UX_CONTRACT.md
docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md
docs/25_DRUMMER_EDGE_UI_STYLE_GUIDE.md
docs/26_ART_DIRECTION_GUIDE.md
lib/features/app/app_shell.dart
lib/features/today/today_screen.dart
lib/features/coach/lesson_detail_screen.dart
lib/features/settings/app_settings_screen.dart
lib/features/settings/hardware_midi_settings_screen.dart
```

Add feature-specific files only when needed:

```text
lib/features/library/pattern_screen.dart
lib/features/midi/midi_pattern_capture.dart
lib/features/midi/midi_pattern_capture_panel.dart
lib/features/practice/widgets/sheet_notation_display.dart
```
