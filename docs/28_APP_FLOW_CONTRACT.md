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
      -> Pattern Library
      -> Pattern Editor
  -> Settings
      -> Hardware & MIDI
      -> temporary MIDI Capture panel
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

- Search must match lesson titles, exercise titles, descriptions, keywords,
  notation text, and metadata labels.
- The default Explore view keeps filters collapsed. Search, active filter
  badges, Add Filter, results count, sorting, and results are the permanent
  elements.
- Add Filter expands an inline panel containing metadata groups such as Skills,
  Difficulty, Genre, Status, Time Signature, Rudiments, Tempo Range, Equipment,
  Feel, Subdivision, Hand Focus, and Foot Focus.
- Multiple chips may be active at once. Filters intersect across groups.
- Active filters appear as removable badges directly under Search. Clear All is
  available only when filters are active.
- Status is single-select. In Progress and Completed may be used alone. Not
  Started is available only after search or another metadata filter narrows the
  catalog.
- Results are lightweight lesson cards with title, short description, metadata
  chips, duration, difficulty, and a save/favorite affordance.
- Sorting stays simple: Relevance, Alphabetical, Newest, Shortest, and Longest.
- Explore must not add nested browse-by flows, tree controls, learning paths,
  or recommendation systems.

### Flow C: Read, Hear, And Practice Lesson

```text
Lesson Detail -> Hear It
Lesson Detail -> Practice It
Lesson Detail -> Guided Practice
Lesson Detail -> Print Lesson
```

Lesson Detail is the main work surface.

It owns:

- lesson explanation
- one active exercise at a time
- exercise step navigation
- Goal, Focus, and Tip for the active exercise
- inline BPM controls attached to the active exercise Tip
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
  Header, Goal | Focus | Tip + BPM controls, wrapped notation, then Practice It
  | Guided Practice | Hear It | Play Along.
- The top exercise navigator is the exercise selection surface. Do not duplicate
  collapsed exercise rows below the active card.
- There is no sticky lesson footer. BPM controls live beneath Tip.
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
- app data reset
- mock scenarios when enabled
- desktop-only hardware setup entry
- temporary MIDI Capture panel while authoring flow is being refined

Settings should not become:

- a pattern library
- a normal practice launcher
- a raw diagnostic dashboard
- a long-term MIDI capture workspace

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

## Temporary MIDI Capture Flow

Current temporary placement:

```text
Settings -> MIDI Capture panel at the end
```

Purpose:

- recover and verify the working capture path while the Pattern Editor flow is
  being redesigned

Current behavior:

- visible only on desktop-capable platforms
- uses the shared MIDI input service
- requires the MIDI device to be connected first
- records mapped MIDI hits
- flashes the shared LED controller for each recorded live hit when the LED
  controller is connected
- ignores Note Off and velocity-zero Note On events
- emits voice-first notation such as `[HH K]`, `[OHH]`, and `[S]`
- writes generated notation into an editable text field
- renders the edited/generated notation with the shared notation preview
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

The temporary capture panel must not create its own playback or guided-practice
timeline. Hear It, Play Along, and Guided Practice are entry points into the
same playback, MIDI, notation-selection, and LED services used elsewhere.

This is not the final product location. The intended future home is Exercise
Authoring.

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
Settings -> MIDI Capture
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

- lightweight placeholder destination
- no fake charts
- no invented coaching
- Home links to it from the progress summary

Future implementation should consume real practice sessions and exercise
completion data before adding charts or trend summaries.

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

1. Pattern authoring exists in code but has no normal entry point.
2. MIDI Capture is temporarily in Settings instead of its intended authoring
   flow.
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
