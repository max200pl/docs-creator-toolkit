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
[component-creator v0.0.14 | sciter-create-component]
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

**0.2 Read docs** (parallel — only what's needed before Step 0.6):
- `reference-component-creation-template.md` — code conventions, layer placement
- `component-registry.json` — existing components (needed for EC2 check)
- `frontend-analysis.json` — extract `naming_conventions` + `styling_system`
- `frontend-design-system.md` — extract `token_file` + `typography_file`

**Do NOT read any existing component files (JS/CSS/figma.ts) or individual registry entries as templates or code patterns.** Use only:
- `reference-component-creation-template.md` → code conventions
- `rules/registry-schema.md` → registry entry format
- `rules/component-output-format.md` → naming, file layout
Existing components (ButtonFeedback, etc.) are read ONLY in Phase 5 to discover Code Connect format from the primitive's `.figma.ts` file.

**0.3 Agent memory** — Read `docs/reference-sciter-agent-memory.md` (seed templates). Check `.claude/agent-memory/sciter-create-component/`. If empty → seed from the templates.

**0.4 Figma token** — `mcp__figma__whoami`. On 401 → stop (EC5).

**0.5 Parse URL** — extract `fileKey` + `nodeId` from argument (convert `-` → `:` in node-id).

**0.6 EC2 check** — if directory `<name>/` exists (even empty) and no registry entry → prompt: overwrite / register as-is / cancel.

**0.7 Node type detection** — Read `docs/reference-figma-nodes.md` (full type table + classification logic).

Call `mcp__figma__get_code_connect_suggestions(nodeId, fileKey)` → get `mainComponentNodeId`.

**Classification:**

| Condition | Node type | Action |
| ---- | ---- | ---- |
| `mainComponentNodeId == nodeId` | `COMPONENT_SET` or standalone `COMPONENT` | ✅ Proceed to Phase 0.5 |
| `mainComponentNodeId != nodeId` AND node is a `COMPONENT` whose parent is `COMPONENT_SET` | Variant (◆ inside ◆◆) | 🔄 Redirect: use `mainComponentNodeId` as new nodeId |
| `mainComponentNodeId != nodeId` AND node type is `INSTANCE` | Instance placed on canvas | ⬆ Drill: follow `componentId` → find source `COMPONENT` → check if parent is `COMPONENT_SET` → use set if exists |
| node type is `FRAME` / `GROUP` / `VECTOR` / `TEXT` / other | Not a component | ❌ Stop |

**Redirect message (variant case):**
> "Node `<nodeId>` is a **variant** (◆), not a component set (◆◆).
> Correct node: `<mainComponentNodeId>` — use this URL:
> `https://www.figma.com/design/<fileKey>?node-id=<mainComponentNodeId>`"

**Stop message (non-component):**
> "This is a `<type>` node, not a component. Select a component (◆) or component set (◆◆) in Figma."

After redirect or drill — re-run Step 0.7 with the resolved nodeId.

---

### Phase 0.5 — Variant Analysis and Plan (MANDATORY — do not start Phase 1 without user confirmation)

1. `mcp__figma__get_design_context(nodeId, fileKey, disableCodeConnect: true)` → full structure: variant combinations, each variant's own nodeId, **all child component instances** (nested components)
2. Record each default-state variant's nodeId for SSIM
3. **Detect ALL child component instances** — scan the design context for nested COMPONENT/INSTANCE nodes:
   - For each child: note name, nodeId, variants/states
   - Check registry: EXACT MATCH → reuse; NOT FOUND → must build first
   - Detect asset sets among children (see `docs/reference-component-decompose.md` § Asset Set Detection)
   - Build **full dependency tree** (bottom-up order)
4. For each variant: note what differs (colors, layout, states)
4. **Derive component name from Figma layer name** → convert to PascalCase → **always show to user and ask to confirm or correct:**
   > "Component name derived from Figma: `<Name>` — confirm or enter correct name:"
   Do NOT proceed with the name silently. Figma layer names may contain typos.
5. **Asset set detection** — before treating as a component, check if all variants are pure image/icon nodes with no layout or behavior (see `docs/reference-component-decompose.md` § Asset Set Detection):
   - If asset set → do NOT create a component directory; download icons to parent's `img/`; stop here
   - If real component → continue
6. Check registry for component name or `figma_node_id` — check **`.claude/state/component-registry.json`** only, NOT markdown files
7. **Detect sub-component placement** — check registry for a parent whose name is a prefix of this component name (see `docs/reference-component-decompose.md` § Sub-Component Detection).
   Show both options in plan: (a) top-level or (b) sub-component inside parent `ui/`. User confirms.
7. **Detect layer** — read `## Component Placement Rules` from `reference-component-creation-template.md` (already loaded in Step 0.2). Use the rule that matches this component. If section absent → ask user.
   Show in plan: `Layer: <path>  (from Component Placement Rules)`
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

Child components detected:
  ✦ <ChildName> — nodeId: <id> — <in registry ✅ reuse | NOT in registry ❌ build first>
  ✦ <IconSetName> — asset set → download to <layer>/<name>/img/

Build order (bottom-up):
  1. <deepest child> — <status>
  2. <next child>    — <status>
  3. <this component> — BUILD NOW

⚠ Components marked ❌ must be built first. Cannot proceed until all dependencies are in registry.

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

  — If COMPONENT_SET (multiple types/variants):
  ✦ <type1> / state:Default / effect:Default — nodeId: <id> — width: <W>dip
  ✦ <type2> / state:Default / effect:Default — nodeId: <id> — width: <W>dip
  ✦ <type3> / state:Default / effect:Default — nodeId: <id> — width: <W>dip
  One run per type. threshold: <0.92 if SVG icons | 0.95 default>

  — If single COMPONENT (no variant axis):
  ✦ <ComponentName> — nodeId: <id> — width: <W>dip × height: <H>dip
  One run, full component. threshold: <0.92 if SVG icons | 0.95 default>

  state:hover / effect:* — CSS-only, verified visually via Space overlay

  ⚠️ width + height = component frame absoluteBoundingBox from get_design_context
  NOT the size of child nodes inside (icons in img/ are irrelevant to SSIM dimensions)

Confirm variant selection →
```

6. **Wait for explicit user confirmation before Phase 1.**

---

## Phase 1 — Context: Figma + Reuse + Token sync

Read `docs/reference-token-sync.md` before comparing tokens.

> Phase 1 runs parallel to Phase 0.5 confirmation wait — start token sync after showing plan.

## Phase 1.5 — Decompose (if composite)

Read `docs/reference-component-decompose.md` — decompose rules, child classification, build order, EC12.

## Phase 2A — Download SVG Assets

Read `docs/reference-component-decompose.md` § Icon Naming Algorithm before naming icon files.

**Always try SVG first.** Never plan PNG download upfront — PNG is fallback only.

For each icon variant detected in Phase 0.5:

```bash
# Step 1 — always try SVG
tools/fetch-figma-svg.sh <fileKey> <iconNodeId> <layer>/img/<icon>.svg
```

**Only if `fetch-figma-svg.sh` returns 404 (asset URL expired):**
```bash
# Step 2 — fallback to PNG screenshot
mcp__figma__get_screenshot(nodeId: <iconNodeId>, fileKey)
# Save as <layer>/img/<icon>.png
# Update JS: __DIR__ + "img/<icon>.png"
```

In Phase 0.5 plan — always list icons as `.svg`. Change to `.png` only after actual 404.

---

## Phase 2B — Generate Sciter CSS + JS + preview + @import

Read `docs/reference-sciter-css.md` before writing any CSS.

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
| Pixel-perfect sizing | Figma value = source of truth; if token value ≠ Figma → use raw `dip` | sacrificing accuracy for token reuse |

### adapter.generate() — JS rules

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Base class | `class Name extends Element` | functional component |
| HTML attr | `class="..."` | `className="..."` |
| Icon paths | `__DIR__ + "img/..."` | `"./img/..."` |
| Imports | must include `.js` extension | bare paths |
| State | native Sciter element methods | React hooks |
| Disabled attr | `state-disabled={this.disabled}` | `disabled={this.disabled}` — HTML attr, not Sciter state system |

### adapter.visual_verify() — SSIM (Phase 3)

Read `docs/reference-component-build.md` before running any preview or SSIM commands.

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

   If component uses `width: *` or `height: *` — wrap in container with real dimensions from Figma (see `docs/reference-component-build.md` § Flex Container Wrapping).

   ```js
   // <name>.preview-<type>.js  (temporary — delete after SSIM passes)
   import { <ClassName> } from "./<name>.js";
   document.body.style.background = "#d9d9d9";
   // Fixed size → render directly:
   //   document.body.content(<ComponentName prop="value" />);
   // Flex sizing (width:* or height:*) → wrap with parent dims from Figma:
   //   document.body.content(<div style="width:<W>dip; height:<H>dip;"><ComponentName /></div>);
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

**When SSIM fails — diagnose in this order:**
1. **Size** — does the button bounding box match Figma? (width × height in px)
2. **Padding / margins** — is there extra space around the component? (body margin, display:block gap)
3. **Element positions** — is text/icon centered correctly?
4. **Colors** — only after layout is correct

Never start diagnosis from background color. Background mismatch is a symptom, not a root cause — fix layout first.

## Phase 4 — Registry (MANDATORY)

Write to **`.claude/state/component-registry.json`** — the JSON file.

⛔ NEVER write to `.claude/docs/reference-component-registry.md` — that is a read-only generated markdown view, not the source of truth.

Follow `rules/registry-schema.md` strictly. Before writing, validate the new entry:
- All keys must be in the allowed list from `registry-schema.md`
- `path` must be the `.js` file, not a directory
- `figma_node_id` must be the **component set** nodeId (captured in Phase 0.5), not a variant nodeId
- `variants`: all implemented type names (e.g. `["sec", "prim", "with-icon"]`)
- `states`: Figma `state` axis values with distinct static designs (e.g. `["Default", "disable"]`) — exclude CSS-only interaction states (hover) that have no separate Figma frame; values vary per component
- `uses`: names of primitive components used by this component — match Figma child node IDs against `figma_node_id` entries in registry; `[]` if no primitives used
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

# SSIM Fix: button display block
Root cause: <button> in Sciter is display:inline-block by default — adds 2px
line-height gap below the element, inflating body height vs Figma.
Fix: add display: block as the FIRST property on the root .button rule.
Apply to: ALL button-like components that use <button> as root element.
Generate this from the start — do not wait for SSIM failure to discover it.

# SSIM Fix: text centering in flow:horizontal
Root cause: content-align / content-horizontal-align on parent doesn't center
text inside a span child in Sciter flow layout.
Fix: on the label span — width: * (fills available space) + text-align: center
+ vertical-align: middle. Do NOT use content-align on the parent.
Apply to: ALL button-like components with centered label text.
Generate this from the start — do not wait for SSIM failure to discover it.
```

## Phase 5 — Code Connect (Sciter specifics)

- Use **`.figma.ts`** extension, NOT `.figma.js` — CLI transpiles `.ts → .js`; `.figma.js` is sent raw and `import` breaks in Figma runtime
- Project must NOT have `"type": "module"` in `package.json` — breaks CLI transpilation
- Always call `get_code_connect_map(nodeId, fileKey)` BEFORE generating — if mapping exists, show old→new diff and ask user to replace or keep

## EC13 — Inline Primitive Onboarding (Sciter)

Same as `create-component` EC13 but inline creation uses Sciter rules + SSIM verify.

Show:
> "No Code Connect pattern found yet — one-time setup needed.
> Pick a **simple Sciter primitive** without child components (Button, Icon, Badge).
> Paste its Figma URL (component set ◆◆, not a variant ◆):"
