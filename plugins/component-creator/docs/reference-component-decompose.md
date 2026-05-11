---
description: "Decompose rules for composite components — Phase 1.5. How to classify children, build order, and handle children not in registry."
---

# Component Decompose — Reference

## Layer Auto-Detection (Phase 0.5)

Layer is derived from `architecture.organizing_principle` in `frontend-analysis.json` + `reference-component-creation-template.md`.

### FSD projects (`organizing_principle: "fsd"`)

Classify by component scope and dependencies:

| Component type | Layer | Example |
| ---- | ---- | ---- |
| Generic UI primitive, no domain logic | `shared/ui` | Button, Icon, Badge, Input |
| Domain entity (knows about business data) | `entities/<name>` | UserCard, ProductBadge |
| User interaction with side effects | `features/<name>` | LoginForm, AddToCart |
| Composite block, multiple features | `widgets/<name>` | Sidebar, Header |
| Full page view | `pages/<name>` | DashboardPage |

**Rule:** if component name has no domain noun → `shared/ui`. If it includes a domain noun (User, Product, Order) → `entities` or `features`.

### Non-FSD projects

Read `## Component Placement Rules` from `reference-component-creation-template.md` (Gap B).
Use the layer path pattern defined there. If the section is absent → ask user where to place it.

### In Phase 0.5 plan — always show detection result:

```
Layer detection:
  Architecture: FSD (from frontend-analysis.json)
  Component type: primitive (no domain noun, generic UI)
  → shared/ui/button/
```

or

```
Layer detection:
  Architecture: feature-folders (from frontend-analysis.json)
  → widgets/button/ (from Component Placement Rules in template)
```

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
