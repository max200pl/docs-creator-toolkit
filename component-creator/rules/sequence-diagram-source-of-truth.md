---
description: "Sequence diagrams are the source of truth for skill execution order. SKILL.md describes intent; .mmd dictates what happens and when. Never change execution logic without updating the diagram first."
---

# Sequence Diagram — Source of Truth

## Rule

**`.mmd` files are the source of truth for execution order.** When they conflict with SKILL.md, the `.mmd` wins.

```
sequences/create-component.mmd          → generic orchestrator flow
sequences/sciter-create-component.mmd   → Sciter adapter delta only
```

## Mandatory Order of Changes

When adding or modifying execution logic:

```
1. Update .mmd first          ← design the change visually
2. Review the diagram         ← does the flow make sense?
3. Update SKILL.md to match   ← prose description follows the diagram
4. Update rules/*.md if needed ← EC table, preconditions, etc.
```

**Never write SKILL.md prose first and update the diagram later.** Prose drifts; diagrams don't.

## What Goes in Each File

| File | Contains | Does NOT contain |
| ---- | ---- | ---- |
| `create-component.mmd` | full generic flow — all phases, all ECs, all branches | Sciter-specific tooling (SSIM, dip, preview-component.sh) |
| `sciter-create-component.mmd` | Sciter-only delta — only what overrides or extends generic | Repetition of generic phases |
| `SKILL.md` | prose explanation of each step, argument examples | Execution order decisions (those live in .mmd) |
| `rules/*.md` | EC table, preconditions, output format, Tool Failure Pattern | Flow diagrams or execution order |

## Delta Diagram Contract

`sciter-create-component.mmd` shows ONLY Sciter additions. Every node must satisfy:

> "Would this node exist in a non-Sciter adapter?" → if yes, it does NOT belong here.

If a delta diagram contains a node that belongs in the generic diagram → move it.

## Staleness Check

Before closing any checkpoint, verify:

```
For each phase change in SKILL.md:
  → Is it represented in the .mmd?
  → Does the .mmd node match the SKILL.md description?

For each new EC added to rules/component-creation-workflow.md:
  → Is the EC branch visible in create-component.mmd?
```

If any answer is "no" → update the diagram before marking the checkpoint done.

## Enforcement

`/sleep` (toolkit internal) checks `.mmd` files exist for every skill with an `## Execution` section in its SKILL.md. Missing diagram = lint warning.
