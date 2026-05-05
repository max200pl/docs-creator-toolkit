---
name: sciter-create-component
description: "Sciter.js adapter for create-component. Implements adapter.generate() with dip/flow/@mixin rules and adapter.visual_verify() with preview-component.sh + SSIM 0.95 gate. Invoke instead of /create-component on Sciter.js projects."
scope: api
argument-hint: "<component-name> [figma-url]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Sciter Create Component

> **Execution flow:** `sequences/sciter-create-component.mmd` (Sciter delta) + `sequences/create-component.mmd` (generic base)
> **Workflow rules:** `rules/component-creation-workflow.md`
> **Output format:** `rules/component-output-format.md` (Sciter CSS overrides below take precedence)
> **Registry schema:** `rules/registry-schema.md` — strict field allowlist; validate before every Phase 4 write

## Usage

```text
/sciter-create-component ButtonPrimary
/sciter-create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
```

## Execution

### ⚙ Version check — print before anything else

Output this line immediately when the skill starts, before any tool calls:
```
[component-creator v0.0.4 | sciter-create-component]
```

### Step 0 — Pre-flight (MANDATORY — do not skip any sub-step)

**0.1 TodoWrite** — call FIRST, before any reads or Figma calls:
```
☐ Step 0    — Pre-flight
☐ Phase 0.5 — Variant analysis + plan (user confirms)
☐ Phase 1   — Context: Figma + Reuse + Token/typography sync
☐ Phase 1.5 — Decompose (if composite)
☐ Phase 2A  — Download assets (SVG icons)
☐ Phase 2B  — Generate Sciter CSS + JS + preview + @import
☐ Phase 3   — Visual verify (SSIM)
☐ Phase 4   — Registry upsert
☐ Phase 5   — Code Connect
```

**0.2 Read docs** (parallel): `reference-component-creation-template.md`, `component-registry.json`, `frontend-analysis.json` (extract `naming_conventions` + `styling_system`), `frontend-design-system.md` (extract `token_file` + `typography_file`).

**Do NOT read any existing component files (JS/CSS/figma.ts) or individual registry entries as templates or code patterns.** Use only:
- `reference-component-creation-template.md` → code conventions
- `rules/registry-schema.md` → registry entry format
- `rules/component-output-format.md` → naming, file layout
Existing components (ButtonFeedback, etc.) are read ONLY in Phase 5 to discover Code Connect format from the primitive's `.figma.ts` file.

**0.3 Agent memory** — check `.claude/agent-memory/sciter-create-component/`. If empty → seed `feedback_ssim_typography.md` (see § Agent Memory below).

**0.4 Figma token** — `mcp__figma__whoami`. On 401 → stop (EC5).

**0.5 Parse URL** — extract `fileKey` + `nodeId` from argument (convert `-` → `:` in node-id).

**0.6 EC2 check** — if directory `<name>/` exists (even empty) and no registry entry → prompt: overwrite / register as-is / cancel.

**0.7 Variant hard-block** ⚠️ — call `mcp__figma__get_code_connect_suggestions(nodeId, fileKey)`.
Read the `mainComponentNodeId` field from the response.

**Compare literally:** is `mainComponentNodeId` the same string as `nodeId`?
- **YES (equal)** → node is a component set → continue to Phase 0.5
- **NO (different)** → node is a variant → **STOP. Do NOT proceed. Do NOT call get_design_context. Do NOT read files.**
  Show exactly:
  > "Node `<nodeId>` is a **variant** (◆), not a component set (◆◆).
  > `mainComponentNodeId` = `<mainComponentNodeId>` — this is the correct node.
  > Please provide the Figma URL with node-id=`<mainComponentNodeId>` (replace `-` with `-` in the URL)."
- Re-parse the new URL provided by user. Repeat step 0.7 with the new nodeId.

---

### Phase 0.5 — Variant Analysis and Plan (MANDATORY — do not start Phase 1 without user confirmation)

1. `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` → all variant property combinations
2. For each variant: note what differs (colors, layout, states)
3. Check registry for component name or `figma_node_id`
4. Show plan:

