# 13 - Communication Style Contract

## Purpose

This document defines how Drumcabulary talks to the student.

It exists to stop copy drift.

The app should not sound like:

- product marketing
- UX filler
- internal framework language
- soft motivational fluff
- generic self-improvement copy

It should sound like a serious drum teacher giving clear direction.

This contract is based on the writing qualities in the triad training guide that inspired the product.

---

## Core Principle

The app speaks in two distinct modes:

1. UI voice
2. teaching voice

These must not be blended casually.

### UI Voice

Use UI voice for:

- navigation
- buttons
- labels
- list rows
- settings
- filters
- metrics

UI voice should be:

- short
- plain
- obvious
- low-drama
- non-explanatory

Examples:

- `Open Matrix`
- `Start Practice`
- `Needs Work`
- `End Session`
- `Right Lead`

### Teaching Voice

Use teaching voice for:

- Coach body copy
- Practice Item guidance
- session-end direction
- short context text where the app is instructing musical work

Teaching voice should be:

- direct
- concrete
- compressed
- teacherly
- drummer-native
- procedural

It should sound like instruction, not narration.

---

## Source Style Characteristics

The reference writing that inspired Drumcabulary has these qualities:

- It is authoritative without hype.
- It uses domain terms naturally.
- It explains through rules, examples, and exercises.
- It assumes the student is capable of following precise instruction.
- It prefers concrete action over abstract explanation.
- It keeps emotional tone restrained.
- It repeats core practice principles in simple language.

This is the target.

---

## Voice Rules

### The app should sound like:

- a drum teacher
- a practice handout
- a short rehearsal note
- a set of exercise rules

### The app should not sound like:

- a dashboard explaining itself
- a product walking the user through screens
- a system narrating its own logic
- a lifestyle app trying to inspire the user

---

## Terminology Rules

Prefer terms like:

- triad
- phrase
- sticking
- kick
- accent
- ghost note
- voice
- flow
- lead
- evenness
- clean
- smooth
- relaxed
- repeat
- around the kit

Avoid terms like:

- baseline
- signal
- status language
- active work
- source material
- this screen
- this view shows
- jump straight into
- bring into the day
- settle in
- next unlock

Use drummer-facing words before framework words.

If a teaching-model concept exists internally, translate it before it reaches the user.

---

## Sentence Style

Prefer:

- short declarative sentences
- imperatives
- rule statements
- cause-and-effect statements

Good patterns:

- `Keep the sound even.`
- `Start slower than you think you need to.`
- `Do not add kick until the hands stay clean.`
- `Move the accent. Keep the sticking the same.`

Avoid:

- layered abstract metaphors
- app-aware setup language
- filler transitions
- explanatory padding

Bad patterns:

- `Use this screen to...`
- `This helps you...`
- `The app will start to...`
- `This is the clearest next...`

---

## Teaching Guidance Rules

When the app teaches, it should prefer:

- rules
- examples
- constraints
- next-step instruction

More useful:

- `Repeat with no gap back to the beginning.`
- `Keep the sticking the same. Change only the voice.`
- `Evenness before speed.`

Less useful:

- `This should feel more natural over time.`
- `This is a good next step because...`

---

## Guidance Versus Authored Data

Important distinction:

- some drumming conventions are good teaching guidance
- they are not necessarily stored defaults

Example:

- accenting the single stroke in a triad
- ghosting the double stroke

These are common instructional defaults and useful teaching guidance.

They do **not** automatically mean:

- the app should store accents by default
- the app should store ghost notes by default
- the app should silently author those markings for the student

Contract:

- accents, ghosts, and flow voices remain user-authored data
- the app may teach common default approaches in copy
- the app may not silently convert teaching guidance into stored markup without an explicit product decision

---

## Screen-Level Communication Rules

### Coach

Coach may use teaching voice.

Coach should sound like:

- a teacher watching a rep
- noticing what is happening
- giving one experienced adjustment

Coach copy should:

- start from an observed practice problem or readiness signal
- tell the student what to do next
- name the concrete thing to notice or correct
- sound like advice, not a status label

Coach copy should not:

- explain ranking logic
- explain the screen
- sound like motivational filler
- expose internal card categories as the visible card identity

Coach card titles should read like coaching moves, not buckets.

Prefer visible card starters like:

- `Try this`
- `Think about`
- `Put more attention on`
- `Slow it down`
- `Speed it up now`
- `You are ready for`
- `Spend more time here`
- `Keep this going`
- `Clean this up`
- `Move this around the kit`

Avoid visible card labels like:

- `Focus`
- `Needs Work`
- `Momentum`
- `Next Unlock`

Preferred structure:

1. observation
2. instruction
3. reason if needed

Example shape:

- `Slow RLL down. The handoff is where it starts to rush.`
- `You are ready for flow on RLR. Keep the sticking the same and move the voices.`
- `Spend more time on LRR. It is close, but the loop still has a gap in it.`

### Matrix

Matrix should mostly use UI voice.

Matrix context text, when present, should be:

- short
- concrete
- about the current slice

Matrix should not teach at length.

### Practice

Practice should use UI voice.

It should present launch choices clearly and with minimal prose.

### Practice Session

Practice Session should use almost no prose.

Only essential transport labels and status cues belong here.

### Practice Item

Practice Item may use short teaching voice.

It should focus on:

- how to approach this item
- what to listen for
- what to keep constant

### Session Summary

Session Summary should use short teaching voice.

It should sound like rep-to-rep direction, not assessment bureaucracy.

### Focus

Focus should use UI voice only.

### Progress

Progress should use measurement language only.

No teacher talk.
No coaching talk.
No internal explanation talk.

---

## Copy Acceptance Rules

A line of student-facing copy passes only if:

1. it matches the screen job
2. it uses the correct voice mode
3. it uses drummer-facing language where appropriate
4. it does not explain the app when it should direct practice
5. it does not duplicate information the UI already shows
6. it would not feel out of place in a teacher's handout

---

## Planned Rewrite Pass

The rewrite should happen in this order:

1. Coach
2. Practice
3. Practice Item
4. Session Summary
5. Matrix context text and labels
6. Focus and Progress cleanup

### Pass Goals

#### Pass 1: Coach

- remove remaining framework phrasing
- rewrite all card titles, bodies, and CTA labels against teacher voice
- keep cards sparse

#### Pass 2: Practice

- remove explanatory filler
- make launch choices read like direct actions

#### Pass 3: Practice Item

- replace generic item guidance with short teacher-style instruction
- allow common teaching defaults to be explained as guidance without storing them as authored markup

#### Pass 4: Session Summary

- rewrite the check and recommendation text
- make it sound like a teacher directing the next rep

#### Pass 5: Matrix

- tighten labels and context text
- keep Matrix concrete and structural

#### Pass 6: Final Sweep

- remove stray product-y phrases
- ensure each screen stays inside its communication mode

---

## Definition Of Done

This pass is done when:

- Coach sounds like instruction, not a system
- Practice does not explain itself
- Session Summary sounds like rep guidance
- Matrix labels are concrete
- Focus and Progress do not borrow teacher language
- the app sounds like one product written by one mind
