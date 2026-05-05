---
description: "Two registry files exist — one is the source of truth (JSON), one is a read-only view (markdown). Never confuse them."
---

# Registry Files

## Rule

One source of truth: `.claude/state/component-registry.json`.

There is no markdown mirror. `reference-component-registry.md` was removed — maintaining two sources causes drift and confusion.

## What Skills Must Do

- **Read:** load `.claude/state/component-registry.json` for all reuse checks and lookups
- **Write:** write only to `.claude/state/component-registry.json` — follow `rules/registry-schema.md`
- **Never** read any markdown file as a registry template

## Git

`component-registry.json` must be committed to git — it is the only persistent link between code components and Figma nodes. Add to project `.gitignore`:
```
!.claude/state/component-registry.json
```

Without this, Figma connections (`figma_node_id`, `figma_connected: true`) are lost every time `/analyze-frontend` reruns.
