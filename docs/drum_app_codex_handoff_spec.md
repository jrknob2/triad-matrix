
# Drum App UX / Product Handoff Spec
**Project handoff for Codex implementation**
**Scope:** Coach, Matrix, Practice Session, and their shared data/interaction model

---

# 1. Product Intent

This app is not a generic content browser and not a passive dashboard. It is a **practice engine** for drummers built around triads, combos, flow, and progress over time.

The app should feel like this:

```text
Open app → know what to do → start practicing quickly → see progress → get better guidance next time
```

The three core screens have different jobs and must not blur together:

- **Coach** = interpretation layer over practice data
- **Matrix** = structure + exploration + builder + progress map
- **Practice Session** = execution only

That separation is important. Do not merge their roles.

---

# 2. System Loop

```text
Coach suggests → user starts practice → session updates practice data → Matrix reflects structural progress → Coach adapts recommendations
```

Supporting loops:

```text
Matrix → select/build → Start Practice
Working On / active items → Start Practice
Coach → deep-link to Matrix slice when useful
```

---

# 3. Screen Responsibilities

## 3.1 Coach
Coach is **data-driven from practice state**, not a duplicate of the Matrix and not a generic dashboard.

Coach should answer:
- What should I practice now?
- What is slipping?
- What is improving?
- What is close to leveling up?
- What should expand into combos or flow next?

Coach should not primarily show:
- full matrix visualization
- long lists
- generic motivational content
- static recommendation cards disconnected from practice data

### Coach block model
Preferred block stack:

1. **Focus** (primary)
2. **Needs Work**
3. **Momentum / Strong Area**
4. **Resume** (optional, only when relevant)
5. **Next Unlock** (optional bridge into Matrix or combo/flow work)

### Coach CTA behavior
- Primary CTA should be **Start Practice**
- If Coach recommends a set of triads not currently in Working On, the app may auto-add them behind the scenes before launching practice
- Coach may offer a secondary deep-link into Matrix for structure/exploration, but that must remain secondary

### Coach tone
Coach should be honest and direct, not softened into vague language.

Approved conceptual labels:
- Focus
- Needs Work
- Momentum
- Strong
- Next Unlock
- Resume

Coach should be allowed to clearly surface undertrained or slipping areas.

---

## 3.2 Matrix
Matrix is the structural map of the triad system and the main builder/explorer surface.

Matrix should answer:
- What patterns exist?
- What slice of the system am I viewing?
- Where am I strong?
- Where do I need work?
- What is active?
- What patterns do I want to practice now?
- What phrase/combo/flow path am I building?

Matrix must preserve the strong interaction model already established in the product:
- category filters
- sub-filters
- grouped selection behavior
- phrase/flow selection behavior
- explanatory context cards

The redesign must **preserve those working mechanics** and layer progress on top of them. It must not replace them with a generic progress heatmap.

### Matrix modes/lenses
The same screen may support multiple lenses:
- Learn / Explore
- Build / Select
- Progress / Strength / Needs Work overlay

This can be done with toggles or simply by layering state into cells; implementation choice is flexible so long as it remains clear.

---

## 3.3 Practice Session
Practice Session is execution only.

It should answer:
- What am I playing right now?
- Am I playing or paused?
- How fast?
- How long into this session am I?

Practice Session must **not** be overloaded with configuration decisions.

### Practice Session rules
- No mode selection here for things that should already be defined by the practice item
- If a practice item is Single Surface, the session is single-surface aware
- If a practice item is Flow, the session is flow-aware and should present the right surface/mapping info
- The session should emphasize:
  - current pattern / phrase
  - visual rhythm feedback
  - timer
  - large play / pause control
  - BPM / click controls as secondary settings

### Explicit removal
The Single Surface / Flow toggle does **not** belong on the Practice Session screen. Practice type is part of the item definition or launch context, not a mid-session toggle.

---

