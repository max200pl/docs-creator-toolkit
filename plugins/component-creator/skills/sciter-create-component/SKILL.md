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
[component-creator v0.0.14 | sciter-create-component]
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

**0.7 Node type detection** — Read `docs/reference-figma-nodes.md` (full type table + classification logic).

Call `mcp__figma__get_code_connect_suggestions(nodeId, fileKey)` → get `mainComponentNodeId`.

**Classification:**

| Condition | Node type | Action |
| ---- | ---- | ---- |
| `mainComponentNodeId == nodeId` | `COMPONENT_SET` or standalone `COMPONENT` | ✅ Proceed to Phase 0.5 |
| `mainComponentNodeId != nodeId` AND node is a `COMPONENT` whose parent is `COMPONENT_SET` | Variant (◆ inside ◆◆) | 🔄 Redirect: use `mainComponentNodeId` as new nodeId |
| `mainComponentNodeId != nodeId` AND node type is `INSTANCE` | Instance placed on canvas | ⬆ Drill: follow `componentId` → find source `COMPONENT` → check if parent is `COMPONENT_SET` → use set if exists |
| node type is `FRAME` / `GROUP` / `VECTOR` / `TEXT` / other | Not a component | ❌ Stop |

**Redirect message (variant case):**
> "Node `<nodeId>` is a **variant** (◆), not a component set (◆◆).
> Correct node: `<mainComponentNodeId>` — use this URL:
> `https://www.figma.com/design/<fileKey>?node-id=<mainComponentNodeId>`"

**Stop message (non-component):**
> "This is a `<type>` node, not a component. Select a component (◆) or component set (◆◆) in Figma."

After redirect or drill — re-run Step 0.7 with the resolved nodeId.

---

### Phase 0.5 — Variant Analysis and Plan (MANDATORY — do not start Phase 1 without user confirmation)

1. `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` → full structure: variant combinations, each variant's own nodeId, **all child component instances** (nested components)
2. Record each default-state variant's nodeId for SSIM
3. **Detect ALL child component instances** — follow `docs/reference-component-decompose.md` § Child Component Detection:
   - 3a. Parse `get_design_context(disableCodeConnect: true)` for COMPONENT/INSTANCE children
   - 3b. If not visible → `get_metadata(nodeId)` → children array → `get_design_context` per child
   - 3c. Recurse N levels deep until full tree
   - 3d. Classify: real component / asset set / layout-only
   - 3e. Registry check per component: ✅ reuse | ❌ build first
   - 3f. States drive asset variants (`<icon>-<state>.svg`)
   - 3g. Show build order bottom-up in plan
4. For each variant: note what differs (colors, layout, states)
4. **Derive component name from Figma layer name** → convert to PascalCase → **always show to user and ask to confirm or correct:**
   > "Component name derived from Figma: `<Name>` — confirm or enter correct name:"
   Do NOT proceed with the name silently. Figma layer names may contain typos.
5. **Asset set detection** — before treating as a component, check if all variants are pure image/icon nodes with no layout or behavior (see `docs/reference-component-decompose.md` § Asset Set Detection):
   - If asset set → do NOT create a component directory; download icons to parent's `img/`; stop here
   - If real component → continue
6. Check registry for component name or `figma_node_id` — check **`.claude/state/component-registry.json`** only, NOT markdown files
7. **Detect sub-component placement** — check registry for a parent whose name is a prefix of this component name (see `docs/reference-component-decompose.md` § Sub-Component Detection).
   Show both options in plan: (a) top-level or (b) sub-component inside parent `ui/`. User confirms.
7. **Detect layer** — read `## Component Placement Rules` from `reference-component-creation-template.md` (already loaded in Step 0.2). Use the rule that matches this component. If section absent → ask user.
   Show in plan: `Layer: <path>  (from Component Placement Rules)`
6. Show plan — use format from `docs/reference-component-plan.md`.

Confirm variant selection →

6. **Wait for explicit user confirmation before Phase 1.**

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

Read `docs/reference-component-decompose.md` § Icon Naming Algorithm before naming icon files.

**Always try SVG first.** Never plan PNG download upfront — PNG is fallback only.

For each icon variant detected in Phase 0.5:

```bash
# Step 1 — always try SVG
tools/fetch-figma-svg.sh <fileKey> <iconNodeId> <layer>/img/<icon>.svg
```

**Only if `fetch-figma-svg.sh` returns 404 (asset URL expired):**
```bash
# Step 2 — fallback to PNG screenshot
mcp__figma__get_screenshot(nodeId: <iconNodeId>, fileKey)
# Save as <layer>/img/<icon>.png
# Update JS: __DIR__ + "img/<icon>.png"
```

In Phase 0.5 plan — always list icons as `.svg`. Change to `.png` only after actual 404.

---

## Phase 2B — Generate Sciter CSS + JS + preview + @import

Read `docs/reference-sciter-css.md` before writing any CSS.

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

Write to **`.claude/state/component-registry.json`** — the JSON file.

⛔ NEVER write to `.claude/docs/reference-component-registry.md` — that is a read-only generated markdown view, not the source of truth.

Follow `rules/registry-schema.md` strictly. Before writing, validate the new entry:
- All keys must be in the allowed list from `registry-schema.md`
- `path` must be the `.js` file, not a directory
- `figma_node_id` must be the **component set** nodeId (captured in Phase 0.5), not a variant nodeId
- `variants`: all implemented type names (e.g. `["sec", "prim", "with-icon"]`)
- `states`: Figma `state` axis values with distinct static designs (e.g. `["Default", "disable"]`) — exclude CSS-only interaction states (hover) that have no separate Figma frame; values vary per component
- `uses`: names of primitive components used by this component — match Figma child node IDs against `figma_node_id` entries in registry; `[]` if no primitives used
- `ssim_score`: minimum score across all parallel SSIM runs
- `status`: `"in-progress"` at Phase 4; updated to `"done"` after Phase 5

If any field violates the schema → stop and show `REGISTRY SCHEMA VIOLATION: <field>` before writing.

## Agent Memory

Seed templates: `docs/reference-sciter-agent-memory.md`.
Seed on first run if `.claude/agent-memory/sciter-create-component/` is empty.

## Phase 5 — Code Connect (Sciter specifics)

- Use **`.figma.ts`** extension, NOT `.figma.js` — CLI transpiles `.ts → .js`; `.figma.js` is sent raw and `import` breaks in Figma runtime
- Project must NOT have `"type": "module"` in `package.json` — breaks CLI transpilation
- Always call `get_code_connect_map(nodeId, fileKey)` BEFORE generating — if mapping exists, show old→new diff and ask user to replace or keep

## EC13 — Inline Primitive Onboarding (Sciter)

Same as `create-component` EC13 but inline creation uses Sciter rules + SSIM verify.

Show:
> "No Code Connect pattern found yet — one-time setup needed.
> Pick a **simple Sciter primitive** without child components (Button, Icon, Badge).
> Paste its Figma URL (component set ◆◆, not a variant ◆):"
