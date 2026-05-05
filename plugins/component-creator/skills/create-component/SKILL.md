---
name: create-component
description: "Create a new frontend component following the project's detected conventions. Use when the user asks to 'create a component', 'add a new component', 'generate a component', or 'scaffold a component'. Requires docs-creator /analyze-frontend to have been run first — reads reference-component-creation-template.md and frontend-analysis.json from the target project's .claude/ directory."
scope: api
argument-hint: "<component-name> [figma-url]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Create Component

> **Execution flow:** `sequences/create-component.mmd` — source of truth for all steps and branches
> **Workflow rules:** `rules/component-creation-workflow.md` — preconditions, EC table, Tool Failure Pattern
> **Output format:** `rules/component-output-format.md` — naming, file layout, registry schema, checklist

## Usage

```text
/create-component ButtonPrimary
/create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
```

## Execution

**First — show the full plan.** Call TodoWrite with all items as `pending` before doing any work:

```
☐ Step 0   — Pre-flight (docs + Figma token + variant check)
☐ Phase 1  — Context: Figma design + Reuse check + Token/typography sync
☐ Phase 1.5 — Decompose (if composite component)
☐ Phase 2A — Download assets (SVG icons)
☐ Phase 2B — Generate code (CSS + JS + preview + @import)
☐ Phase 3  — Visual verify (adapter)
☐ Phase 4  — Registry upsert
☐ Phase 5  — Code Connect
```

Mark each item `in_progress` before starting, `completed` immediately after finishing.

**Then — follow `sequences/create-component.mmd` exactly.**

## What to Read and When

| File | Read at | Purpose |
| ---- | ---- | ---- |
| `reference-component-creation-template.md` | Step 0 | **Primary** code pattern — file structure, conventions, examples |
| `frontend-analysis.json` | Step 0 | `naming_conventions`, `styling_system` |
| `frontend-design-system.md` | Step 0 | `token_file`, `typography_file` paths |
| `component-registry.json` | Phase 1 Agent 2 | Reuse check only |
| Existing component files | **Phase 5 only** | Code Connect format discovery from primitive |

**Never read an existing component as a code generation reference.** Existing components may have workarounds, outdated patterns, or project-specific quirks. `reference-component-creation-template.md` is the canonical source for how new components should be written.

## Adapter Hooks

Generic skill calls these hooks — adapter SKILL.md implements them:

| Hook | Generic fallback | Adapter |
| ---- | ---- | ---- |
| `adapter.generate()` | apply `rules/component-output-format.md` directly | e.g. `sciter-create-component` |
| `adapter.visual_verify()` | skip — log `[SKIP]` | e.g. `sciter-create-component` |
| `adapter.cc_publish()` | `figma connect publish` | adapter may override |
| `adapter.fetch_svg(nodeId)` | `fetch-figma-svg.sh` | adapter may override |

## EC13 — Inline Primitive Onboarding

Triggered when Phase 5 finds no `*.figma.ts` / `*.figma.js` in the project.

Show:
> "No Code Connect pattern found yet — one-time setup needed.
> Pick a **simple primitive** without child components (Button, Icon, Badge).
> Paste its Figma URL (component set ◆◆, not a variant ◆):"

Run inline creation flow for that primitive (Phases 1–4 + CC format setup), then resume original component from Phase 5 step 2.
