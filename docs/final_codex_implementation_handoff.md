
# Drum App Final Codex Implementation Handoff
**Implementation-grade handoff for Codex**
**Scope:** Coach, Matrix, Practice Session, shared state, selectors, routes, actions, fixture contracts, and build order

---

# 1. Intent

This app is a **practice engine** for drummers. It is not a passive dashboard, not just a content browser, and not a generic habit tracker.

The core loop is:

```text
Open app → Coach interprets practice data → user starts practice quickly → session updates progress → Matrix reflects structural state → Coach adapts
```

The three core screens must remain distinct:

- **Coach** = interpretation over practice data
- **Matrix** = structure + builder + progress map
- **Practice Session** = execution only

Do not collapse these roles together.

---

# 2. Architecture Summary

## 2.1 Recommended top-level module split

```text
features/
  coach/
  matrix/
  practice/
  working_on/
core/
  models/
  state/
  selectors/
  services/
  fixtures/
```

## 2.2 Responsibility split

### `features/coach`
- screen container
- Coach block rendering
- Coach CTA handlers
- Coach deep-link actions to Matrix / Practice

### `features/matrix`
- Matrix screen container
- filter chip groups
- context card
- matrix grid
- matrix cell component
- selection CTA
- quick-action menu for long press

### `features/practice`
- practice session screen
- session timer
- play/pause
- BPM / click controls
- rhythm visualization surface

### `core/models`
- shared domain interfaces and enums

### `core/state`
- app store state shape
- actions / reducers / notifiers / controllers (implementation style may vary)

### `core/selectors`
- derived data for Coach
- matrix visible cell state
- working-on summaries
- practice launch context

### `core/services`
- progress calculation
- recommendation engine
- practice session lifecycle
- persistence

### `core/fixtures`
- mock data for local development and UI testing

---

# 3. Screen Contracts

## 3.1 Coach Screen Contract

### Route
Suggested route:

```text
/coach
```

### Purpose
Coach is the interpretation layer over real practice data.

### Required inputs
Coach screen should derive from:
- active working-on items
- practice history
- progress summaries
- recency
- competency / stability markers
- recommendation engine output

### Required outputs / actions
Coach must support:
- start practice from Focus block
- start practice from Needs Work block
- start practice or expand from Momentum block
- resume active practice thread if present
- optional deep-link into Matrix slice for structural follow-up

### UI block order
1. Focus
2. Needs Work
3. Momentum / Strong
4. Resume (only if relevant)
5. Next Unlock (optional)

### Hard rules
- No generic dashboard clutter
- No full matrix duplication
- No static cards disconnected from live practice data
- Primary action must remain obvious

---

## 3.2 Matrix Screen Contract

### Route
Suggested route:

```text
/matrix
```

### Purpose
Matrix is the structural map and builder surface.

### Required inputs
Matrix screen should derive from:
- filter state
- selection state
- matrix progress state
- triad definitions
- practice item drafts in progress

### Required outputs / actions
Matrix must support:
- filter changes
- sub-filter changes
- cell selection / deselection
- ordered phrase building
- contextual start practice
- quick actions per cell
- optional add-to-working-on
- optional convert selection to combo / flow draft

### Hard rules
- Preserve filter/group selection behavior already working in the product
- Do not simplify into a generic progress-only heatmap
- Selection and progress must both remain visible

---

## 3.3 Practice Session Screen Contract

### Route
Suggested route:

```text
/practice/session/:sessionId
```

Alternate acceptable route:

```text
/practice/run
```

### Purpose
Pure execution surface.

### Required inputs
Practice session screen should receive or derive:
- practice item or launch context
- practice type
- triad / phrase labels
- BPM
- click state
- session timing state

### Required outputs / actions
- start session
- pause session
- resume session
- end session
- update session timing
- update BPM
- update click state

### Hard rules
- No Single Surface / Flow toggle on this screen
- Practice type is inherited from launch context / practice item
- Keep setup minimal
- Primary control must be Play / Pause

---

# 4. Concrete Data Types

Use these as the baseline implementation contracts unless the project already has equivalent types. If equivalent types exist, adapt them rather than creating duplicates.

## 4.1 Enums / unions

~~~ts
export type Hand = 'R' | 'L' | 'K';

export type LeadType = 'right' | 'left' | 'kick' | 'mixed';

export type PracticeType = 'singleSurface' | 'flow' | 'combo';

export type PracticeStatus = 'notStarted' | 'active' | 'needsWork' | 'strong';

export type CompetencyLevel = 'notStarted' | 'developing' | 'stable' | 'strong';

export type MatrixProgressState = 'notTrained' | 'active' | 'needsWork' | 'strong';

