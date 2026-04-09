# 01 — V1 Product Definition

## V1 Goal (Locked)

> Ship a focused drumming practice app that helps a player turn short patterns into usable musical vocabulary.

V1 is not trying to be a full drum curriculum. It is trying to make a specific kind of work clear, repeatable, and worth coming back to.

---

## Core Promise

Drumcabulary helps a drummer move from:

- isolated sticking
- to grouped patterns
- to repeatable phrases
- to musical application

The app should make that progression feel deliberate, not accidental.

---

## What V1 Must Do

V1 must support:

1. practicing triads as the core material system
2. building longer phrases from triads
3. practicing any phrase in either:
   - `Single Surface`
   - `Flow`
4. assigning kit voices in `Flow`
5. keeping a simple active working set
6. guiding the player from `Coach`
7. exposing the full triad system in `Matrix`
8. allowing direct entry into `Practice`
9. measuring development in `Progress`
10. supporting optional warmups without polluting coaching or progress

---

## Top-Level Product Model

V1 is organized around five main surfaces:

1. `Coach`
   - decides what matters now
   - gives the player a clear next step

2. `Matrix`
   - shows the triad system
   - supports filtering, analysis, and phrase building

3. `Practice`
   - gives the player a direct way to start playing
   - supports repeating the last session, practicing `Working On`, or warming up

4. `Focus`
   - holds the current working set
   - acts primarily as CRUD for active practice items

5. `Progress`
   - shows measurement, trends, and coverage
   - does not coach

---

## Practice Modes

V1 supports two practice modes:

### Single Surface

Purpose:

- control
- timing
- balance
- phrase retention

Characteristics:

- one surface for the hands
- no kit orchestration requirement
- direct repetition

### Flow

Purpose:

- voice assignment
- movement around the kit
- musical contour
- phrase application

Characteristics:

- note-level voice assignment
- same phrase as single-surface work
- kit application matters

Important rule:

The phrase is the material.  
The mode is how it is practiced.

---

## Warmup

Warmup is part of the practice experience, but it is not part of the coaching model.

Warmup in v1 should be:

- optional
- easy to start
- fixed and familiar
- untracked

Warmup should not:

- affect Coach
- affect Matrix progress coloring
- affect Progress metrics
- affect toolbox readiness

---

## What V1 Is Not

V1 is not:

- a general drum practice logger
- a favorites manager
- a notation editor
- a full rudiment system
- an exhaustive permutation explorer
- a lesson course with long text instruction

---

## Guardrails

1. `Coach` must never read like internal framework text.
2. `Progress` must never read like coaching copy.
3. `Focus` must not become a dashboard.
4. `Practice` must be reachable directly from the bottom navigation.
5. `Warmup` must remain optional and untracked.
6. `Matrix` must stay structural and interactive, not collapse into a passive heatmap.

---

## Success Criteria

V1 is successful if:

- a new user can open the app and know where to start
- a returning user can get into practice without hunting for the right entry point
- the active working set feels clean and manageable
- Coach feels useful, not generic
- Progress feels like measurement, not recycled guidance
- the app helps the player practice more, not configure more
