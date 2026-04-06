# Alignment Execution Plan

## Purpose

This document converts the teaching reset into a concrete product direction and execution plan.

It captures product-owner decisions made after the reset and turns them into:

- product framing
- screen responsibilities
- MVP boundaries
- data/model implications
- post-MVP expansion points

This is the working plan to align the app with a clearer teaching philosophy before more feature work.

## Locked Product Decisions

These decisions are now assumed unless explicitly changed later.

### 1. Core promise

The app's core promise is:

**turn pattern material into musical vocabulary**

That includes:

- single triads
- triad combinations
- longer phrases built from several triads
- later, 5-note groupings as an expansion family

The app is not primarily about:

- collecting patterns
- catalog completion
- storing favorite ideas
- generalized drummer level

### 2. 5-note groupings

5-note grouping is a **post-triad expansion**.

It is important, but it should not compete with establishing the triad system first.

### 3. Custom patterns

Users should be able to add any pattern they like as custom phrasing.

But custom patterns should not distort the app's teaching priorities.

Therefore custom patterns should:

- live in a separate bucket
- be easy to practice on demand
- be easy to hear and review
- not be included in core coaching analysis
- not affect matrix coverage or triad progression logic
- not dilute the app's recommendations about what matters most

### 4. Focus / Working On repositioning

The current `Toolkit` concept should be repositioned.

Two distinct ideas exist and should not be conflated:

- material the student is **working on now**
- material the student has **earned and can call on musically**

Those are different product surfaces.

### 5. Today recommendations

`Today` should recommend work across the teaching spine rather than only surface a generic ranked list.

That means Today should help maintain momentum in the meaningful lanes of development.

### 6. Combo practice distinction

The app must clearly distinguish between:

- a phrase as material
- the mode in which that phrase is practiced

Any triad combination should be practiceable in either:

- `single surface`
- `flow`

The distinction is not the phrase itself. The distinction is the presence or absence of voice assignment and kit application.

### 7. Flow matters in the core vision

The app must support **flow**:

- applying patterns to the kit
- assigning voices
- hearing how the phrase works musically

This does not need to be fully realized in MVP, but the design must make room for it from the start.

## Product Framing

### Recommended product sentence

Drumcabulary helps drummers turn triads and related linear phrases into usable musical vocabulary through guided work in control, balance, dynamics, phrasing, and kit application.

### What the app teaches

The app teaches a progression:

1. own the cell
2. own both leads
3. shape the cell dynamically
4. combine cells into phrases
5. move phrases onto the kit
6. turn phrases into usable vocabulary

### What the app does not try to be

At MVP, it should not try to be:

- a universal drum curriculum
- a full rudiment trainer
- a notation editor
- a general drum practice logger

## Naming Model

### Current problem

`Toolkit` is currently overloaded.

It is trying to mean:

- current work
- saved material
- combos
- customs
- mastered material

That creates conceptual blur.

### Recommended naming

#### 1. `Today`

Daily direction and assignments.

#### 2. `Matrix`

Vocabulary map, analysis surface, and combo-builder entry point.

#### 3. `Focus`

The main-tab label should be `Focus`.

The screen title can read `Working On`.

This replaces the current broad meaning of `Toolkit`.

`Focus / Working On` is the active working set:

- current assignments
- active combos
- phrases under development

#### 4. `Library`

Optional later surface for saved customs, references, and user-kept materials.

This does not need to be a main MVP tab.

#### 5. `Progress`

Retention, balance, coverage, milestones.

#### 6. `Toolbox`

This is a valid and useful name, but it should mean something specific:

**material that is reliable enough to call on musically**

So yes, `Toolbox` is a good name for mastered / available-on-demand vocabulary.

It should not be the same thing as:

- routine
- work in progress
- saved favorites

### Recommendation

Use:

- `Focus` for the tab label
- `Working On` for the active development screen title
- `Toolbox` for earned, ready-to-use material
- `Custom` as a bucket inside `Library` or a sub-area of `Focus`, but excluded from coaching analysis

## Teaching Spine

The app should explicitly organize around these lanes.

### 1. Control

Goal:

- even sound
- relaxed motion
- stable pulse

Typical material:

- hands-only triads
- repeated single cells

### 2. Balance

Goal:

- right-lead / left-lead symmetry
- non-dominant-side development

Typical material:

- mirrored lead work
- opposite-lead pairs

### 3. Dynamics

Goal:

- accent/tap contrast
- ghost-note control
- touch and shape

Typical material:

- accented triads
- ghosted inner notes

### 4. Integration

