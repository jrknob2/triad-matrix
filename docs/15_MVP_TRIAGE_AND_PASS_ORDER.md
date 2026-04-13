# 15 — MVP Triage And Pass Order

## Purpose

This document sorts current product notes into:

- `Consider Now`
- `Decision Needed Soon`
- `Post-MVP`

It exists to stop feature churn and keep pass selection aligned to the current v1 product.

Use this document when deciding what to work on next.

---

## Triage Rules

An item belongs in `Consider Now` when it affects at least one of these:

- trust
- core practice usability
- screen/flow clarity
- core player behavior
- MVP identity

An item belongs in `Decision Needed Soon` when the implementation can wait, but the product model needs to be settled now because it affects current contracts.

An item belongs in `Post-MVP` when it expands scope, introduces major new systems, or is valuable but not required to make the current product coherent.

---

## Consider Now

### 1. iPad responsive UI

Status:

- deferred from MVP

Initial thought:

- use a distinct iPad shell
- prefer split panes and side navigation
- allow an immersive fullscreen player on iPad only
- keep the phone flow unchanged

### 2. Coach should feel more like a progress summary

Why now:

- Coach is one of the app's identity surfaces
- current overly specific drill language does not land reliably
- this is a communication and product-model issue, not just a wording tweak

Initial thought:

- Coach should lead with a higher-level progress-aware summary
- it should include one concrete next action, but should not feel like a stack of direct commands
- recommendations should be grounded in known practice principles:
  - consistency
  - revisit frequency
  - focused repetition
  - stability before expansion

### 3. Curated phrase growth vs fully free-built combos

Why now:

- this affects what Matrix and phrase-building are ultimately for
- it changes how the app should think about musicality vs raw building-block training

Initial thought:

- v1 can continue allowing free phrase building
- but the product should explicitly reserve room for a curated phrase track later
- free-built phrases and curated musical phrases should not be treated as the same learning object forever

### 4. Strong/mastered items and maintenance

Why now:

- this affects the meaning of `Working On`
- it also affects Coach and Progress contracts

Initial thought:

- `Working On` and `Maintain` are separate ideas in v1
- not every strong item still belongs in active work
- the product should support refresh/revisit logic for retained skills

### 5. `Session Setup` should become `Practice Settings`

Why now:

- this is a naming and ownership cleanup on a core editing surface
- the current label is less clear than the behavior it owns

Initial thought:

- use `Practice Settings` in `Practice Item`
- keep per-pattern defaults there rather than scattering them across list flows

### 6. `Save Phrase` meaning is unclear

Why now:

- unclear CTA meaning on a core creation flow is an MVP problem
- if the user cannot tell what is being saved, the flow is not finished

Initial thought:

- rename it to the actual object/result
- likely candidates:
  - `Save to Working On`
  - `Save Practice Item`
  - `Save Phrase Item`

### 7. Player timer completion behavior

Why now:

- duration is core session behavior
- the player needs a defined end-of-timer contract

Initial thought:

- when timer reaches target, switch to a clear completed visual state
- do not silently stop the session unless a stricter timed-drill mode is added later

### 8. Player reset / start over

Why now:

- this is basic transport behavior
- users need a fast way to restart a rep without ending the session

Initial thought:

- add a clear reset/start-over action
- keep it distinct from ending the session

### 9. Player control density and surface design

Why now:

- the player owns a large amount of the app's active-use time
- available space is not being used as intentionally as it should be

Initial thought:

- make the player feel more like an instrument/device surface
- bring important controls into the main play surface when space allows

### 10. Player control labels

Why now:

- these are core controls
- ambiguity here weakens the whole practice loop

Initial thought:

- define clearer transport-state labels
- default transport state uses `Play` and `End`
- running transport state uses `Pause` and `Reset`
- define these as paired states, not isolated labels

### 11. High-BPM timing jitter and click/pulse sync

Why now:

- this is a real practice-quality issue
- if the player becomes unreliable at higher BPMs, it undermines trust in the tool

Initial thought:

