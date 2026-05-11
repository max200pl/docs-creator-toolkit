---
description: "Decompose rules for composite components — Phase 1.5. How to classify children, build order, and handle children not in registry."
---

# Component Decompose — Reference

## Sub-Component Detection (Phase 0.5)

Before deciding layer placement — check if the component name starts with an existing parent component name from registry:

```
"AsidePanelNavBarIcon" starts with "AsidePanel" (in registry)
→ suggest: res/widgets/aside-panel/ui/aside-panel-nav-bar-icon/
   type: local, parent: "AsidePanel"
```

Show both options and let user decide:
- **(a) Top-level widget** — `res/widgets/aside-panel-nav-bar-icon/`, `type: primitive`
- **(b) Sub-component** — `res/widgets/aside-panel/ui/aside-panel-nav-bar-icon/`, `type: local, parent: "AsidePanel"`

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
