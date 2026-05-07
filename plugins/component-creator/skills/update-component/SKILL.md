---
name: update-component
description: "Update an existing component to match a changed Figma design. Diffs current implementation against Figma, shows a change plan, waits for confirmation, then applies changes and re-verifies SSIM."
scope: api
argument-hint: "<component-name> [figma-url]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Update Component

> **Adapter rules:** `docs/reference-sciter-css.md`, `docs/reference-component-build.md`, `docs/reference-token-sync.md`
> **Registry schema:** `rules/registry-schema.md`

## Usage

```text
/update-component Button
/update-component AsidePanel https://figma.com/design/FILE?node-id=1:88
```

Figma URL is optional — if omitted, resolved from `<name>.figma.ts` URL comment (`// url=https://...`).

## Execution

### ⚙ Version check

```
[component-creator | update-component]
```

### Step 0 — TodoWrite

```
☐ Phase 0 — Locate component + resolve Figma URL
☐ Phase 1 — Analyze: Figma diff + token sync (parallel)
☐ Phase 2 — Change plan (user confirms)
☐ Phase 3 — Download new assets (if needed)
☐ Phase 4 — Apply changes bottom-up
☐ Phase 5 — Visual verify (SSIM)
☐ Phase 6 — Registry + Code Connect update
```

### Phase 0 — Locate

1. Find component in `component-registry.json` by name → get `path`, `figma_node_id`, `figma_file_key`
2. If not in registry → stop: "Component not found in registry. Run `/create-component` first."
3. Resolve Figma URL: from argument OR from `// url=` comment in `<name>.figma.ts`
4. Read current `<name>.js` + `<name>.css` from filesystem

### Phase 1 — Analyze (parallel)

Run in parallel:

**Agent A — Figma diff:**
- `mcp__figma__get_design_context(nodeId, fileKey)` — check Code Connect
- `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` — full structure
- `mcp__figma__get_screenshot(nodeId, fileKey)` — fresh visual reference

**Agent B — Token sync:**
- `mcp__figma__get_variable_defs(nodeId, fileKey)` — current Figma variables
- Compare against local token file (see `docs/reference-token-sync.md`)
- Flag conflicts: same-name-diff-value / diff-name-same-value / new tokens

**Agent C — Code diff:**
- Read current CSS + JS
- Load previous Figma screenshot from `tools/ScreenshotHistory/` (saved at creation time)

### Phase 2 — Change plan (STOP — wait for user confirmation)

Compare Figma (new) vs current implementation across 11 categories:

| # | Category | Checks |
| ---- | ---- | ---- |
| 1 | Structure | FSD layer, file layout |
| 2 | Layout | flow direction, nesting |
| 3 | Pixel-perfect sizing | width/height exact dip values |
| 4 | Pixel-perfect spacing | padding, gap, margin exact dip values |
| 5 | Colors | token values vs Figma |
| 6 | Typography | @mixin names, sizes |
| 7 | Icons | new/removed/renamed icons |
| 8 | Borders | border-radius, border-width |
| 9 | Shadows | box-shadow values |
| 10 | States | new/removed variant states |
| 11 | Token accuracy | each `var(--token)` resolves to exact Figma value |

**Format each change as:** `was → now (source: Figma)`

Show full change list → **STOP. Do NOT write any code until user confirms.**

### Phase 3 — Download new assets

Only if Phase 2 detected new or changed icons. Use `tools/fetch-figma-svg.sh`. See `docs/reference-component-decompose.md` for icon naming algorithm.

### Phase 4 — Apply changes bottom-up

Apply only confirmed changes as targeted edits — **not full rewrite**.

Order: tokens → typography → CSS → JS → `.preview.js` → verify `@import` in `main.css`

**Pixel-perfect rule:** Figma is source of truth for dimensions. If token value ≠ Figma value → use raw `dip` (not token). See `docs/reference-sciter-css.md`.

After edits → run component-done checklist (`rules/component-output-format.md`).

### Phase 5 — Visual verify (SSIM)

Same flow as `sciter-create-component` Phase 3. See `docs/reference-component-build.md`.

`ssim_score` target: `0.95` default, `0.92` for SVG icons + border-radius ceiling.

### Phase 6 — Registry + Code Connect

1. Update registry entry: `last_verified_at`, `ssim_score`, `status: "done"`, update `variants`/`states` if changed
2. `mcp__figma__get_code_connect_map(nodeId, fileKey)` — check existing mapping
3. If mapping exists → show old→new diff, ask to replace or keep
4. Update `<name>.figma.ts` if changed
5. `figma connect publish --dry-run` → publish

Update `last_figma_sync_at` in registry entry.

## Key Rules

- **NEVER** edit code without showing change plan first
- **ALWAYS** wait for explicit user confirmation before Phase 4
- **PRESERVE** existing component structure — only apply confirmed changes, no full rewrites
- **Figma > token** for all dimension values
- **No silent renames** — if Figma renamed a component/variant, flag it explicitly