```
Component Set: <name> (N variants)

☑ <prop> / default  — <description>
☑ <prop> / hover    — ...
☐ disabled          — (uncheck if not needed)

Existing in registry: <none | partial match>
Suggested layer: <widgets | shared/ui>

Confirm variant selection →
```

5. **Wait for explicit user confirmation before Phase 1.**

---

## Sciter Adapter Overrides

### adapter.generate() — CSS rules

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Layout | `flow: horizontal` / `flow: vertical` | `display: flex` |
| Flex fill | `width: *` / `height: *` | `flex: 1` |
| Hidden overflow | `overflow: none` | `overflow: hidden` |
| Dimensions | `dip` (1:1 from Figma px) | `px` |
| Colors | CSS vars only | hardcoded hex |
| Typography | `@mixin name;` | `font` shorthand with `var()` |
| Mixin syntax | no commas inside `@mixin` | comma-separated values |
| Centering + `width:*` | `vertical-align: middle` on every child | `content-vertical-align` on parent |

### adapter.generate() — JS rules

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Base class | `class Name extends Element` | functional component |
| HTML attr | `class="..."` | `className="..."` |
| Icon paths | `__DIR__ + "img/..."` | `"./img/..."` |
| Imports | must include `.js` extension | bare paths |
| State | native Sciter element methods | React hooks |

### adapter.visual_verify() — SSIM

**Component set preview strategy:**
When the component is a component set with multiple variants (types × states), the `preview.js` must reproduce the exact same grid layout as the Figma component set screenshot:
- Rows = states (Default, hover, disabled)
- Columns = types (sec, prim, with-icon)
- Same spacing/gaps as Figma

This way SSIM compares the full grid in one shot. Do NOT compare a partial layout against the full Figma set screenshot — SSIM will always fail due to composition mismatch.

For `:hover` and `[disabled]` states that cannot be triggered programmatically, use CSS forced-state classes in preview:
```js
// Force hover state for preview row
<div class="button button--sec button--preview-hover">Not Now</div>
```
```css
/* preview-only forced states */
.button--preview-hover { /* same styles as :hover */ }
.button--preview-disabled { /* same styles as [disabled] */ }
```

**Resolve adaptive threshold before running:**
Scan agent memory `feedback_*.md` for patterns matching this component:
- Has SVG icons + border-radius → use threshold `0.92` (known rendering ceiling)
- Default → `0.95`

1. `tools/fetch-figma-screenshot.sh <fileKey> <nodeId> /tmp/figma-<name>.png`
   → copy to `tools/ScreenshotHistory/{ts}_figma_{name}.png`
2. Loop max 3 — exact command:
   ```bash
   tools/preview-component.sh res/<layer>/<name>/<name>.preview.js <ClassName> <width_dip> /tmp/figma-<name>.png
   ```
   Example: `tools/preview-component.sh res/widgets/button/button.preview.js Button 159 /tmp/figma-Button.png`
   - First arg: **path to `.preview.js` file** (not the main `.js`, not the directory)
   - Second arg: PascalCase component class name
   - Third arg: width in dip (integer, no units)
   - Fourth arg: path to Figma reference PNG
   Do NOT read the script to check its signature — use this format exactly.
3. PASS → copy preview screenshot → `tools/ScreenshotHistory/{ts}_code_{name}.png`
4. Fix applied → write `.claude/agent-memory/sciter-create-component/feedback_ssim_<topic>.md`
5. 3 failures → EC14 escalation (see `sequences/sciter-create-component.mmd`)

## Agent Memory

Seed on first run if `.claude/agent-memory/sciter-create-component/` is empty:

```
# SSIM Fix: typography
Root cause: font shorthand with var() is silently ignored in Sciter — font metrics
never applied → wrong element dimensions → SSIM fails on layout, not color.
Fix: replace font: var(--x) with @mixin name; (no parens, no comma)
Apply to: ALL components with text elements
```

## EC13 — Inline Primitive Onboarding (Sciter)

Same as `create-component` EC13 but inline creation uses Sciter rules + SSIM verify.

Show:
> "No Code Connect pattern found yet — one-time setup needed.
> Pick a **simple Sciter primitive** without child components (Button, Icon, Badge).
> Paste its Figma URL (component set ◆◆, not a variant ◆):"