Goal:

- clean kick inclusion
- stable linear coordination

Typical material:

- kick-containing triads
- starts/ends-with-kick studies

### 5. Phrasing

Goal:

- longer phrase retention
- transitions between cells
- fill language and grouping awareness

Typical material:

- 2-cell combos
- 3- to 5-triad phrases
- later, 5-note grouping studies

### 6. Flow

Goal:

- orchestrated kit movement
- voice assignment
- musical continuity
- usable fill/groove vocabulary

Typical material:

- orchestrated combos
- voice-mapped phrases
- later, playback and animated kit guidance

## Single-Surface Practice vs Flow Practice

This distinction needs to be explicit in the product.

### Phrase-first model

A combo is a phrase.

The same phrase can be used to:

- develop core control on one surface
- develop flow through voice assignment and kit application

That means the app should not permanently classify a combo as either "core skill" or "flow."

Instead:

- `phrase` is the material
- `practice mode` is how the player works on it

### Single-Surface Practice

Purpose:

- build control
- reinforce transitions
- develop stamina
- expose weak links

Characteristics:

- often practiced on one surface
- limited orchestration
- clear repeated phrase loops
- often symmetrical or intentionally corrective

Typical examples:

- mirrored lead pairings
- repeated two-cell transitions
- weak-side-biased phrases

### Flow Practice

Purpose:

- build musical movement
- develop phrasing across surfaces
- teach voice assignment and contour
- create usable fill and vocabulary language

Characteristics:

- assigned voices
- surface movement matters
- dynamic shape matters
- phrasing is more important than raw repetition

Typical examples:

- a 4-triad phrase voiced across snare, toms, and kick
- an accent-led phrase with clear contour
- a linear fill phrase intended to be heard, not just drilled

### Product implication

Any phrase should be able to open in either:

- `singleSurface`
- `flow`

`Flow` should mean:

- note-level voice assignment
- eventual kit visualization
- eventual flow playback

## Today: Recommended Analysis and Output Model

### Today should recommend by lane

Rather than one undifferentiated feed, Today should surface one recommendation per teaching lane, or per a selected subset of lanes.

Recommended structure:

- `Control`
- `Balance`
- `Dynamics`
- `Integration`
- `Phrasing`
- `Flow`

Each lane should answer:

- what is recommended
- why
- what action is available now

### Lane-specific recommendation angles

#### Control

Look at:

- under-practiced hands-only triads
- triads with high reflection difficulty
- items with time logged but low competency

#### Balance

Look at:

- lead-side imbalance
- missing opposite-lead coverage
- right-heavy or left-heavy routine patterns

#### Dynamics

Look at:

- items practiced plain but not dynamically
- items with accents but no ghost-note work
- dynamic studies neglected recently

#### Integration

Look at:

- kick-containing cells with low time
- starts/ends-with-kick blind spots
- kick material avoided relative to hands-only work

#### Phrasing

Look at:

- overreliance on single-cell work
- combos with low revisit frequency
- transitions that have time but low confidence

#### Flow

Look at:

- phrases flagged for kit application but not yet voiced
- phrases worked on pad only
- orchestrated phrases not revisited

### Recommended Today layout

#### Hero

Should identify today's primary lane:

- "Today centers on Balance."
- "Today centers on Phrasing."

Not hard-coded inspiration. A true lane decision.

#### Lane cards

Each lane card should include:

- lane name
- short teacher-style reason
- one featured item or phrase
- action button

Potential actions:

- `Practice`
- `Open in Matrix`
- `Add to Focus`
- `Voice for Flow`

#### Momentum strip

Below lane cards:

- one `Close to Toolbox` item
- one `Neglected` item
- one `Recent Win` or `Needs Review` item

This gives continuity without overpowering the lane structure.

## MVP Scope

### Main screens

Recommended main navigation for MVP:

1. `Today`
2. `Matrix`
3. `Focus`
4. `Progress`

Settings remains secondary.

### Today

Must do:

- generate lane-based recommendations from actual data
- use teacher voice
- start practice directly
- move items into active work

Should not do:

- act like a static dashboard
- use hard-coded headline logic

### Matrix

Must do:

- remain the central vocabulary surface
- support analysis filters
- support phrase building
- support sending selected material to Work
- support starting practice

Should later do:

- support flow voice previews
- support more explicit teaching-stage overlays

### Focus

Must do:

- hold active assignments
- separate active combos from custom bucket
- surface why an item is here
- support direct practice

Should not do:

- become a junk drawer

### Progress

Must do:

