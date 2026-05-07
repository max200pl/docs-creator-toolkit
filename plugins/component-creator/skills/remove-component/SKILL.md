---
name: remove-component
description: "Safely remove a component — finds all references, disconnects Figma Code Connect, deletes files, cleans registry and dependents. Always shows full impact and waits for confirmation."
scope: api
argument-hint: "<component-name>"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Remove Component

> **Registry schema:** `rules/registry-schema.md`
> **Registry source:** `.claude/state/component-registry.json`

## Usage

```text
/remove-component Button
/remove-component AsidePanel
```

## Execution

### ⚙ Version check

```
[component-creator | remove-component]
```

### Phase 0 — Locate

1. Find `<name>` in `component-registry.json` → get `path`, `figma_node_id`, `figma_file_key`, `figma_connected`, `layer`
2. If not found → stop: "Component `<name>` not found in registry."
3. Resolve file paths from `path` field:
   - `<path>/<name>.js`
   - `<path>/<name>.css`
   - `<path>/<name>.preview.js`
   - `<path>/<name>.figma.ts` (or `.figma.js`)
   - `<path>/img/` directory

### Phase 1 — Find all references

Run in parallel:

**A — CSS imports:**
```bash
grep -rn "<name>.css\|<layer>/<name>" res/app/main.css
```

**B — JS imports:**
```bash
grep -rn "from.*<name>/<name>\|import.*<name>" res/ --include="*.js"
```

**C — Registry dependents:**
Scan `component-registry.json` → find all entries where `uses` array contains `"<name>"`.

**D — Figma Code Connect status:**
If `figma_connected: true` → note that unpublish will be needed.

### Phase 2 — Impact report (STOP — wait for confirmation)

Show full impact before doing anything:

```
Component: <name>
Layer:     <layer>/<name>/

Files to delete:
  <path>/<name>.js
  <path>/<name>.css
  <path>/<name>.preview.js
  <path>/<name>.figma.ts         (if exists)
  <path>/img/                    (if exists, N files)

CSS imports to remove:
  res/app/main.css line <N>: @import "../<layer>/<name>/<name>.css"

JS imports in other components:
  <file>:<line> — import { <name> } from "..."   (N files)
  (none)

Registry dependents (uses[] to update):
  <ComponentA> — will have "<name>" removed from uses[]
  (none)

Figma Code Connect:
  figma connect unpublish — node <figma_node_id> in file <figma_file_key>
  (not connected — skip)

⚠️  This action is IRREVERSIBLE. Type "yes" to confirm removal →
```

**STOP. Do NOT proceed until user types explicit confirmation.**

### Phase 3 — Figma disconnect (if connected)

Only if `figma_connected: true`:

```bash
figma connect unpublish --node-id <figma_node_id> --file-key <figma_file_key>
```

If unpublish fails (token expired, network) → warn user, ask: continue anyway or abort?

### Phase 4 — Delete files

```bash
rm -f <path>/<name>.js
rm -f <path>/<name>.css
rm -f <path>/<name>.preview.js
rm -f <path>/<name>.figma.ts   # or .figma.js
rm -rf <path>/img/             # only if exists and non-empty
rmdir <path>/                  # only if now empty
```

### Phase 5 — Clean up all references

**5A — Remove CSS import:**
Edit `res/app/main.css` — remove the `@import` line for this component.

**5B — Fix JS imports in other files:**
For each file found in Phase 1B with an import of `<name>`:
- Remove the `import { <Name> } from "..."` line

**5C — Stub JSX usages:**
For each file with JS imports removed, scan for JSX usage of the component:
```js
// Find: <Button ... />  or  <Button>...</Button>
// Replace with: {/* TODO: <Button> removed — replace with alternative */}
```

Show each substitution to the user in the Phase 7 summary.

If JSX usage spans multiple lines (children) → replace the entire block with the stub comment.

### Phase 6 — Update registry

1. Remove the component entry from `component-registry.json`
2. For each dependent found in Phase 1C → remove `"<name>"` from their `uses[]` array

### Phase 7 — Summary

```
✓ Figma Code Connect unpublished
✓ Deleted: <N> files
✓ Removed @import from main.css
✓ Registry entry removed
✓ Updated uses[] in: <ComponentA>, <ComponentB>

Component <name> removed successfully.
```

## Rules

- **NEVER** delete anything before Phase 2 confirmation
- **NEVER** skip the impact report — even if it seems empty
- If any file in Phase 4 does not exist → skip silently (already deleted), do not error
- If `rmdir` fails (directory not empty) → warn, leave directory, do not force-delete
- JS imports in other files → always auto-remove import line + stub JSX usages with `{/* TODO: <Name> removed */}`
- Never leave broken imports behind — all referencing files must compile after removal