# 4. Existing Working Concepts That Must Be Preserved

These are already working concepts from the current app and must not be accidentally removed during redesign:

## 4.1 Matrix filter model
Examples include:
- Control
- Balance
- Dynamics
- Integration
- Phrasing
- Flow
- Coaching
- Technique
- Combos
- Right Lead
- Left Lead
- Hands Only

These are not decorative chips. They are part of the learning system.

## 4.2 Grouped selection behavior
The matrix already supports useful group selection patterns and slice views. Preserve that. These help the user see:
- lane-based subsets
- lead-hand subsets
- hands-only subsets
- phrase-building subsets
- flow-building subsets

## 4.3 Context framing cards
The contextual explanation cards at the top of matrix slices are useful and should remain, but their copy should be tighter and more concise.

---

# 5. Shared Data Model

Below is a suggested conceptual model. Naming can vary, but the separation of responsibilities should remain.

## 5.1 Core entities

### Triad
A single triad cell in the system.

Suggested fields:
- `id: string`
- `label: string`  // e.g. "RRR", "LRR", "KLL"
- `firstStroke: "R" | "L" | "K"`
- `rowGroup: string` // e.g. RR, LL, RL, LR, KK, RK, LK, etc.
- `columnGroup: "R" | "L" | "K"`
- `isHandsOnly: boolean`
- `isKickInvolved: boolean`
- `leadType: "right" | "left" | "kick" | "mixed"`
- `tags: string[]` // e.g. ["control", "phrasing", "leftLead"]

### PracticeItem
A user-workable practice definition.

Suggested fields:
- `id: string`
- `type: "singleSurface" | "flow" | "combo"`
- `title: string`
- `sourceTriadIds: string[]`
- `phraseSequence: string[]` // ordered triad ids when combo/flow applies
- `status: "notStarted" | "active" | "needsWork" | "strong"`
- `competency: "notStarted" | "developing" | "stable" | "strong"`
- `isInWorkingOn: boolean`
- `createdAt: DateTime`
- `updatedAt: DateTime`
- `lastPracticedAt?: DateTime`
- `sessionCount: number`
- `totalPracticeSeconds: number`
- `practiceType: "singleSurface" | "flow"`
- `notes?: string`
- `surfaceAssignments?: object` // only for flow / orchestrated items

### PracticeSession
Represents one launched practice session.

Suggested fields:
- `id: string`
- `practiceItemId: string`
- `startedAt: DateTime`
- `endedAt?: DateTime`
- `durationSeconds: number`
- `targetDurationSeconds?: number`
- `bpm: number`
- `clickEnabled: boolean`
- `completed: boolean`
- `mode: "singleSurface" | "flow"` // derived from practice item, not user-switched mid-session

### MatrixCellProgress
Derived or cached state for how a triad appears in the matrix.

Suggested fields:
- `triadId: string`
- `status: "notTrained" | "active" | "needsWork" | "strong"`
- `selected: boolean`
- `selectionOrder?: number`
- `inScope: boolean`
- `muted: boolean`
- `lastPracticedAt?: DateTime`
- `sessionCount: number`
- `totalPracticeSeconds: number`

---

# 6. Derived State / Recommendation Logic

Coach should be built from derived practice state, not from hardcoded cards.

## 6.1 Focus
The best current practice target.

Likely inputs:
- items in Working On
- most important active set
- current emphasis
- recent incomplete work
- recommended balanced set for the day

Example output:
- a set of 3–4 triads
- one combo
- one flow path
- one active practice thread

## 6.2 Needs Work
Items that deserve attention now.

Likely triggers:
- practiced but inconsistent
- slipping from prior strength
- neglected too long
- weak relative to adjacent patterns or lead side
- repeatedly active but not stabilizing

Important:
- “needs work” should mean something real
- it should not be the default state for untouched cells

## 6.3 Momentum / Strong
Reward / earned progress.

