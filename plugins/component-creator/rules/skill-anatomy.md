---
description: "SKILL.md anatomy rule — skills must be thin: plan + doc references only. No inline algorithm detail."
---

# Skill Anatomy — Keep SKILL.md Thin

## Rule

`sciter-create-component/SKILL.md` (and all adapter skills) must be **thin**.

A SKILL.md contains only:
1. **Version check** — one line banner
2. **TodoWrite** — task list with phase names
3. **Phase headers** — one line per phase with what to read and what to do
4. **References to docs** — `Read docs/reference-*.md` at the right step, not upfront
5. **Short decision rule** — one sentence per step max; details go in the doc

## What does NOT belong in SKILL.md

- Algorithm detail (loops, conditionals, fallback logic)
- Multi-step procedures with sub-bullets
- Code examples longer than 3 lines
- Tables with more than 5 rows
- Duplicated content from reference docs

If a section exceeds ~10 lines → extract to a `docs/reference-*.md` and replace with a one-line read instruction.

## Pattern

```
## Phase N — <Name>

Read `docs/reference-<topic>.md` before proceeding.

<one sentence describing what to do>
```

## Why

The LLM reads SKILL.md on every invocation. Bloated skills increase context load and reduce instruction precision. Reference docs are read only when the relevant step is reached — just-in-time loading keeps context lean.

## Enforcement

Before adding more than 5 lines to any phase in SKILL.md — ask: "Does this belong in a reference doc?"
