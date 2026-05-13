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
☑ <type> / state:disable — (CSS [disabled])
☑ <type> / effect:*      — (CSS  hover/transitions/shadows — no extra JS prop)

Existing in registry: <none | partial match>
Layer: <path from Component Placement Rules>   (reference-component-creation-template.md)

Component table (one source of truth):

  ┌─────────────────┬────────────┬──────────┬──────────────┬──────────────────────┬───────────────┬────────────────┐
  │ Component       │ Figma ID   │ Axis     │ Values       │ Implementation       │ Visual change │ Status         │
  ├─────────────────┼────────────┼──────────┼──────────────┼──────────────────────┼───────────────┼────────────────┤
  │ <ComponentName> │ <nodeId>   │ type     │ <v1>, <v2>   │ JS prop              │ layout/icon   │ BUILD NOW      │
  │                 │            │ state    │ <s1>, <s2>   │ JS prop / CSS class  │ color/icon    │                │
  │                 │            │ effect   │ hover        │ CSS :hover           │ bg tint       │                │
  ├─────────────────┼────────────┼──────────┼──────────────┼──────────────────────┼───────────────┼────────────────┤
  │ <SubComponent>  │ <nodeId>   │ state    │ <s1>, <s2>   │ prop / CSS class     │ icon swap     │ ❌ build first │
  │                 │            │ effect   │ hover        │ CSS :hover           │ highlight     │ local ui/      │
  ├─────────────────┼────────────┼──────────┼──────────────┼──────────────────────┼───────────────┼────────────────┤
  │ <AssetSetName>  │ <nodeId>   │ type     │ <v1>..<vN>   │ SVG in img/          │ —             │ ASSET SET      │
  │                 │            │ state    │ <s1>..<sM>   │ <t>-<s>.svg per pair │               │ download only  │
  └─────────────────┴────────────┴──────────┴──────────────┴──────────────────────┴───────────────┴────────────────┘

  state = condition (active, disabled, selected) | effect = visual reaction (hover, shadow, transition)

Build order (bottom-up):
  1. <asset-set> (<nodeId>) — download N SVG → <layer>/<name>/img/
  2. <sub-component> (<nodeId>) — ❌ build first / ✅ reuse from <path>
  3. <this-component> (<nodeId>) — BUILD NOW

⚠ Components marked ❌ must be built first.

Files to be created:
  <layer>/<name>/
    <name>.js                — main component
    <name>.css
    <name>.preview.js        — Space overlay preview
    <name>.figma.ts          — Code Connect
    img/
      <icon>-<state>.svg     — (one line per actual Figma variant)
    ui/                      — (only if local sub-components)
      <sub-name>.js
      <sub-name>.css

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