Likely triggers:
- repeated recent successful sessions
- stable work over time
- progress threshold crossed
- consistent work in a lane or category

## 6.4 Next Unlock
Bridge from current stable work to the next meaningful expansion.

Examples:
- stable triads → combo suggestion
- stable hands-only lane → flow recommendation
- strong right lead → left lead balancing suggestion

---

# 7. Matrix State Model

The Matrix must support stacked meaning in each cell.

A cell is not just on or off. It may simultaneously be:
- in current filter scope
- selected into a phrase
- strong
- active
- needs work
- muted because excluded by sub-filter

## 7.1 Cell state layers

### Layer A: Filter / scope state
Controlled by current chips and sub-filters.
- in-scope = normal contrast
- out-of-scope = muted / grayed

### Layer B: Progress state
Controlled by training history.
- not trained
- active
- needs work
- strong

### Layer C: Selection state
Controlled by user interaction.
- selected
- selected with sequence order (1, 2, 3...)
- phrase member
- flow member

## 7.2 Visual rules
Use these rules consistently:

- **Progress = fill / background tint**
- **Selection = border / check / numeric badge**
- **Filtering = visibility / muting / contrast**

Do **not** rely on fill color alone to represent selection, because fill is already needed for progress.

---

# 8. Visual State Mapping

## 8.1 Matrix colors
Preferred conceptual mapping:

- Neutral / off-white / gray = not trained
- Blue = active / in rotation
- Orange-red = needs work
- Green = strong

Important notes:
- Orange-red is acceptable for needs work
- Red/orange-red should mean something real, not just “untouched”
- Avoid turning the whole matrix into a warning field
- Green should feel earned, not automatic

## 8.2 Selection styling
Because progress already uses fill color, selection should be communicated with:
- thicker/darker border
- checkmark
- ordered badge (1, 2, 3...)
- optional slight lift or shadow increase

Selection must remain visible even on blue / orange-red / green cells.

---

# 9. Interaction Model

## 9.1 Coach interactions
### Primary
- Tap primary CTA → Start Practice

### Secondary
- Tap Needs Work block → launch focused practice set or deep-link to relevant Matrix slice
- Tap Momentum block → build combo or expand into next level
- Tap Resume → continue last active item/session if supported

## 9.2 Matrix interactions
### Tap cell
- select / deselect

### Long press cell
Open quick actions such as:
- Practice now
- Add to Working On
- Configure
- Build combo from selection
- Start flow from selection (only when valid)

### Tap filter chips
- change visible slice
- adjust in-scope cells
- update context card
- preserve compatible selection when possible, clear invalid selection when necessary

### CTA behavior
If one or more cells are selected:
- show contextual CTA like `Start Practice (3)`

## 9.3 Practice Session interactions
- Play / Pause is primary
- End Session is secondary
- BPM / click are adjustable but visually subordinate
- practice type is inherited, not switched mid-session

---

# 10. Screen-by-Screen Implementation Notes

## 10.1 Coach screen implementation guidance
Coach should not be a static set of pretty cards. It should be populated from real practice data.

Suggested layout:
1. Focus card (prominent)
2. Needs Work card
3. Momentum / Strong card
4. Resume / Continue card if relevant

### Focus card contents
- small label
- selected triads / combo chips
- short plain-language explanation
- single dominant CTA

### Needs Work card contents
- one or more target chips
- short explanation tied to actual performance history
- direct CTA like `Fix This` or `Start Practice`

### Momentum card contents
- strong or recently improving items
- short explanation
- CTA like `Build Combo`, `Expand`, or `Move to Flow`

## 10.2 Matrix screen implementation guidance
Suggested layout order:
1. Header
2. Top-level filter chips
3. Context / explanation card
4. Secondary filter chips
5. Matrix grid
6. Contextual bottom CTA when selection exists

Do not remove the existing matrix filter/grouping logic in favor of a simpler progress-only grid.

