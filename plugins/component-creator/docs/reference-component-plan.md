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

Child components detected:
  ✦ <ChildName> — nodeId: <id> — ✅ in registry, reuse from <path>
  ✦ <ChildName> — nodeId: <id> — ❌ NOT in registry, build first
  ✦ <IconSetName> — asset set → download to <layer>/<name>/img/

Build order (bottom-up):
  1. <deepest child or asset set> — <status>
  2. <next child>                 — <status>
  3. <this component>             — BUILD NOW

⚠ Components marked ❌ must be built first. Cannot proceed until all in registry.

Files to be created:
  <layer>/<name>.js          — component class
  <layer>/<name>.css         — styles
  <layer>/<name>.preview.js  — full grid (all types, for Space overlay)
  <layer>/<name>.figma.ts    — Code Connect
  <layer>/img/<icon>.svg     — (if icons detected)
  (<layer> = path from Component Placement Rules)

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
