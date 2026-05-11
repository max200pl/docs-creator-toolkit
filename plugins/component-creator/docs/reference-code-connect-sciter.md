---
description: "Code Connect specifics for Sciter.js projects — file format, package.json constraint, publish flow."
---

# Code Connect — Sciter Reference

## File Format

Always use **`.figma.ts`** extension, NOT `.figma.js`.

- CLI transpiles `.ts → .js` before sending to Figma
- `.figma.js` is sent raw — `import` statements break in Figma runtime
- Project must NOT have `"type": "module"` in `package.json` — breaks CLI transpilation

## Before Generating

Call `get_code_connect_map(nodeId, fileKey)` BEFORE creating the file:
- If mapping exists → show old→new diff, ask user to replace or keep
- If no mapping → create new

## Publish Flow

```bash
figma connect publish --dry-run   # validate first
figma connect publish             # publish if dry-run OK
```

If no token → create `.figma.ts`, skip publish, note: "publish manually when token available".

## EC13 — No Primitive Pattern Found

If no existing `*.figma.ts` in project:
> "No Code Connect pattern found — one-time setup needed.
> Pick a simple Sciter primitive (Button, Icon, Badge) — component set ◆◆, not a variant ◆:
> Paste its Figma URL:"

Run inline onboarding: create primitive → establish format → continue with original component.