export type MatrixPrimaryFilter =
  | 'control'
  | 'balance'
  | 'dynamics'
  | 'integration'
  | 'phrasing'
  | 'flow'
  | 'coaching'
  | 'technique'
  | 'combos';

export type MatrixSecondaryFilter =
  | 'rightLead'
  | 'leftLead'
  | 'handsOnly'
  | 'all';

export type CoachBlockType =
  | 'focus'
  | 'needsWork'
  | 'momentum'
  | 'resume'
  | 'nextUnlock';
~~~

## 4.2 Core models

~~~ts
export interface Triad {
  id: string;
  label: string;
  rowGroup: string;
  columnGroup: Hand;
  firstStroke: Hand;
  strokes: [Hand, Hand, Hand];
  isHandsOnly: boolean;
  isKickInvolved: boolean;
  leadType: LeadType;
  tags: string[];
}

export interface PracticeItem {
  id: string;
  title: string;
  type: PracticeType;
  sourceTriadIds: string[];
  phraseSequence: string[];
  practiceType: 'singleSurface' | 'flow';
  status: PracticeStatus;
  competency: CompetencyLevel;
  isInWorkingOn: boolean;
  sessionCount: number;
  totalPracticeSeconds: number;
  lastPracticedAt?: string;
  createdAt: string;
  updatedAt: string;
  notes?: string;
  surfaceAssignments?: Record<string, string>;
}

export interface PracticeSession {
  id: string;
  practiceItemId: string;
  startedAt: string;
  endedAt?: string;
  durationSeconds: number;
  targetDurationSeconds?: number;
  bpm: number;
  clickEnabled: boolean;
  completed: boolean;
  mode: 'singleSurface' | 'flow';
}

export interface MatrixFilters {
  primary: MatrixPrimaryFilter;
  secondary: MatrixSecondaryFilter;
}

export interface MatrixSelectionState {
  selectedTriadIds: string[];
  orderedTriadIds: string[];
}

export interface MatrixCellVisualState {
  triadId: string;
  inScope: boolean;
  muted: boolean;
  progress: MatrixProgressState;
  selected: boolean;
  selectionOrder?: number;
}

export interface CoachBlock {
  id: string;
  type: CoachBlockType;
  title: string;
  subtitle?: string;
  body?: string;
  triadIds?: string[];
  practiceItemId?: string;
  ctaLabel: string;
  ctaAction:
    | 'startPractice'
    | 'resumePractice'
    | 'openMatrix'
    | 'buildCombo'
    | 'moveToFlow';
  matrixDeepLink?: Partial<MatrixFilters>;
}
~~~

---

# 5. Store / State Shape

~~~ts
export interface AppState {
  triads: Record<string, Triad>;
  practiceItems: Record<string, PracticeItem>;
  sessions: Record<string, PracticeSession>;
  workingOnIds: string[];

  matrix: {
    filters: MatrixFilters;
    selection: MatrixSelectionState;
  };

  practice: {
    activeSessionId?: string;
  };

  ui: {
    lastVisitedScreen?: 'coach' | 'matrix' | 'practice' | 'progress';
  };
}
~~~

## Hard requirements
- Matrix filter state and selection state must be independently stored
- Practice session state must not be conflated with matrix selection state
- Coach should derive from practice data and selectors, not be stored as static cards

---

# 6. Selectors / Derived State Contracts

## 6.1 Coach selectors

~~~ts
export function selectCoachFocus(state: AppState): CoachBlock | null;
export function selectCoachNeedsWork(state: AppState): CoachBlock | null;
export function selectCoachMomentum(state: AppState): CoachBlock | null;
export function selectCoachResume(state: AppState): CoachBlock | null;
export function selectCoachNextUnlock(state: AppState): CoachBlock | null;
~~~

### Logic notes
- Focus prioritizes active grouped work, recent unfinished work, and balanced recommendations
- Needs Work flags slipping or underperforming practiced items, not untouched items
- Momentum reflects real stability and recent gains
- Resume appears only when continuing something is meaningful
- Next Unlock bridges stable work into combos, flow, or balancing suggestions

## 6.2 Matrix selectors

~~~ts
export function selectVisibleTriads(state: AppState): Triad[];
export function selectMatrixCellState(
  state: AppState,
  triadId: string
): MatrixCellVisualState;
export function selectSelectedTriads(state: AppState): Triad[];
export function selectCanStartPracticeFromMatrix(state: AppState): boolean;
export function selectMatrixPracticeDraft(state: AppState): PracticeItem | null;
~~~

### Logic notes
- `selectVisibleTriads` respects current filters
- `selectMatrixCellState` layers scope, progress, and selection simultaneously
- selection must remain visible independently from progress fill

## 6.3 Practice selectors

