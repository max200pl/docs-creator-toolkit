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
[component-creator v0.0.9 | sciter-create-component]
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

1. `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` → all variant property combinations + **each variant's own nodeId**
2. Record each default-state variant's nodeId for SSIM (e.g. sec/default=314:4128, prim/default=314:4127, with-icon/default=314:4149)
3. For each variant: note what differs (colors, layout, states)
4. Check registry for component name or `figma_node_id` — check **`.claude/state/component-registry.json`** only, NOT markdown files
5. **Derive layer and path from `reference-component-creation-template.md`** (already loaded in Step 0.2):
   - Find the row matching `Widget directory` or `Component file` in the file conventions table
   - Extract the path pattern, e.g. `res/widgets/<widget-name>/`
   - Substitute `<widget-name>` with the kebab-case component name
   - **Do NOT guess between `widgets/` and `shared/ui/`** — use only what the template says
6. Show plan:

```
Component Set: <name> (N variants)

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
Layer: <exact path from reference-component-creation-template.md — Widget directory row, name substituted>

Files to be created:
  <layer>/<name>.js          — component class
  <layer>/<name>.css         — styles
  <layer>/<name>.preview.js  — full grid (all types, for Space overlay)
  <layer>/<name>.figma.ts    — Code Connect
  <layer>/img/<icon>.svg     — (if icon variant present)
  (<layer> = path resolved above from reference-component-creation-template.md)

Token delta (new tokens to add to tokens.css):
  + --<token-name>: <value>   — <what it maps to in Figma>
  = --<existing>              — already exists, reused as-is
  (none) if all colors already covered by existing tokens

SSIM verification plan (Phase 3):
  ✦ <type1> / state:Default / effect:Default — nodeId: <id> — width: <N>dip
  ✦ <type2> / state:Default / effect:Default — nodeId: <id> — width: <N>dip
  ✦ <type3> / state:Default / effect:Default — nodeId: <id> — width: <N>dip
  threshold: <0.92 if SVG icons present | 0.95 default>
  state:hover / state:disable / effect:* — CSS-only, not SSIM-testable (verified visually via Space overlay)

Confirm variant selection →
```

6. **Wait for explicit user confirmation before Phase 1.**

---

## Phase 2A — Download SVG Assets

For each icon variant detected in Phase 0.5:

```bash
tools/fetch-figma-svg.sh <fileKey> <iconNodeId> <layer>/img/<icon>.svg
```

**If `fetch-figma-svg.sh` returns 404 (asset URL expired):**
Figma CDN pre-signed URLs expire in ~10-15 min. Fallback:
1. `mcp__figma__get_screenshot(nodeId: <iconNodeId>, fileKey)` — fetches a fresh PNG render
2. Save as `<layer>/img/<icon>.png` instead of `.svg`
3. Update JS reference: `__DIR__ + "img/<icon>.png"`

Do not retry the expired URL — it will not recover. Use the screenshot fallback immediately.

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
| `<button>` block | `display: block` on root element | default inline-block — adds 2px line-height gap below button, inflating body height |

### adapter.generate() — JS rules

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Base class | `class Name extends Element` | functional component |
| HTML attr | `class="..."` | `className="..."` |
| Icon paths | `__DIR__ + "img/..."` | `"./img/..."` |
| Imports | must include `.js` extension | bare paths |
| State | native Sciter element methods | React hooks |

### adapter.visual_verify() — SSIM

**Component set preview + SSIM strategy:**

`preview.js` — shows all variants as a grid (for visual inspection, Space overlay).
SSIM — runs only for **default state of each type**, in parallel.

**Why not full grid SSIM:** hover/disabled are CSS states that can't be pixel-perfectly forced in a static preview. Comparing forced states against Figma's renderer produces false SSIM failures.

**Why not one canonical variant:** each type (sec, prim, with-icon) has different visual weight — all three need independent verification.

**Implementation:**

1. `<name>.preview.js` — full grid for human review only (NOT used for SSIM):
   ```js
   // one row per type — all types visible for Space overlay inspection
   <Button type="sec" label="Not Now" />
   <Button type="prim" label="Update" />
   <Button type="with-icon" label="Not Now" />
   // hover/disabled states inspected manually via Space overlay
   ```

