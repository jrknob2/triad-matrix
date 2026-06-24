# 10 - Notation Grouping And Warmups

## Status

This document is superseded for notation-language rules.

The single source of truth for Drumcabulary notation is:

- `docs/18_NOTATION_LANGUAGE_CONTRACT.md`

Do not add notation grammar, token, grouping, subdivision, voice, or duration
rules here. Update the notation language contract first, then update
implementation and tests.

## Historical Note

This file previously mixed two concerns:

- notation grouping syntax
- older warmup/practice product direction

That made the notation language harder to reason about because multiple files
appeared to define overlapping rules. The active lesson-plan MVP does not use
the old warmup/product lane as a notation authority.

Any future warmup or rudiment work should reference
`docs/18_NOTATION_LANGUAGE_CONTRACT.md` for notation behavior and define only
product-specific flow rules in its own screen or feature contract.
