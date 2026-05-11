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

## One Doc Per Step

Each phase or step has its **own dedicated reference doc**. A doc covers exactly one step's rules — never shared between steps.

| Step | Doc |
| ---- | ---- |
| Step 0.7 — node classification | `docs/reference-figma-nodes.md` |
| Phase 0.5 — child detection + build plan | `docs/reference-component-decompose.md` |
| Phase 1 — token sync | `docs/reference-token-sync.md` |
| Phase 2A — icon download | `docs/reference-component-decompose.md` § Icon Naming |
| Phase 2B — CSS/JS generation | `docs/reference-sciter-css.md` |
| Phase 3 — SSIM + preview | `docs/reference-component-build.md` |
| Phase 0.3 — agent memory | `docs/reference-sciter-agent-memory.md` |

If a step has no doc yet → create one before adding detail to SKILL.md.

## Pattern

Sub-steps are listed in SKILL.md — the plan is the executable checklist.
Each sub-step that has non-trivial detail references its own doc.

```
## Phase N — <Name>

1. <sub-step A> — `docs/reference-<substep-a>.md`
2. <sub-step B> — `docs/reference-<substep-b>.md`
3. <sub-step C> — <one sentence if trivial, no doc needed>
```

Sub-step detail (algorithm, fallbacks, edge cases, code examples) → in the sub-step's own doc.
If a sub-step needs more than one sentence in SKILL.md → it needs its own doc.

## Why

The LLM reads SKILL.md on every invocation. Bloated skills increase context load and reduce instruction precision. Reference docs are read only when the relevant step is reached — just-in-time loading keeps context lean.

## Enforcement

Before adding more than 5 lines to any phase in SKILL.md — ask: "Does this belong in a reference doc?"