~~~ts
export function selectActivePracticeSession(state: AppState): PracticeSession | null;
export function selectActivePracticeItem(state: AppState): PracticeItem | null;
export function selectPracticeDisplayLabel(state: AppState): string;
export function selectPracticeDescriptor(state: AppState): string | null;
~~~

---

# 7. Reducer / Action Contracts

## 7.1 Matrix actions

~~~ts
type MatrixAction =
  | { type: 'matrix/setPrimaryFilter'; payload: MatrixPrimaryFilter }
  | { type: 'matrix/setSecondaryFilter'; payload: MatrixSecondaryFilter }
  | { type: 'matrix/toggleTriadSelection'; payload: { triadId: string } }
  | { type: 'matrix/clearSelection' }
  | { type: 'matrix/removeSelectedTriad'; payload: { triadId: string } };
~~~

## 7.2 Practice item actions

~~~ts
type PracticeItemAction =
  | { type: 'practiceItem/createFromSelection'; payload: { practiceType: PracticeType } }
  | { type: 'practiceItem/addToWorkingOn'; payload: { practiceItemId: string } }
  | { type: 'practiceItem/removeFromWorkingOn'; payload: { practiceItemId: string } }
  | { type: 'practiceItem/updateStatus'; payload: { practiceItemId: string; status: PracticeStatus } }
  | { type: 'practiceItem/updateCompetency'; payload: { practiceItemId: string; competency: CompetencyLevel } };
~~~

## 7.3 Practice session actions

~~~ts
type PracticeSessionAction =
  | { type: 'practice/startFromCoach'; payload: { coachBlockId: string } }
  | { type: 'practice/startFromMatrixSelection' }
  | { type: 'practice/startFromPracticeItem'; payload: { practiceItemId: string } }
  | { type: 'practice/pauseSession'; payload: { sessionId: string } }
  | { type: 'practice/resumeSession'; payload: { sessionId: string } }
  | { type: 'practice/endSession'; payload: { sessionId: string } }
  | { type: 'practice/setBpm'; payload: { sessionId: string; bpm: number } }
  | { type: 'practice/setClickEnabled'; payload: { sessionId: string; clickEnabled: boolean } }
  | { type: 'practice/tick'; payload: { sessionId: string; elapsedSeconds: number } };
~~~

### Behavior requirements
- Starting from Coach may auto-create or auto-add a practice item
- Starting from Matrix should preserve selection order
- Ending session must update practice item aggregates

---

# 8. Route and Navigation Contracts

## 8.1 Primary tabs
- Coach
- Matrix
- Focus / Working On
- Progress

## 8.2 Deep-link contracts
- Coach → Practice opens immediately
- Coach → Matrix may deep-link with filter params
- Matrix → Practice launches selected cells
- Working On → Practice starts or resumes quickly

Example:

```text
/matrix?primary=control&secondary=leftLead
```

---

# 9. Component Responsibilities

## 9.1 Coach components
- `CoachScreen`
- `CoachFocusCard`
- `CoachNeedsWorkCard`
- `CoachMomentumCard`
- `CoachResumeCard`
- `CoachBlockChips`

## 9.2 Matrix components
- `MatrixScreen`
- `MatrixPrimaryFilterChips`
- `MatrixSecondaryFilterChips`
- `MatrixContextCard`
- `MatrixGrid`
- `MatrixCell`
- `MatrixSelectionCta`
- `MatrixCellQuickActions`

## 9.3 Practice components
- `PracticeSessionScreen`
- `PracticePatternHeader`
- `PracticeRhythmSurface`
- `PracticePrimaryControls`
- `PracticeTimer`
- `PracticeTempoControls`

### Rules
- Presentational components should not own recommendation logic
- `MatrixCell` should receive full derived visual state
- Practice screen should stay execution-focused

---

# 10. Matrix Visual Rules

## 10.1 Progress color mapping
- neutral/off-white/gray = not trained
- blue = active / in rotation
- orange-red = needs work
- green = strong

## 10.2 Selection styling
Use at least two:
- thicker border
- checkmark
- numbered badge
- slight lift

## 10.3 Filtering styling
- in-scope = normal contrast
- out-of-scope = muted / grayed

## 10.4 State stacking priority
1. scope/contrast
2. progress/fill
3. selection/border/check/number

---

# 11. Coach Visual Rules

- Focus is the dominant card
- Needs Work may use orange-red accents
- Momentum should feel earned and distinct
- Use direct labels: Focus, Needs Work, Momentum, Strong, Start Practice, Fix This, Build Combo, Move to Flow
- Avoid vague filler copy

---

# 12. Practice Screen Visual Rules

## 12.1 Primary hierarchy
1. pattern / phrase label
2. rhythm feedback surface
3. large Play / Pause control
4. timer
5. BPM / click

