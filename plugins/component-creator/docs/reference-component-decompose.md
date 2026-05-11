---
description: "Decompose rules for composite components — Phase 1.5. How to classify children, build order, and handle children not in registry."
---

# Component Decompose — Reference

## Layer Detection (Phase 0.5)

**Source:** `reference-component-creation-template.md` — produced by `/create-frontend-docs` and already read in Step 0.2.

Read `## Component Placement Rules` section from that file. It contains the project-specific placement rules derived from the actual codebase structure — no need to re-analyze or apply generic FSD rules here.

If `## Component Placement Rules` section is absent → ask user where to place the component.

**In Phase 0.5 plan — always show result:**

```
Layer: <path from Component Placement Rules>  (reference-component-creation-template.md)
```

## Child Component Detection (Phase 0.5)

Always scan for nested component instances — even for standalone COMPONENT nodes (not just COMPONENT_SET).

### Algorithm

**Step 1 — get full structure:**
Call `get_design_context(nodeId, fileKey, disableCodeConnect: true)`.
Parse the response for child nodes whose `type` is `COMPONENT` or `INSTANCE`.

**Step 2 — if children not visible:**
Call `get_metadata(nodeId, fileKey)` → get `children` array with nodeIds and types.
For each child with `type: COMPONENT | INSTANCE`: call `get_design_context(childNodeId, fileKey, disableCodeConnect: true)`.

**Step 3 — recurse:**
For each child component found, repeat Steps 1–2 to detect ITS children.
Continue until no more nested components. The tree may be N levels deep.

**Step 4 — classify each node:**
- `COMPONENT_SET` or `COMPONENT` with variant axis → real component, check registry
- `COMPONENT`/`INSTANCE` with only visual image variants → asset set (see § Asset Set Detection)
- `FRAME`, `GROUP`, text, shapes → layout only, no separate component needed

**Step 5 — check registry per component node:**
- EXACT MATCH (by `figma_node_id` or name) → reuse, import from `path`
- NOT FOUND → must build first; block parent until dependency is ready

**Step 6 — states drive asset variants:**
If a child component has states (e.g. `default`/`active`) AND uses an icon asset set →
the icon set must provide one file per state:
```
<icon-type>-<state>.svg   (e.g. home-normal.svg, home-active.svg)
```
The parent component's state selector picks the correct file.

### Build order output (show in plan)

```
Build order (bottom-up):
  1. <asset-set-name> — asset set → download to <parent>/img/
  2. <deepest-child>  — ❌ not in registry / ✅ reuse from <path>
  3. <parent-child>   — ❌ not in registry / ✅ reuse
  4. <this-component> — BUILD NOW
```

⚠ Any component marked ❌ must be built first. Do not proceed until all are in registry.

## Execution — Build from Plan

After user confirms Phase 0.5 plan, execute in the **Build order** shown (bottom-up):

| Item type | Action |
| ---- | ---- |
| Asset set | Download all icon variants to `<parent>/img/` immediately — before Phase 2B |
| Component ✅ in registry | Skip build — import from registry `path` in parent's JS |
| Component ❌ not in registry | **STOP** — "Build `<Name>` first with `/create-component`, then re-run." |
| This component (last) | Run full Phases 1 → 5 |

**Icons must be downloaded before Phase 2B** — JS references `img/` paths that must exist.

---

## Asset Set Detection (Phase 0.5)

Before treating a Figma component set as a new component — check if it's actually a **set of visual assets** (icons, images) rather than a UI component.

**Signs it's an asset set, not a component:**
- All variants differ only in the visual image (different icons per type)
- No layout, no text, no interactive behavior — pure image nodes
- Variants map to different icon files, not different component states

**If it's an asset set:** do NOT create a separate component directory. Download the icons and place them in `img/` of the parent component that uses them.

Path follows project conventions from `reference-component-creation-template.md`:
```
<layer>/<parent-component-name>/img/<icon-name>.svg
```

Example (paths are project-specific, not hardcoded):
```
→ NOT a component
→ download to: <layer>/<parent>/img/home-normal.svg, history-normal.svg, ...
```

## Sub-Component Detection (Phase 0.5)

Before deciding layer placement — check registry for a parent component whose name is a prefix of the new component name.

**Pattern:** `<ParentName><Suffix>` → suggest placing inside parent's `ui/` directory.

Paths follow project conventions from `reference-component-creation-template.md` (not hardcoded).

Show both options and let user decide:
- **(a) Top-level** — `<layer>/<component-name>/`, `type: primitive/feature`
- **(b) Sub-component** — `<layer>/<parent-name>/ui/<component-name>/`, `type: local, parent: "<ParentName>"`

## When to Decompose

Decompose when `get_design_context(disableCodeConnect: true)` reveals child component instances (not just nested frames). Pure layout wrappers with no logic or states → flatten into parent, no separate file.

## Child Classification

| Child type | Placement | Rule |
| ---- | ---- | ---- |
| Private to this slice | `<slice>/ui/<sub>.js` | used only inside this component |
| Reusable across slices | `shared/ui` | appears in 2+ components — flag for promotion, do NOT force |
| Pure layout wrapper | flatten into parent | no logic, no states, no variants |

**Promotion is not automatic.** Create locally first, promote when actually reused. `validate-registry` flags `type: local` entries that appear in 2+ components and suggests promotion.

## Build Order

Always bottom-up: deepest children first, then their parents.

```
Page
  └── Widget           ← build 2nd
        └── Primitive  ← build 1st
```

Never build a parent before its children exist in registry.

## EC12 — Child Not in Registry

Child component instances detected but no registry entry and no files on disk.

1. Create locally inside parent: `<parent>/ui/<child-name>.js` + `.css`
2. Register with `type: local`, `parent: "<ParentName>"` — no blocking, no extra prompts
3. Continue building parent using local child
4. `validate-registry` later scans `uses` fields, finds `type: local` in 2+ components, flags for promotion

## Phase 2A — SVG Download

Always try SVG first. Never plan PNG upfront.

```bash
# Step 1 — SVG
tools/fetch-figma-svg.sh <fileKey> <iconNodeId> <layer>/img/<icon>.svg

# Step 2 — PNG fallback (only on 404)
mcp__figma__get_screenshot(nodeId: <iconNodeId>, fileKey)
# Save as <layer>/img/<icon>.png; update JS to __DIR__ + "img/<icon>.png"
```

In Phase 0.5 plan — list icons as `.svg`. Change to `.png` only after actual 404.

## Icon Naming Algorithm

Convert Figma `layerName` to kebab-case SVG filename:

1. Remove section prefix (`"Icon / "`, `"Icons / "`, `"Ic "`)
2. Replace `/` and spaces with `-`
3. Lowercase everything
4. Add `.svg`

```
"Icon / Scan / Normal"  → scan-normal.svg
"Icon / Scan / Active"  → scan-active.svg
"Ic_Settings"           → ic-settings.svg
"Settings icon"         → settings-icon.svg
```

Icon names must describe **purpose**, not appearance (`close.svg` not `x-shape.svg`).

## Icon Display Pattern

| Use case | Correct |
| ---- | ---- |
| Icon is the main content of element | `<img src="__DIR__ + 'img/icon.svg'" />` |
| Icon decorates an interactive element | `foreground-image: url(img/icon.svg)` + `foreground-size: contain` in CSS |
| Many small icons from one sprite | `@image-map` |
