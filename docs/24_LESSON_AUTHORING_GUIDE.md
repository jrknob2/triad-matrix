# 24 - Lesson Authoring Guide

## Purpose

This document defines the standard process for creating new Drumcabulary lessons.

It bridges the gap between the educational philosophy and the lesson YAML format.

Lesson and exercise metadata categories are defined by:

- `docs/29_LESSON_METADATA_CONTRACT.md`

This document should be followed **before** writing YAML.

The goal is to ensure that every lesson teaches consistently, progresses naturally, and feels like it belongs in Drumcabulary.

---

# Authoring Workflow

Every lesson should be created using the following process.

```
Choose Curriculum Position

↓

Define Learning Objective

↓

Assign Lesson Metadata

↓

Choose Instructional Pattern

↓

Design Progressive Exercises

↓

Review Educational Flow

↓

Author YAML

↓

Review & Test
```

Authors should avoid writing notation or YAML until the lesson itself has been designed.

---

# Step 1 — Choose Curriculum Position

Determine where the lesson belongs.

Questions:

- Beginner, Intermediate, or Advanced?
- Which skill does it develop?
- What prerequisite knowledge is required?
- What lessons should naturally follow?

Example

```
Level

Beginner

Skill

Grooves

Lesson

Money Beat
```

---

# Step 2 — Define The Learning Objective

Every lesson should teach **one primary musical idea**.

Avoid combining unrelated concepts.

Good objectives:

- Learn the Money Beat
- Learn the Six Stroke Roll
- Develop Triplet Vocabulary
- Play a Basic Shuffle
- Build Hi-Hat Independence

Poor objectives:

- Learn grooves and fills
- Learn everything about triplets
- Become a better drummer

Objectives should be specific and achievable.

---

# Step 3 — Assign Lesson Metadata

Assign the metadata that lets students find and understand the lesson later.

Required lesson metadata:

- Identity
- Fundamentals
- Musical Vocabulary
- Difficulty

Common optional metadata:

- Musical Context
- Objectives
- Musical Environment
- Equipment
- BPM Recommendation

Rules:

- Fundamentals describe how the drummer develops, such as timing, dynamics, and
  coordination.
- Musical Vocabulary describes what the drummer learns to play, such as grooves,
  fills, rudiments, or linear playing.
- Musical Context describes where the vocabulary is commonly applied, such as
  rock, funk, jazz, or Latin.
- Difficulty describes the lesson, not the student.
- Objectives describe teaching intent and should not become the primary Explore
  filter set.
- Do not duplicate inherited exercise metadata unless an exercise adds or
  overrides something meaningful.
- Never store completion, favorite, last practiced, best BPM, or other user
  progress data in content metadata.

---

# Step 4 — Choose An Instructional Pattern

Select the instructional pattern that best matches the lesson.

Examples:

| Lesson | Instructional Pattern |
|---------|----------------------|
| Money Beat | Build Pattern |
| Six Stroke Roll | Rudiment Pattern |
| Triplet Vocabulary | Vocabulary Pattern |
| Basic Fill | Fill Pattern |
| Shuffle Groove | Groove Pattern |
| Independence | Independence Pattern |

The instructional pattern determines the overall teaching flow.

---

# Step 5 — Design Progressive Exercises

Exercises are the heart of every lesson.

Each exercise should introduce **one new challenge**.

Avoid combining multiple new concepts.

Example

Money Beat

Exercise 1

Hi-Hat only

↓

Exercise 2

Hi-Hat + Snare

↓

Exercise 3

Hi-Hat + Kick

↓

Exercise 4

Full Groove

↓

Exercise 5

Crash Resolution

Notice that every exercise builds naturally upon the previous one.

---

# Step 6 — Complete Each Exercise

Every exercise should answer four questions.

## Why

Explain the musical purpose.

Example:

"The hi-hat establishes the pulse before adding additional limbs."

---

## What

Describe exactly what the student should play.

Be concise.

Avoid unnecessary theory.

---

## How

Provide practical coaching.

Examples:

- Count aloud.
- Stay relaxed.
- Keep the hi-hat even.
- Let the sticks rebound naturally.
- Don't rush the fill.

This is where the instructor teaches.

---

## Practice

Define how the student practices.

Examples:

- suggested starting tempo
- target tempo
- notation
- hear it
- practice it

If an exercise differs from the lesson's metadata, add only the exercise-level
metadata needed for search, filtering, or Insights. Exercises inherit lesson
metadata by default.

---

# Step 7 — Musical Application

Whenever practical, every lesson should end with musical application.

Examples:

Money Beat

↓

Play four bars.

↓

Add a crash.

↓

Repeat.

---

Six Stroke Roll

↓

Play as a fill.

↓

Return to groove.

---

Triplet Vocabulary

↓

Insert every fourth measure.

↓

Return to groove.

Students should always understand how today's lesson becomes tomorrow's music.

---

# Step 8 — Tempo

Tempo exists to encourage success.

Default philosophy:

```
Correct

↓

Comfortable

↓

Consistent

↓

Faster
```

Never encourage speed before control.

Tempo should always support learning.

---

# Step 9 — Review

Before authoring YAML, ask:

- Does this lesson teach only one primary idea?
- Does every exercise build upon the previous one?
- Is each exercise introducing only one new challenge?
- Is there a musical application?
- Does the lesson include required metadata from the metadata contract?
- Does any exercise metadata add useful specificity without duplicating the
  lesson?
- Would a student naturally know what to do next?

If not, revise the lesson before writing notation.

---

# Writing YAML

Only after the educational design is complete should the lesson be translated into YAML.

YAML is an implementation detail.

The educational design should always exist independently of the file format.

---

# Review Checklist

Every completed lesson should satisfy the following.

## Educational

- [ ] One primary objective
- [ ] Appropriate curriculum level
- [ ] Appropriate curriculum skill or bucket
- [ ] Required lesson metadata is present
- [ ] Exercise metadata only adds useful specificity or overrides
- [ ] Clear prerequisites
- [ ] Progressive exercises
- [ ] Musical application

---

## Exercises

- [ ] Every exercise has a Why
- [ ] Every exercise has a What
- [ ] Every exercise has a How
- [ ] Every exercise introduces one new challenge
- [ ] Tempo progression makes sense

---

## Musical

- [ ] Notation reviewed
- [ ] Hear It reviewed
- [ ] Practice flow reviewed
- [ ] Return to groove is musical
- [ ] Dynamics and sticking are intentional

---

## Technical

- [ ] YAML validates
- [ ] IDs are unique
- [ ] Notation parses
- [ ] Audio preview works
- [ ] Lesson appears correctly in the curriculum

---

# Lesson Completion

A lesson is complete when:

- the educational flow feels natural
- the student can understand why they are learning each exercise
- every exercise prepares the student for the next one
- the lesson ends with musical application
- the lesson prepares the student for future lessons

If a lesson satisfies these principles, it is ready to become part of the Drumcabulary curriculum.

---

# Long-Term Vision

Drumcabulary lessons should feel like sitting down with an experienced drum instructor.

Students should never feel overwhelmed.

They should always know:

- what they are learning
- why it matters
- how to practice it
- what comes next

Every lesson should leave the student more confident than when they started.