- profile the current timing path
- simplify any UI-coupled update paths that interfere with timing
- keep the timing path naive and stable if needed

### 12. Monospaced notation in the player

Why now:

- notation stability is part of the core reading experience
- this directly affects perceived quality during active practice

Initial thought:

- use monospaced notation for the player readout
- avoid uneven wrapping caused by proportional glyph widths

### 13. Assessment should detect BPM changes and offer save

Why now:

- this matches the explicit-save model already established elsewhere
- it gives a clear place to update remembered per-item BPM defaults

Initial thought:

- detect whether session-end BPM differs from the item's saved practice default
- if it does, offer `Save BPM` in assessment

---

## Decision Needed Soon

### 1. Is iPad part of MVP?

Decision:

- no
- it is a post-MVP platform extension

### 2. Should Coach be summary-first, action-first, or hybrid?

This needs a contract decision before the next Coach rewrite pass.

Decision:

- summary-first with one concrete next action underneath

### 3. Should `Working On` and `Maintain` be separate buckets in v1?

This needs a product decision soon because it changes:

- Focus
- Coach
- Progress

Decision:

- yes
- the model should be defined now and implemented in the next product-model pass

### 4. Should curated musical phrases become a separate guided system?

This needs to be decided at the model level before phrase-building grows further.

Decision:

- yes, later
- keep free-building now
- reserve curated phrases as a later guided layer

---

## Post-MVP

### 1. iPad responsive UI

Initial thought:

- keep this as a later platform pass
- when it happens, it should be a real layout and flow redesign, not responsive patching

### 2. Pattern grammar root-model refactor

Initial thought:

- the current app treats triads as the root system
- long-term, triads should become one configured slice of a more general pattern grammar
- that grammar should support:
  - variable grouping sizes
  - a configurable symbol alphabet
  - rests as an additional symbol
  - regrouping and later rudiment overlays
- this is a domain-model refactor, not an MVP product-surface change
- v1 should continue presenting triads as the teaching system even if the underlying model is generalized later

### 3. Theme system

Includes:

- dark
- light
- auto
- extra themed variants

Initial thought:

- worthwhile, but not needed to prove the product

### 3. Novice / Pro mode

Initial thought:

- avoid this until the default UI is more self-explanatory
- this can become a crutch for unresolved clarity problems

### 4. Warmup auto-advance and random advance

Initial thought:

- useful, but not required for the core practice loop

### 5. Warmup interval logic tied to musical phrasing

Initial thought:

- too much complexity for current value

### 6. Listen mode / beat-accuracy detection

Initial thought:

- large technical scope
- environment-sensitive
- high false-confidence risk
- explicitly post-MVP

### 7. Groupings 3, 4, 5, 6

Initial thought:

- substantial domain expansion
- not needed for the current triad-focused MVP

### 8. Re-group existing patterns

Initial thought:

- powerful, but not required for current flow coherence

### 9. Rudiment map integration

Initial thought:

- strong future extension
- should come after the triad system is fully stable

### 10. Automatic accents, ghosts, and voices from musicality rules

Initial thought:

- valuable later
- must not undermine the current user-authored notation model without a deliberate redesign

---

## Recommended Next Pass Order

This is the recommended order for the next serious product passes.

1. `Player contract pass`
   Focus:
   - timer completion behavior
   - reset/start-over
   - control labels
   - monospaced notation
   - BPM-save handoff in assessment
   - high-BPM timing reliability

2. `Coach contract pass`
   Focus:
   - summary-first guidance
   - motivational tone grounded in real practice signals
   - one optional concrete next action

3. `Working On vs Maintain model pass`
   Focus:
   - define active work vs maintenance refresh
   - update Focus, Coach, and Progress contracts accordingly

4. `Phrase strategy pass`
   Focus:
   - free-built phrases vs curated musical phrases
   - define the long-term relationship without overbuilding it now

5. `iPad pass`
   Focus:
   - post-MVP only

---

## What This Document Is For

Use this document to stop random feature picking.

If a new note comes in:

1. place it in one of these buckets
2. decide whether it changes the current pass order
3. only then implement it
