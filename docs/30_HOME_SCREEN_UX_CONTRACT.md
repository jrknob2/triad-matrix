# 30_HOME_SCREEN_UX_CONTRACT.md

**Version:** 1.0  
**Status:** Draft (Approved for Implementation)  
**Last Updated:** July 2026

---

# Purpose

The Home screen is Drumcabulary's launchpad.

It answers one question:

> **"What should I do next?"**

Its purpose is to get the drummer practicing again with as little friction as possible.

The Home screen is **not**:

- a dashboard
- a lesson browser
- an analytics page
- a hardware configuration screen
- an Explore page

Those have their own destinations.

---

# Product Philosophy

The Home screen should feel like walking into your practice room.

Your kit is ready.

Your work is waiting.

Everything encourages you to pick up your sticks and continue.

The Home screen is operational.

It is **not reflective**.

Reflection belongs in **Insights**.

Discovery belongs in **Explore**.

---

# User Questions

The Home screen should answer these questions in order.

1. What was I working on?
2. Can I immediately continue?
3. Am I staying consistent?
4. What comes after this?
5. What have I accomplished recently?
6. Are my practice devices connected?

Nothing else.

---

# Information Hierarchy

Top to bottom.

1. Greeting
2. Device Status
3. Keep Practicing This
4. Progress
5. Up Next

No additional sections should compete with these.

---

# Navigation

Primary navigation:

- Home
- Explore
- Insights
- Author
- Settings

Hardware is **not** primary navigation.

---

# Devices

The current MIDI device and LED controller status are always visible in the header.

Examples:

🟢 Roland TD-17 Connected

🟢 LED Controller Connected

If disconnected:

🟡 Roland TD-17 Not Connected

The MIDI and LED status badges are interactive. Selecting either badge opens the
quick device connection modal.

Device management never occurs directly from Home.

---

# Section Responsibilities

---

## Shell Header Greeting

Purpose:

Provide context and readiness.

Example:

```
Good Evening Terry

Ready when you are.
```

The name comes from the persisted app profile. Until first-light capture and
Settings editing exist, the seeded profile name is Terry.

This greeting is rendered by the shared shell header, not inside the Home
scrolling body. The Home body begins with the first content card below that
header.

---

## Keep Practicing This

Primary action of the entire application.

This section owns **all information related to the current lesson**.

Nothing about the current lesson should appear elsewhere on Home.

Contents:

- lesson title
- exercise title
- exercise checklist
- completion indicators
- Resume button

Example:

```
Money Beat + Triplet Fills

Triplet Fill Alone

Exercise 2 of 3

Hi-Hat Only            ✓

Hi-Hat + Snare         ██████

Hi-Hat + Snare + Kick

1 of 3 complete

Resume
```

Button text:

**Resume**

NOT:

- Resume Practice
- Continue Practice

Section title:

**Keep Practicing This**

---

## Progress

Purpose:

Collect recent practice signals into one compact card.

The outer card title is:

**Progress**

The card has two subsections:

- **Progress Summary**
- **Recent Activity**

---

### Progress Summary

Purpose:

Provide a quick snapshot of consistency.

Not gamification.

Not analytics.

Three metrics only.

Current MVP:

- Day Streak
- Practice Time This Week
- Exercises Across Lessons

Examples:

```
17

Day Streak
```

```
3h 42m

This Week
```

```
7 Exercises

Across 3 Lessons
```

No XP.

No badges.

No levels.

No scores.

A link to:

**View My Insights**

appears in the upper-right of the Progress card when space allows. It should
use a restrained text-button treatment and must not compete with Resume.

---

### Recent Activity

Purpose:

Show recent concrete exercise activity.

Items describe actions.

Not lesson-open events.

Not simply lesson names.

Every item is scoped to an exercise and must include the parent lesson context.
The activity should not leave the user guessing where an exercise belongs.

Examples:

```
Completed

Add Ghost Notes
Six Stroke Roll

Today
```

```
Practiced

Groove First
Six Stroke Roll

Yesterday
```

```
Practiced

Hi-Hat Only
The Money Beat

2 days ago
```

---

## Up Next

Purpose:

Show the next lesson.

This section owns **future work only**.

It never shows progress.

It never shows exercise completion.

It never duplicates information from "Keep Practicing This."

Contents:

- lesson title
- one useful lesson label, usually primary Musical Vocabulary or Musical Context
- brief description (optional)
- Choose Something Else

Examples:

```
Rock Beat Basics

Lesson

Rock Grooves
```

Secondary action:

**Choose Something Else**

opens Explore.

---

# First-Light Experience

If no practice history exists:

Replace:

Keep Practicing This

with

```
Welcome to Drumcabulary

Turn what you learn into focused practice.

Explore Lessons

Record Exercise
```

Do not display:

- zero streaks
- empty charts
- blank recent activity
- meaningless placeholders

Every empty state should encourage the first practice session.

---

# Visual Language

Theme:

Dark

Accent:

Burnt Orange (user configurable in the future)

Typography:

Modern

Confident

Readable

Avoid excessive font weight.

Large whitespace.

Rounded cards.

Premium feel.

The application should resemble a professional music application rather than a business dashboard.

---

# Design Principles

## One Screen

One Purpose.

---

## One Section

One Responsibility.

No duplicated information.

---

## Operational

Not Reflective.

Reflection belongs in Insights.

---

## Music Before Technology.

Hardware supports practice.

It is not the focus.

---

## Deterministic

Not AI-driven.

The application should avoid pretending to coach.

Instead it should expose clear information and let the drummer decide.

---

## Continue First.

Resume should dominate the page.

Everything else is secondary.

---

# Out of Scope

The Home screen does not contain:

- Practice Insights
- Radar charts
- Capability visualization
- Lesson browsing
- Search
- Filters
- Analytics dashboards
- Device configuration
- Authoring
- Notifications
- Coaching
- Recommendations
- AI-generated suggestions

---

# Future Enhancements

These intentionally belong elsewhere.

Insights

- Practice Map
- Radar visualization
- Growth Highlights
- Milestones
- Historical trends
- Capability drill-down

Explore

- Metadata filters
- Search
- Favorites

Devices

- MIDI configuration
- LED controller configuration
- Diagnostics
- Firmware

Author

- Exercise editor
- Lesson editor
- MIDI capture
- Pattern library

---

# Success Criteria

A returning drummer should be able to:

- understand where they left off
- resume in one click
- verify hardware is connected
- see their recent consistency
- choose another lesson if desired

...all within approximately ten seconds.

If the user accomplishes those tasks quickly and without confusion, the Home screen has succeeded.
