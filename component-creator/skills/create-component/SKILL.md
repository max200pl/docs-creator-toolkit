---
name: create-component
description: "Create a new frontend component following the project's detected conventions. Use when the user asks to 'create a component', 'add a new component', 'generate a component', or 'scaffold a component'. Requires docs-creator /analyze-frontend to have been run first — reads reference-component-creation-template.md and frontend-analysis.json from the target project's .claude/ directory."
scope: api
argument-hint: <component-name> [figma-url]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Create Component

> **Flow:** read `sequences/create-component.mmd` — source of truth for execution order
> **Workflow rules:** read `rules/component-creation-workflow.md` — preconditions, EC handling, Tool Failure Pattern
> **Output format:** read `rules/component-output-format.md` — naming, file layout, registry schema, checklist

## Usage

```text
/create-component ButtonPrimary
/create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
/create-component AsidePanel --adapter sciter
```

## Execution

Follow `sequences/create-component.mmd` exactly. Each phase below maps to the diagram.

### Step 0 — Pre-flight

```bash
START_TS=$(date +%s)
```

1. `TodoWrite` — init all task items as `pending`
2. Read preconditions (per `rules/component-creation-workflow.md` § Preconditions):
   - `.claude/docs/reference-component-creation-template.md`
   - `.claude/state/component-registry.json`
   - `.claude/state/frontend-analysis.json` → extract `naming_conventions` + `styling_system`
   - `token_file:` frontmatter in `.claude/rules/frontend-design-system.md`
3. Verify Figma token — call `mcp__figma__whoami`. On 401 → **EC5**: stop.
4. Parse `<figma-url>` argument if provided (convert `-` → `:` in node-id).
   If not provided → prompt user.

### Phase 1 — Context (3 parallel agents)

Invoke all three simultaneously:

**Agent 1 — Figma design:**
- `mcp__figma__get_design_context(nodeId, fileKey)` — layout, colors, typography reference
- `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` — full child structure, variant states, icon node list

**Agent 2 — Reuse check:**
- Load `component-registry.json`
- Apply Reuse Decision Tree (§ in `rules/component-creation-workflow.md`):
  - EXACT MATCH → report "Already exists" and stop
  - PARTIAL MATCH → show match, ask user: extend / refactor / create new
  - EC2 (files on disk, not in registry) → prompt user

**Agent 3 — Token sync:**
- Read `token_file` path from `frontend-design-system.md` frontmatter
- `mcp__figma__get_variable_defs(nodeId, fileKey)`
- Compare by hex-normalized value → produce: matched list + missing list

After all agents: surface EC3b (token name mismatch) and EC11 (no Figma tokens) if applicable. Wait for user confirmation before Phase 2.

### Phase 1.5 — Decompose (conditional)

Only if Agent 1 detected child component instances:

1. Build dependency tree — deepest children first
2. Classify each child by FSD layer (per `rules/component-output-format.md` § File Layout)
3. Build each child via Phase 2 before parent — do NOT auto-create primitives (flag + stop if missing)

### Phase 2 — Implement

**EC6** — if component name has special chars: apply `naming_conventions.component_file` rule, show converted name, user confirms.

Run parallel:

**Stream A — Download assets:**
- For each icon node from Phase 1: fetch SVG via adapter `fetch_svg(nodeId)` → write `img/<kebab-name>.svg`

**Stream B — Generate code:**
1. Add missing tokens to `token_file` (from Phase 1 Agent 3 result)
2. Call `adapter.generate(template, tokens, variants, layer, styling_system)` → component files
3. Write files to `<layer>/<slice-name>/` (per layout in `rules/component-output-format.md`)
4. Register `@import` in main CSS entry file
5. Run component-done checklist (§ in `rules/component-output-format.md`) — fix `[FAIL]` items before Phase 3

**EC4** — no icons: log note, continue.
**EC12** — child not in registry: create as `type: local` in `ui/`, non-blocking.
**EC7** — style wiring: read `styling_system.type` + `styling_system.import_syntax` from `frontend-analysis.json`.

### Phase 3 — Visual verify (adapter-specific)

Call `adapter.visual_verify(component, figma_ref)`. Adapter handles SSIM, screenshots, retries, escalation. Generic skill does not implement details.

### Phase 4 — Registry

Upsert entry per schema in `rules/component-output-format.md` § Registry Entry Schema.
Set `status: "in-progress"`. `figma_connected` stays `false` until Phase 5.

### Phase 5 — Code Connect

1. Scan project for primitive (`*.figma.ts`, `*.figma.js`, or equivalent)
   - **EC13** — not found: stop → "Run `/create-primitive` first to establish Code Connect pattern"
2. Read primitive → extract: format, template, publish command
3. `mcp__figma__get_code_connect_map(nodeId, fileKey)` — check existing mapping; prompt if found
4. Write `<name>.figma.{ext}` following primitive pattern
5. Run `cc_publish --dry-run` → validate → run `cc_publish`
6. Update registry: `figma_connected: true`, `last_figma_sync_at: <now>`, `status: "done"`

### Finish

```bash
END_TS=$(date +%s)
```

Mark all TodoWrite tasks `completed`. Report:

```text
✓ <name> — <layer>/<slice-name>/
  Files:   <name>.js, <name>.css, <name>.preview.js, <name>.figma.{ext}
  Icons:   N downloaded
  Tokens:  N matched, M added
  SSIM:    <score or "skipped">
  Registry: updated
  Code Connect: published / skipped
  Duration: <Ns>
```

## What This Skill Does NOT Do

- Implement adapter-specific tooling (SSIM, preview, dip units, `@mixin`) — that's the adapter's SKILL.md
- Create primitives inline — run `/create-primitive` first (EC13)
- Overwrite hand-edited files without confirmation
- Touch project source code outside `<layer>/<slice-name>/`
