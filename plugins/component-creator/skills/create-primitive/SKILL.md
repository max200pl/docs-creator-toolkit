---
name: create-primitive
description: "One-time onboarding skill — creates a minimal component and establishes the project's Code Connect pattern. Run once before /create-component. The created primitive becomes the project-wide reference for Code Connect format, file extension, and publish command. Supports --adapter for framework-specific generation and visual verify."
scope: api
argument-hint: [figma-url] [--adapter <adapter-name>]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Create Primitive

> **Purpose:** one-time project onboarding — establish Code Connect pattern.
> **Result used by:** `create-component` and `sciter-create-component` Phase 5 — scan project for this primitive to discover format + publish command.
> **Adapter:** if `--adapter sciter` provided (or auto-detected), applies Sciter CSS/JS rules and runs SSIM visual verify.

## Usage

```text
/create-primitive
/create-primitive https://figma.com/design/FILE?node-id=1:234
/create-primitive --adapter sciter
/create-primitive https://figma.com/design/FILE?node-id=1:234 --adapter sciter
```

A primitive is a **simple, standalone component** with no external project dependencies (Button, Icon, Badge, Tag, Chip). It must:
- Have a Figma component node (◆ icon in layers panel)
- Have no child component instances (no decomposition needed)

## When to Run

Run `/create-primitive` once during project onboarding. After this, `/create-component` Phase 5 discovers the Code Connect pattern automatically from the created primitive.

If `/create-component` reaches Phase 5 and finds no primitive → EC13 → it stops and asks you to run this skill first.

## Execution

### Step 0 — Pre-flight

1. `TodoWrite` — init task items as `pending`
2. Read preconditions:
   - `frontend-analysis.json` accessible (for `naming_conventions`, `styling_system`, adapter auto-detect)
   - `component-registry.json` accessible (or will be created if absent)
   - Figma token: `mcp__figma__whoami` → stop on 401 (EC5)
3. Resolve adapter:
   - If `--adapter <name>` provided → use it
   - Else read `frontend-analysis.json` → `stack.framework`:
     - `sciter` → set adapter = `sciter`
     - anything else → adapter = generic (no visual verify)
4. If no Figma URL provided → prompt:
   > "Please paste the Figma URL for a simple component (Button, Icon, Badge) — this will be your project's Code Connect reference."
5. Parse `fileKey` + `nodeId` from URL (convert `-` → `:` in node-id)

### Phase 1 — Design context (simplified)

No reuse check — this is intentionally creating the primitive from scratch.

1. `mcp__figma__get_design_context(nodeId, fileKey)` — layout reference
2. `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` — full structure + variants
3. Confirm component name (EC6: apply `naming_conventions.component_file`, show converted name)
4. Determine FSD layer from `frontend-analysis.json` — default `shared/ui` for primitives
5. Token sync: `mcp__figma__get_variable_defs(nodeId, fileKey)` → compare against token file

### Phase 2 — Generate files

Generate minimal component — no decomposition, no child dependencies.

If adapter = `sciter`: apply all Sciter CSS/JS rules from `sciter-create-component/SKILL.md` § Phase 2 Stream B.
Otherwise: apply generic rules from `rules/component-output-format.md`.

Files to create:
- `<name>.js` (or `.ts` — per `naming_conventions.component_file`)
- `<name>.css` (if project uses separate CSS)
- `<name>.preview.js` — isolated demo

Download icon SVGs if icon nodes detected (same as `create-component` Stream A).
Add missing tokens to token file.
Register `@import` in main CSS entry file.
Run component-done checklist.

### Phase 3 — Visual verify (adapter-specific)

If adapter = `sciter`: run full visual verify per `sciter-create-component/SKILL.md` § Phase 3 (SSIM 0.95 gate, ScreenshotHistory, EC14).
Otherwise: skip — log `[SKIP] Visual accuracy — no adapter visual_verify configured`.

### Phase 4 — Registry

Upsert entry per `rules/component-output-format.md` § Registry Entry Schema with:
- `type: "primitive"`
- `status: "in-progress"` (updated to `"done"` after Phase 5)
- `ssim_score`: from Phase 3 result, or `null` if skipped

### Phase 5 — Establish Code Connect pattern

This phase differs from `create-component` — instead of discovering an existing pattern, we **create** the pattern.

1. Scan project for existing Code Connect files (`*.figma.ts`, `*.figma.js`):
   - Found → ask user: "Found existing Code Connect files. Use the same format (`<ext>`) or choose a new one?"
   - Not found → proceed to step 2

2. Prompt user for format:
   > "Choose the Code Connect format for this project:
   > 1. TypeScript `.figma.ts` — `figma connect publish`
   > 2. JavaScript `.figma.js` — `figma connect publish`
   > 3. Custom — I'll describe the format and publish command"

3. If option 3: capture from user:
   - File extension
   - Template structure (show an example from user or from existing docs)
   - Publish command

4. Create Code Connect file `<name>.figma.{ext}` following chosen format

5. Validate: `<publish-command> --dry-run`
   - On failure: show error + suggest fix; ask user to resolve and confirm

6. Publish: `<publish-command>`
   - On 401/auth error: note "Code Connect file created — publish manually when token is available"; continue

7. Update registry: `figma_connected: true`, `last_figma_sync_at: <now>`, `status: "done"`

### Finish

```text
✓ Primitive: <name>
  Layer:       <layer>/<slice-name>/
  CC format:   <name>.figma.{ext}
  Publish cmd: <command>
  SSIM:        <score or "skipped">
  Registry:    entry created (type: primitive, figma_connected: true)

/create-component will now discover this primitive to determine Code Connect format.
```

## What This Skill Does NOT Do

- Replace `/create-component` for ongoing work — run this once, then use `create-component`
- Decompose composite components — keep the primitive simple
- Create multiple primitives at once — run once per onboarding
- Override Code Connect format after it is established — edit the existing primitive file manually if needed
