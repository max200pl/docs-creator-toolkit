---
description: "Phase 0.5 plan display format — how to structure the variant analysis plan shown to the user before confirmation."
---

# Component Plan Format — Phase 0.5

Use this format when showing the plan to the user in Phase 0.5.

```
Component Set: <name> (N variants)          ← or "Component: <name>" for single

Property axes detected:
  type   — <list of values>        → JS prop
  state  — Default / hover / disable / … → CSS :hover / [disabled] / …
  effect — Default / shadow / blur / … → CSS transition / box-shadow / …
  (only "type" becomes a JS prop; state + effect → CSS-only)

☑ <type> / state:Default / effect:Default  — nodeId: <id> — <description>
☑ <type> / state:hover   — (CSS :hover)
☑ <type> / state:disable — (CSS [disabled])
☑ <type> / effect:*      — (CSS transitions/shadows — no extra JS prop)

Existing in registry: <none | partial match>
Layer: <path from Component Placement Rules>   (reference-component-creation-template.md)

Dependency table:

  ┌─────────────────┬──────────────┬─────────────────────────┬────────────────┐
  │   Component     │ Variants/States              │ Uses            │ Status         │
  ├─────────────────┼──────────────────────────────┼─────────────────┼────────────────┤
  │ <ChildName>     │ state: <s1>, <s2>            │ <AssetSetName>  │ ❌ build first │
  │                 │ type: <t1>, <t2>             │                 │                │
  ├─────────────────┼──────────────────────────────┼─────────────────┼────────────────┤
  │ <AssetSetName>  │ <axis>: <v1>/<v2>            │ —               │ asset set      │
  │                 │ (N variants → N .svg files)  │                 │ download       │
  ├─────────────────┼──────────────────────────────┼─────────────────┼────────────────┤
  │ <ThisComponent> │ (no variant axis)            │ <ChildName>     │ BUILD NOW      │
  └─────────────────┴──────────────────────────────┴─────────────────┴────────────────┘

Build order (bottom-up):
  1. <asset-set> — download to <layer>/<name>/img/
  2. <deepest-child> — ❌ build first / ✅ reuse
  3. <this-component> — BUILD NOW

⚠ Components marked ❌ must be built first. Cannot proceed until all in registry.

Files to be created:
  <layer>/<name>/
    <name>.js                — main component
    <name>.css               — styles
    <name>.preview.js        — Space overlay preview
    <name>.figma.ts          — Code Connect
    img/
      <icon-1>.svg           — (one line per icon from dependency table)
      <icon-2>.svg
    ui/                      — (only if sub-components detected)
      <sub-name>.js          — sub-component
      <sub-name>.css
  (<layer> = path from Component Placement Rules; ui/ only if local children)

States table:

  ┌─────────────────┬────────────────┬──────────────────────┬─────────────────────────────┐
  │ Component       │ State          │ Implementation       │ Visual change               │
  ├─────────────────┼────────────────┼──────────────────────┼─────────────────────────────┤
  │ <ComponentName> │ <state-name>   │ JS prop / CSS :hover │ <what changes visually>     │
  │                 │ <state-name>   │ CSS [disabled]       │ <what changes visually>     │
  ├─────────────────┼────────────────┼──────────────────────┼─────────────────────────────┤
  │ <SubComponent>  │ <state-name>   │ prop active: bool    │ icon swap + color change    │
  └─────────────────┴────────────────┴──────────────────────┴─────────────────────────────┘

Token delta:
  + --<token-name>: <value>   — <Figma variable it maps to>
  = --<existing>              — already exists, reused
  (none) if all colors covered by existing tokens

SSIM verification plan:

  — COMPONENT_SET (multiple types):
  ✦ <type1> / state:Default / effect:Default — nodeId: <id> — width: <W>dip
  ✦ <type2> / state:Default / effect:Default — nodeId: <id> — width: <W>dip
  One run per type. threshold: <0.92 SVG icons | 0.95 default>

  — Single COMPONENT:
  ✦ <ComponentName> — nodeId: <id> — width: <W>dip × height: <H>dip
  One run, full component. threshold: <0.92 SVG icons | 0.95 default>

  state:hover / effect:* — CSS-only, Space overlay only

  ⚠ width/height = absoluteBoundingBox of component frame (not child icon size)

Confirm variant selection →
```

## Notes

- Always confirm component name with user before showing rest of plan (typo check)
- Width/height from `get_design_context` `absoluteBoundingBox`, not child node dimensions
- "Child components detected" section: omit if none found
- "Build order" section: omit if no dependencies
