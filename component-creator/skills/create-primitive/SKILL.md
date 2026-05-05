---
name: create-primitive
description: "One-time onboarding skill — creates a minimal component and establishes the project's Code Connect pattern. Run once before /create-component. The created primitive becomes the project-wide reference for Code Connect format, file extension, and publish command. For Sciter projects use /sciter-create-primitive instead."
scope: api
argument-hint: "[figma-url]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Create Primitive

> **Purpose:** one-time project onboarding — establish Code Connect pattern.
> **Result used by:** `create-component` Phase 5 — scans project for this primitive to discover format + publish command.
> **Sciter projects:** use `/sciter-create-primitive` instead — includes SSIM visual verify.

## Usage

```text
/create-primitive
/create-primitive https://figma.com/design/FILE?node-id=1:234
```

A primitive is a **simple, standalone component** with no external project dependencies (Button, Icon, Badge, Tag, Chip). It must:
- Have a Figma **component set** node (◆◆ icon in layers panel — NOT a variant ◆)
- Have no child component instances (no decomposition needed)

## When to Run

Run once during project onboarding. After this, `/create-component` Phase 5 discovers the Code Connect pattern automatically from the created primitive.

If `/create-component` reaches Phase 5 and finds no primitive → EC13 → it stops and prompts to run this skill first.

## Execution

### Step 0 — Pre-flight

1. `TodoWrite` — init task items as `pending`
2. Read preconditions:
   - `frontend-analysis.json` accessible (for `naming_conventions`, `styling_system`)
   - `component-registry.json` accessible (or will be created if absent)
   - Figma token: `mcp__figma__whoami` → stop on 401 (EC5)
3. If no Figma URL provided → prompt:
   > "Please paste the Figma URL for a simple component (Button, Icon, Badge) — this will be your project's Code Connect reference. Select the component set (◆◆), not a variant (◆)."
4. Parse `fileKey` + `nodeId` from URL (convert `-` → `:` in node-id)
5. **Validate node type** — call `mcp__figma__get_design_context(nodeId, fileKey)`:
   - If response indicates this is a **variant** (has `variantProperties`, or is a child of a component set) → stop immediately:
     > "The provided node is a variant, not a component set. In Figma, right-click the parent ◆◆ component set in the layers panel → Copy link to selection. Provide that URL."
   - If response is a component set or standalone component → proceed

### Phase 1 — Design context

No reuse check — creating from scratch.

1. `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` — full structure + variants
2. Confirm component name (EC6: apply `naming_conventions.component_file`, show converted name)
3. Determine FSD layer from `frontend-analysis.json` — default `shared/ui` for primitives
4. Token sync: `mcp__figma__get_variable_defs(nodeId, fileKey)` → compare against token file

### Phase 2 — Generate files

Generate minimal component — no decomposition, no child dependencies.
Apply generic rules from `rules/component-output-format.md`.

Files to create:
- `<name>.js` (or `.ts` — per `naming_conventions.component_file`)
- `<name>.css` (if project uses separate CSS)
- `<name>.preview.js` — isolated demo

Download icon SVGs if icon nodes detected. Add missing tokens. Register `@import`. Run component-done checklist.

### Phase 3 — Visual verify

Skip — log `[SKIP] Visual accuracy — use /sciter-create-primitive for SSIM verification`.

### Phase 4 — Registry

Upsert entry per `rules/component-output-format.md` § Registry Entry Schema with:
- `type: "primitive"`
- `status: "in-progress"` (updated to `"done"` after Phase 5)
- `ssim_score: null`

### Phase 5 — Establish Code Connect pattern

1. Scan project for existing Code Connect files (`*.figma.ts`, `*.figma.js`):
   - Found → ask: "Found existing Code Connect files (`<ext>`). Use same format or choose new one?"
   - Not found → proceed to step 2

2. Prompt user for format:
   > "Choose the Code Connect format for this project:
   > 1. TypeScript `.figma.ts` — `figma connect publish`
   > 2. JavaScript `.figma.js` — `figma connect publish`
   > 3. Custom — describe the format and publish command"

3. If option 3: capture file extension, template structure, publish command from user.

4. Create Code Connect file `<name>.figma.{ext}` following chosen format

5. Validate: `<publish-command> --dry-run` → on failure show error, ask user to fix and confirm

6. Publish: `<publish-command>`
   - On auth error: note "Code Connect file created — publish manually"; continue

7. Update registry: `figma_connected: true`, `last_figma_sync_at: <now>`, `status: "done"`

### Finish

```text
✓ Primitive: <name>
  Layer:       <layer>/<slice-name>/
  CC format:   <name>.figma.{ext}
  Publish cmd: <command>
  Registry:    entry created (type: primitive, figma_connected: true)

/create-component will now discover this primitive to determine Code Connect format.
```

## What This Skill Does NOT Do

- Run SSIM visual verification — use `/sciter-create-primitive` for Sciter projects
- Decompose composite components — keep the primitive simple
- Create multiple primitives at once — run once per onboarding