- show retention
- show balance
- show coverage
- show near-toolbox candidates

Should not do:

- overvalue custom patterns
- flatten all families into one undifferentiated leaderboard

### Practice Session

Must do:

- make phrase visually dominant
- support session-only dynamic edits
- show lane / purpose
- support direct logging

Should later do:

- support auditory reference playback
- support flow voice playback
- support animated kit guidance

## Data Model Implications

### Practice items

Built-in triads and structured combos should stay central to tracked analysis.

Custom patterns should be explicitly flagged:

- `includeInCoaching = false`
- `includeInCoverage = false`
- `includeInToolboxEligibility = false`

This preserves freedom without diluting the teaching system.

### Combos

Combos need clearer structure than the current model.

Add or redefine:

- `isBuiltFromTriads`: bool
- `voiceAssignments`: editable when practicing in flow
- `toolboxEligible`: bool

Sessions should carry:

- `practiceMode`: `singleSurface | flow`

### Sessions

Sessions should log:

- item ids
- family
- bpm
- click
- reflection
- lane
- optional `flowApplied`

### Progress / recommendation data

Add support for:

- last practiced by lane
- dynamic-variation exposure
- lead-balance aggregates
- phrase-length exposure
- flow/orchestration exposure
- toolbox eligibility and readiness

## First-Light / Onboarding Plan

### Principle

First-light should sound like a teacher introducing a disciplined practice method.

It should not sound like app-tour copy.

### Recommended first-light structure

#### Step 1. Purpose

Explain:

- short patterns become usable vocabulary
- this app teaches that step by step

#### Step 2. Method

Explain the teaching spine briefly:

- control
- balance
- dynamics
- phrasing
- flow

#### Step 3. Setup

Collect:

- handedness
- default BPM
- timer
- click

#### Step 4. First Assignment

Send the user into one simple first practice action, not into a generic home screen with no direction.

## Post-MVP Features to Design For Now

These features are not required for MVP, but the design should not block them.

### 1. Hear the pattern at different BPMs

Future capability:

- tap an item or phrase
- hear an example at chosen BPMs
- optionally hear plain vs accented/dynamic versions

Design implication now:

- phrases need a clean internal note/token representation
- dynamic markings need to be machine-readable
- combos need ordered playback-ready structure

### 2. Flow mode with animated kit graphic

Future capability:

- choose a kit graphic from several layouts
- show voice assignment
- animate the pattern on the kit
- hear how the phrase sounds while the animation plays

Design implication now:

- flow phrases need voice assignments as structured data
- do not bake display-only orchestration into text strings
- keep a future `kitLayout` / `surfaceMap` concept possible

## Execution Sequence

### Phase 1. Product alignment

1. rewrite Today around lane-based recommendations
2. rewrite first-light in teacher voice
3. rename/reposition Toolkit as Focus / Working On
4. separate Focus vs Toolbox vs Custom bucket in the product model
5. introduce phrase practice mode: `singleSurface | flow`
6. add note-level voice assignment editing for flow

### Phase 2. Coaching clarity

1. update Progress to reflect lane logic
2. show why items are recommended
3. add clearer balance/dynamics/phrase coverage analysis
4. remove or downgrade passive list-like views

### Phase 3. Flow foundation

1. add flow-ready phrase structure
2. add optional voice assignment model
3. add flow-specific practice sessions
4. prepare for playback and kit animation

### Phase 4. Expansion

1. 5-note grouping curriculum
2. optional rudiment mapping
3. later embellishment families such as flams

## Immediate Build Plan

This is the recommended next implementation sequence.

1. update docs and naming in the app shell:
   `Toolkit` -> `Focus`
2. redesign `Today` around teaching lanes and evidence-based recommendations
3. rewrite onboarding / first-light in teacher voice
4. separate custom patterns from coached/tracked core material
5. add phrase practice mode:
   `singleSurface` vs `flow`
6. add note-level voice assignment editing for flow
6. adjust Work and Progress to reflect that distinction

## Open Decisions

These are the remaining decisions likely needed before implementation starts.

1. Should `Toolbox` be visible in MVP, or should it remain an internal milestone concept until the mastery logic is stronger?
   Recommendation: keep it visible lightly in Progress first, not as a full main screen.

2. Should `Flow` appear as a visible lane in MVP even before full kit animation/playback exists?
   Recommendation: yes, but scoped to voice-ready phrases and planning, not full audiovisual playback.

3. Should custom patterns be practiceable directly from Work, or live only in a separate Library bucket?
   Recommendation: practiceable directly, but excluded from coaching and core progress logic.