## 10.3 Practice Session screen implementation guidance
Suggested layout order:
1. Header / session label
2. current triad / phrase label
3. very short descriptor (e.g. “Even strokes”)
4. central rhythm feedback surface
5. large Play / Pause control
6. timer
7. secondary controls (BPM, click)

Keep the screen feeling like an instrument, not a form.

---

# 11. Copy / Content Guidelines

## Coach
Use direct, useful copy. Avoid empty encouragement and avoid generic dashboard labels.

Good examples:
- Focus
- Needs Work
- Momentum
- Strong
- Resume
- Next Unlock
- Start Practice
- Fix This
- Build Combo
- Move to Flow

## Matrix
Context cards should be short and explain why a slice matters.

Good structure:
- category name
- 1 concise paragraph or 1–2 short sentences

Example:
```text
Control
Clean up pulse, rebound, and even sound here before adding more variables.
```

## Practice Session
Use minimal copy.
Examples:
- Even strokes
- Left lead control
- Combo transition
- Flow phrase

---

# 12. Non-Goals / What Not To Do

Do not:
- merge Coach and Matrix into one screen
- turn Matrix into only a heatmap
- make Practice Session responsible for setup decisions
- remove working filter/group selection mechanics from Matrix
- represent selection solely by fill color
- mark untouched cells as “needs work” by default
- overload Coach with long lists or static dashboard clutter

---

# 13. Acceptance Criteria

## Coach
- derives recommendations from practice data
- clearly surfaces Focus, Needs Work, and Momentum
- supports immediate Start Practice
- does not duplicate Matrix structure unnecessarily

## Matrix
- preserves existing filter and grouped-selection behavior
- supports progress overlays
- supports multi-select / sequence building
- displays selection and progress simultaneously without ambiguity
- supports contextual Start Practice from selected cells

## Practice Session
- has no practice-type toggle that should have been defined earlier
- emphasizes play/pause and rhythm feedback
- keeps BPM/click as secondary controls
- feels like execution, not configuration

---

# 14. Recommended Build Order

1. Refactor / lock shared data model
2. Build derived recommendation helpers for Coach
3. Refactor Matrix cell rendering to support stacked state
4. Preserve and reconnect existing filter/group logic
5. Implement contextual selection CTA in Matrix
6. Simplify Practice Session into execution-only surface
7. Connect Coach → Practice and Coach → Matrix deep-links
8. Tune recommendation thresholds for Needs Work / Strong / Momentum

---

# 15. Suggested Engineering Interfaces

These are conceptual helper functions. Naming can vary.

## Coach
- `getCoachFocus(practiceState) -> CoachFocusBlock`
- `getCoachNeedsWork(practiceState) -> CoachNeedsWorkBlock`
- `getCoachMomentum(practiceState) -> CoachMomentumBlock`
- `getCoachResume(practiceState) -> CoachResumeBlock | null`

## Matrix
- `getVisibleTriads(filters) -> Triad[]`
- `getMatrixCellState(triadId, filters, selection, progress) -> MatrixCellProgress`
- `toggleTriadSelection(triadId, currentSelection) -> SelectionState`
- `buildPhraseFromSelection(selection) -> PracticeItemDraft`

## Practice
- `startPracticeFromCoach(coachBlock) -> PracticeSession`
- `startPracticeFromMatrix(selection) -> PracticeSession`
- `startPracticeFromItem(practiceItemId) -> PracticeSession`

---

# 16. Final Product Summary

The product should behave like this:

- **Coach** interprets the user’s real practice history and tells them what matters now
- **Matrix** preserves the structural intelligence of the triad system, supports filtering and grouping, and overlays progress without losing builder behavior
- **Practice Session** is a focused execution surface with minimal friction

The redesign must protect what already works in the matrix, clarify the roles of the screens, and strengthen the loop between guidance, structure, practice, and progress.