## 12.2 Explicit removals
Do not include:
- practice-type toggle that should already be known
- large instructional blocks
- configuration-heavy forms

---

# 13. Example Fixture Data

## 13.1 Triads fixture

~~~json
[
  {
    "id": "triad_rrr",
    "label": "RRR",
    "rowGroup": "RR",
    "columnGroup": "R",
    "firstStroke": "R",
    "strokes": ["R", "R", "R"],
    "isHandsOnly": true,
    "isKickInvolved": false,
    "leadType": "right",
    "tags": ["control", "handsOnly", "rightLead"]
  },
  {
    "id": "triad_lrr",
    "label": "LRR",
    "rowGroup": "RR",
    "columnGroup": "L",
    "firstStroke": "L",
    "strokes": ["L", "R", "R"],
    "isHandsOnly": true,
    "isKickInvolved": false,
    "leadType": "left",
    "tags": ["control", "handsOnly", "leftLead"]
  },
  {
    "id": "triad_kll",
    "label": "KLL",
    "rowGroup": "LL",
    "columnGroup": "K",
    "firstStroke": "K",
    "strokes": ["K", "L", "L"],
    "isHandsOnly": false,
    "isKickInvolved": true,
    "leadType": "kick",
    "tags": ["flow", "integration"]
  }
]
~~~

## 13.2 Practice item fixture

~~~json
{
  "id": "pi_focus_001",
  "title": "Hands-only left lead set",
  "type": "singleSurface",
  "sourceTriadIds": ["triad_lrr"],
  "phraseSequence": ["triad_lrr"],
  "practiceType": "singleSurface",
  "status": "needsWork",
  "competency": "developing",
  "isInWorkingOn": true,
  "sessionCount": 4,
  "totalPracticeSeconds": 780,
  "lastPracticedAt": "2026-04-06T18:10:00Z",
  "createdAt": "2026-03-28T16:00:00Z",
  "updatedAt": "2026-04-06T18:10:00Z"
}
~~~

## 13.3 Practice session fixture

~~~json
{
  "id": "session_001",
  "practiceItemId": "pi_focus_001",
  "startedAt": "2026-04-07T14:00:00Z",
  "durationSeconds": 155,
  "targetDurationSeconds": 600,
  "bpm": 92,
  "clickEnabled": true,
  "completed": false,
  "mode": "singleSurface"
}
~~~

## 13.4 Coach block fixture

~~~json
{
  "id": "coach_focus_001",
  "type": "focus",
  "title": "Focus",
  "subtitle": "Left-lead control",
  "body": "Reinforce the weaker side before moving into combos.",
  "triadIds": ["triad_lrr"],
  "practiceItemId": "pi_focus_001",
  "ctaLabel": "Start Practice",
  "ctaAction": "startPractice",
  "matrixDeepLink": {
    "primary": "control",
    "secondary": "leftLead"
  }
}
~~~

---

# 14. Acceptance Criteria

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

# 15. Recommended Build Order

1. Lock shared domain types
2. Wire or adapt store shape
3. Implement Coach selectors
4. Implement Matrix cell derived state
5. Reconnect existing filter and grouped-selection logic
6. Add Matrix selection CTA
7. Refactor Practice Session to execution-only
8. Wire Coach → Practice and Coach → Matrix deep-links
9. Add fixtures and test with selector-driven data
10. Tune thresholds for needsWork / strong / momentum

---

# 16. Engineering Checklist

## Data / state
- [ ] Triad model aligned
- [ ] PracticeItem model aligned
- [ ] PracticeSession model aligned
- [ ] Matrix filters and selection stored independently
- [ ] Derived state computed via selectors

## Coach
- [ ] Focus block implemented
- [ ] Needs Work block implemented
- [ ] Momentum block implemented
- [ ] Resume block implemented when relevant
- [ ] Coach CTAs launch correct routes/actions

## Matrix
- [ ] Existing filters preserved
- [ ] Existing grouped-selection behavior preserved
- [ ] Progress fill added
- [ ] Selection overlay added
- [ ] Long-press quick actions wired
- [ ] Start Practice CTA appears only when valid

## Practice
- [ ] Single Surface / Flow toggle removed from session screen
- [ ] Large Play / Pause control implemented
- [ ] Rhythm feedback surface implemented
- [ ] Timer implemented
- [ ] BPM / click controls kept secondary
- [ ] Session completion updates aggregates

---

# 17. Final Product Summary

- **Coach** interprets real practice history and tells the user what matters now
- **Matrix** preserves the structural intelligence of the triad system, supports filtering and grouping, and overlays progress without losing builder behavior
- **Practice Session** is a focused execution surface with minimal friction

This redesign must protect what already works in the matrix, clarify screen roles, and strengthen the loop between guidance, structure, practice, and progress.