2. SSIM — **one separate run per type**. Never run SSIM against the full-grid `preview.js`.

   ⚠️ Never use the component set nodeId for SSIM. A component set screenshot includes all variants in a grid — its height is N× taller than a single-variant preview. The comparison tool scales both to the same size, compressing the Figma screenshot and making overlay useless.

   Always match: **one Figma screenshot of one variant ↔ one temporary single-variant preview file**.

   **Step A — For each type, create a temporary single-variant preview file:**
   ```js
   // <name>.preview-<type>.js  (temporary — delete after SSIM passes)
   import { Button } from "./button.js";
   document.body.style.background = "#d9d9d9";
   document.body.content(<Button type="sec" label="Not Now" />);
   ```
   Repeat for every type.

   **Step B — Fetch Figma screenshot per type** using the default-state variant nodeId recorded in Phase 0.5:
   ```bash
   tools/fetch-figma-screenshot.sh <fileKey> <sec_default_nodeId>       /tmp/figma-sec.png
   tools/fetch-figma-screenshot.sh <fileKey> <prim_default_nodeId>      /tmp/figma-prim.png
   tools/fetch-figma-screenshot.sh <fileKey> <withicon_default_nodeId>  /tmp/figma-with-icon.png
   ```

   **Step C — Run SSIM per type** using `--js` mode (loop max 3 per type):

   For each type, the sequence is:
   1. **STOP before running the script** — ask the user to confirm all previous Sciter preview windows are closed
   2. Only after user confirms → run `preview-component.sh`
   3. The script opens the window, waits for it to appear, then auto-captures

   Ask before EACH type run:
   > "Close the previous preview window → confirm when ready"

   Only proceed after explicit user confirmation ("есть", "готово", "да"). Do NOT run the script speculatively — a stale open window will be captured instead of the new one.

   ```bash
   tools/preview-component.sh --js res/widgets/button/button.preview-sec.js       159 /tmp/figma-sec.png
   tools/preview-component.sh --js res/widgets/button/button.preview-prim.js      159 /tmp/figma-prim.png
   tools/preview-component.sh --js res/widgets/button/button.preview-with-icon.js 159 /tmp/figma-with-icon.png
   ```
   - `--js` flag MUST be first — standard mode derives path as `<name>.preview.js` and will not find `preview-<type>.js`
   - Second arg: path to the per-type preview file (absolute or relative to project root)
   - Third arg: width in dip (integer, no units) — use the variant's own width from Phase 0.5
   - Fourth arg: path to per-type Figma PNG
   Do NOT read the script to check its signature — use this format exactly.

   ⚠️ **Window reuse bug:** `preview-component.sh` finds the first open window named "Preview". If the previous type's window is still open, the script captures it instead of the new one → wrong SSIM. **Before each type run: close the previous preview window (red button).** If unsure, run `pkill -f sciterjsMacOS` to kill all Sciter windows.

   ⚠️ **Figma PNGs must stay in `/tmp/`:** `find-component.py save_history()` clears ALL PNGs in ScreenshotHistory on every run. Never store Figma reference PNGs there — deleted by the next SSIM run. Always use `/tmp/figma-<type>.png`.

   **Step D — Cleanup:** after all types pass, delete the temporary `*.preview-<type>.js` files.

3. ScreenshotHistory — save `_code_` and `_figma_` for each verified type.

**Resolve adaptive threshold before running:**
Scan agent memory `feedback_*.md` for patterns matching this component:
- Has SVG icons + border-radius → use threshold `0.92` (known rendering ceiling)
- Default → `0.95`

- PASS → copy preview screenshot → `tools/ScreenshotHistory/{ts}_code_{name}-<type>.png`
- Fix applied → write `.claude/agent-memory/sciter-create-component/feedback_ssim_<topic>.md`
- 3 failures on any type → EC14 escalation (see `sequences/sciter-create-component.mmd`)

## Phase 4 — Registry (MANDATORY)

Write to **`.claude/state/component-registry.json`** — the JSON file.

⛔ NEVER write to `.claude/docs/reference-component-registry.md` — that is a read-only generated markdown view, not the source of truth.

Follow `rules/registry-schema.md` strictly. Before writing, validate the new entry:
- All keys must be in the allowed list from `registry-schema.md`
- `path` must be the `.js` file, not a directory
- `figma_node_id` must be the **component set** nodeId (captured in Phase 0.5), not a variant nodeId
- `variants`: all implemented type names (e.g. `["sec", "prim", "with-icon"]`)
- `states`: Figma `state` axis values with distinct static designs (e.g. `["Default", "disable"]`) — exclude CSS-only interaction states (hover) that have no separate Figma frame; values vary per component
- `ssim_score`: minimum score across all parallel SSIM runs
- `status`: `"in-progress"` at Phase 4; updated to `"done"` after Phase 5

If any field violates the schema → stop and show `REGISTRY SCHEMA VIOLATION: <field>` before writing.

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
