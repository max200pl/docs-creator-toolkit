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
> **Registry schema:** `rules/registry-schema.md` — strict field allowlist; validate before every Phase 4 write

## Usage

```text
/create-component ButtonPrimary
/create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
```

## Execution

### Step 0 — Pre-flight (MANDATORY — do not skip any sub-step)

**0.1 TodoWrite** — call FIRST, before any reads or Figma calls:
```
☐ Step 0    — Pre-flight
☐ Phase 0.5 — Variant analysis + plan (user confirms)
☐ Phase 1   — Context: Figma + Reuse + Token/typography sync
☐ Phase 1.5 — Decompose (if composite)
☐ Phase 2A  — Download assets
☐ Phase 2B  — Generate code
☐ Phase 3   — Visual verify
☐ Phase 4   — Registry upsert
☐ Phase 5   — Code Connect
```

**0.2 Read docs** (parallel): `reference-component-creation-template.md`, `component-registry.json`, `frontend-analysis.json`, `frontend-design-system.md`.

**0.3 Figma token** — `mcp__figma__whoami`. On 401 → stop (EC5).

**0.4 Parse URL** — extract `fileKey` + `nodeId` (convert `-` → `:` in node-id).

**0.5 EC2 check** — if directory `<name>/` exists (even empty) and no registry entry → prompt: overwrite / register as-is / cancel.

**0.6 Variant hard-block** ⚠️ — call `mcp__figma__get_code_connect_suggestions(nodeId, fileKey)`:
- If `mainComponentNodeId ≠ nodeId` → **STOP. Do NOT continue**:
  > "Provided node is a **variant** (◆), not a component set (◆◆).
  > Right-click the parent component set in Figma → Copy link to selection. Paste new URL:"
- Wait for user. Re-parse. Repeat until `mainComponentNodeId == nodeId`.

---

### Phase 0.5 — Variant Analysis and Plan (MANDATORY — do not start Phase 1 without user confirmation)

1. `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` → all variant combinations
2. Check registry for component name or `figma_node_id`
3. Show plan with checkboxes, wait for explicit user confirmation before Phase 1.

---

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
