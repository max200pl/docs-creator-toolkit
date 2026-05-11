---
name: sciter-create-component
description: "Sciter.js adapter for create-component. Implements adapter.generate() with dip/flow/@mixin rules and adapter.visual_verify() with preview-component.sh + SSIM 0.95 gate. Invoke instead of /create-component on Sciter.js projects."
scope: api
argument-hint: "<component-name> [figma-url]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Sciter Create Component

> **Execution flow:** `sequences/sciter-create-component.mmd` (Sciter delta) + `sequences/create-component.mmd` (generic base)
> **Workflow rules:** `rules/component-creation-workflow.md`
> **Output format:** `rules/component-output-format.md` (Sciter CSS overrides below take precedence)
> **Registry schema:** `rules/registry-schema.md` — strict field allowlist; validate before every Phase 4 write

## Usage

```text
/sciter-create-component ButtonPrimary
/sciter-create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
```

## Execution

### ⚙ Version check — print before anything else

Output this line immediately when the skill starts, before any tool calls:
```
[component-creator v0.0.15 | sciter-create-component]
```

### Step 0 — Pre-flight (MANDATORY — do not skip any sub-step)

**0.1 TodoWrite** — call FIRST, before any reads or Figma calls:
```
☐ Step 0    — Pre-flight
☐ Phase 0.5 — Variant analysis + plan (user confirms)
☐ Phase 1   — Context: Figma + Reuse + Token/typography sync
☐ Phase 1.5 — Decompose (if composite)
☐ Phase 2A  — Download assets (SVG icons)
☐ Phase 2B  — Generate Sciter CSS + JS + preview + @import
☐ Phase 3   — Visual verify (SSIM)
☐ Phase 4   — Registry upsert
☐ Phase 5   — Code Connect
```

**0.2 Read docs** (parallel — only what's needed before Step 0.6):
- `reference-component-creation-template.md` — code conventions, layer placement
- `component-registry.json` — existing components (needed for EC2 check)
- `frontend-analysis.json` — extract `naming_conventions` + `styling_system`
- `frontend-design-system.md` — extract `token_file` + `typography_file`

**Do NOT read any existing component files (JS/CSS/figma.ts) or individual registry entries as templates or code patterns.** Use only:
- `reference-component-creation-template.md` → code conventions
- `rules/registry-schema.md` → registry entry format
- `rules/component-output-format.md` → naming, file layout
Existing components (ButtonFeedback, etc.) are read ONLY in Phase 5 to discover Code Connect format from the primitive's `.figma.ts` file.

**0.3 Agent memory** — Read `docs/reference-sciter-agent-memory.md` (seed templates). Check `.claude/agent-memory/sciter-create-component/`. If empty → seed from the templates.

**0.4 Figma token** — `mcp__figma__whoami`. On 401 → stop (EC5).

**0.5 Parse URL** — extract `fileKey` + `nodeId` from argument (convert `-` → `:` in node-id).

**0.6 EC2 check** — if directory `<name>/` exists (even empty) and no registry entry → prompt: overwrite / register as-is / cancel.

**0.7 Node type detection** — Read `docs/reference-figma-nodes.md`.

1. `get_code_connect_suggestions(nodeId, fileKey)` → `mainComponentNodeId`
2. Classify node type → proceed / redirect / drill / stop (see doc)
3. Re-run with resolved nodeId after redirect or drill

---

### Phase 0.5 — Variant Analysis and Plan (MANDATORY — do not start Phase 1 without user confirmation)

Read `docs/reference-component-decompose.md` § Child Component Detection + Asset Set Detection + Sub-Component Detection.
Read `docs/reference-component-plan.md` for plan display format.

1. `get_design_context(nodeId, fileKey, disableCodeConnect: true)` → full structure
2. Record default-state variant nodeIds for SSIM
3. Detect all child instances recursively — `docs/reference-component-decompose.md` § Child Component Detection
4. Derive name from Figma layer → always confirm with user (typo check)
5. Asset set detection — `docs/reference-component-decompose.md` § Asset Set Detection
6. Registry check by name or `figma_node_id`
7. Sub-component placement detection — `docs/reference-component-decompose.md` § Sub-Component Detection
8. Layer detection — `## Component Placement Rules` from `reference-component-creation-template.md`
9. Show plan — `docs/reference-component-plan.md`

**Wait for explicit user confirmation before Phase 1.**

---

## Execution — Build from plan

Follow `docs/reference-component-decompose.md` § Execution — Build from Plan.
Execute build order bottom-up: asset sets → dependencies → this component.

---

## Phase 1 — Context: Figma + Reuse + Token sync

Read `docs/reference-token-sync.md` before comparing tokens.

> Phase 1 runs parallel to Phase 0.5 confirmation wait — start token sync after showing plan.

## Phase 1.5 — Decompose (if composite)

Read `docs/reference-component-decompose.md` — decompose rules, child classification, build order, EC12.

## Phase 2A — Download SVG Assets

Read `docs/reference-component-decompose.md` § Phase 2A — SVG Download + § Icon Naming Algorithm.

1. Download each icon — SVG first, PNG fallback on 404
2. Name files per icon naming algorithm

---

## Phase 2B — Sciter Adapter Rules

Read `docs/reference-sciter-css.md` § Adapter Override Rules.

1. Generate CSS — follow adapter CSS rules (flow/dip/overflow/centering/display:block/pixel-perfect)
2. Generate JS — follow adapter JS rules (class extends Element / state-disabled / __DIR__ paths)
3. Write `<name>.preview.js` — full grid all types for Space overlay (NOT used for SSIM)
4. Add `@import` to main CSS entry file

(Sciter API reference: `docs/reference-sciter-links.md`)

### adapter.visual_verify() — SSIM (Phase 3)

Read `docs/reference-component-build.md` § Full SSIM Loop (Per-Type).

1. Resolve adaptive threshold from agent memory (0.92 SVG+border-radius | 0.95 default)
2. Execute per-type loop: Steps A–F from doc
3. On pass: save to ScreenshotHistory; on 3 failures: EC14 escalation

## Phase 4 — Registry (MANDATORY)

Read `rules/registry-schema.md` — strict field allowlist, validate before writing.

1. Write to `.claude/state/component-registry.json` (JSON only, never markdown)
2. Validate all fields against schema — stop on violation with `REGISTRY SCHEMA VIOLATION: <field>`
3. `status: "in-progress"` at Phase 4 → update to `"done"` after Phase 5

## Agent Memory

Seed templates: `docs/reference-sciter-agent-memory.md`.
Seed on first run if `.claude/agent-memory/sciter-create-component/` is empty.

## Phase 5 — Code Connect

Read `docs/reference-code-connect-sciter.md`.

1. Check existing mapping — `get_code_connect_map(nodeId, fileKey)` before generating
2. Generate `.figma.ts` (not `.figma.js`) following pattern from existing primitive
3. Publish — dry-run first; EC13 if no primitive found (see doc)
