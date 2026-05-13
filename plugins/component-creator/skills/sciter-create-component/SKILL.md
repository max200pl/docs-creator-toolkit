---
name: sciter-create-component
description: "Sciter.js adapter for create-component. Implements adapter.generate() with dip/flow/@mixin rules and adapter.visual_verify() with preview-component.sh + SSIM 0.95 gate. Invoke instead of /create-component on Sciter.js projects."
scope: api
argument-hint: "<component-name> [figma-url]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Sciter Create Component

> **Reference docs** (human reference only — do NOT attempt to Read these as files):
> `docs/reference-sciter-css.md`, `docs/reference-component-build.md`,
> `docs/reference-component-decompose.md`, `docs/reference-component-plan.md`,
> `docs/reference-figma-nodes.md`, `docs/reference-code-connect-sciter.md`

## Usage

```text
/sciter-create-component ButtonPrimary
/sciter-create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
```

## Execution

### ⚙ Version check — OUTPUT THIS AS YOUR VERY FIRST TEXT, before any tool call

```
[component-creator v0.0.23 | sciter-create-component]
```

Do not call any tools before outputting the version line above.

### Step 0 — Pre-flight (MANDATORY)

**0.1 TodoWrite** — call FIRST:
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

**0.2 Read project files** (parallel):
- `.claude/docs/reference-component-creation-template.md` — code conventions, layer placement
- `.claude/state/component-registry.json` — existing components
- `.claude/state/frontend-analysis.json` — `naming_conventions` + `styling_system`
- `.claude/docs/frontend-design-system.md` or `token_file` path — tokens + typography

**0.3 Agent memory** — use `Glob(".claude/agent-memory/sciter-create-component/**")` to list files. If empty → create these seed files:
- `feedback_ssim_typography.md`: font shorthand `var()` silently ignored → use `@mixin name;`
- `feedback_ssim_display_block.md`: `<button>` is inline-block → always add `display: block` first
- `feedback_ssim_centering.md`: `content-align` ignored when child uses `width:*` → use `vertical-align: middle` on each child
- `feedback_ssim_icon_in_flow.md`: `<img>` icons inside `flow: vertical` (or any non-inline parent flow) default to inline-block in Sciter — they ignore `content-horizontal-align: center` on parent and `vertical-align: middle` on themselves. **Always set `display: block` on the icon `<img>` AND on its container** when the icon must center within a `flow: vertical` button/menu-item/nav-item. Symmetric to `feedback_ssim_display_block` (which covers `<button>` containers) but for image children. SSIM symptom: icon offset top-left, label below correct — diff highlights icon position, not size.
- `feedback_ssim_state_render.md`: state-driven swap (any `js-src-swap` / `icon-prop` strategy chosen in interactive step) needs `this.componentUpdate()` after state mutation. Reactor will NOT auto-re-render on field assignment. Symptom: first SSIM pass succeeds (default state correct), but clicking active item doesn't swap — second SSIM run shows DOM unchanged. Verify event handler ends with `componentUpdate()` BEFORE side effects (`navigate()`, etc.). See `reference-sciter-icons.md#sciter-reactor-re-render-rule`.

**0.4** `mcp__figma__whoami` — on 401 stop.

**0.5** Parse URL: extract `fileKey` + `nodeId` (convert `-` → `:` in node-id).

**0.6 EC2 check** — if directory exists but no registry entry → prompt: overwrite / register as-is / cancel.

**0.7 Node type detection:**
1. `get_code_connect_suggestions(nodeId, fileKey)` → `mainComponentNodeId`
2. Classify:
   - `mainComponentNodeId == nodeId` → COMPONENT_SET or standalone COMPONENT → proceed
   - `mainComponentNodeId != nodeId`, node is COMPONENT with COMPONENT_SET parent → variant → redirect to `mainComponentNodeId`
   - node type is INSTANCE → drill via `componentId` to source COMPONENT/SET
   - FRAME / GROUP / VECTOR / TEXT → stop: "Not a component node"
3. Re-run with resolved nodeId after redirect/drill

---

### Phase 0.5 — Variant Analysis and Plan (wait for user confirmation before Phase 1)

1. `get_design_context(nodeId, fileKey, disableCodeConnect: true)` → full structure
2. Record default-state variant nodeIds for SSIM
3. **Detect all child instances recursively:**
   - Parse response for COMPONENT/INSTANCE children
   - If not visible → `get_metadata(nodeId)` → children array → `get_design_context` per child
   - For each INSTANCE: follow `componentId` to SOURCE → recurse into SOURCE children
   - For each COMPONENT_SET found (including asset sets): call `get_design_context(nodeId, fileKey, disableCodeConnect: true)` to extract **all property axes** (type/state/effect) + all variant nodeIds
   - **Asset sets also have effect axes** (e.g. hover) — extract them too, then decide: if hover variant is visually identical to another state → CSS-only, no extra SVG; if visually distinct → separate SVG file
   - Repeat N levels deep until full tree built
   - Classify: asset set (pure image variants) / real component / layout-only
   - Registry check: EXACT MATCH → reuse | NOT FOUND → must build first
4. Derive component name → always confirm with user (Figma layer names may have typos)
5. Asset set check: if all variants are pure image nodes with no layout/behavior → not a component, download icons to parent `img/`
6. Registry check by name or `figma_node_id`
7. Sub-component check: if name = `<ParentName><Suffix>` and parent in registry → offer placement inside `<parent>/ui/`
8. Layer detection: read `## Component Placement Rules` from `reference-component-creation-template.md`
9. Show plan in this format:

```
Component: <name> (nodeId: <id>)

Component table:
  ┌─────────────────┬────────────┬──────────┬──────────────┬──────────────────────┬───────────────┬────────────────┐
  │ Component       │ Figma ID   │ Axis     │ Values       │ Implementation       │ Visual change │ Status         │
  ├─────────────────┼────────────┼──────────┼──────────────┼──────────────────────┼───────────────┼────────────────┤
  │ <name>          │ <nodeId>   │ type     │ <v1>,<v2>    │ JS prop              │ layout/icon   │ BUILD NOW      │
  │                 │            │ state    │ <s1>,<s2>    │ JS prop/CSS class    │ color/icon    │                │
  │                 │            │ effect   │ hover        │ CSS :hover           │ bg tint       │                │
  ├─────────────────┼────────────┼──────────┼──────────────┼──────────────────────┼───────────────┼────────────────┤
  │ <child>         │ <nodeId>   │ state    │ <s1>,<s2>    │ prop/CSS class       │ icon swap     │ ❌ build first │
  │                 │            │ effect   │ hover        │ CSS :hover           │ highlight     │ local ui/      │
  ├─────────────────┼────────────┼──────────┼──────────────┼──────────────────────┼───────────────┼────────────────┤
  │ <asset-set>     │ <nodeId>   │ type×st  │ N variants   │ distinct visuals → SVG │ —           │ ASSET SET      │
  │                 │            │ ×effect  │              │ same visual → CSS only │               │ download only  │
  └─────────────────┴────────────┴──────────┴──────────────┴──────────────────────┴───────────────┴────────────────┘

  state = condition (active/disabled) | effect = visual reaction (hover/shadow/transition)

Layer: <path>  (Component Placement Rules)
Build order (bottom-up):
  1. <asset-set> (<nodeId>) — N SVG → <layer>/<name>/img/
  2. <child> (<nodeId>) — ❌ build first / ✅ reuse from <path>
  3. <this> (<nodeId>) — BUILD NOW

Files to be created:
  <layer>/<name>/
    <name>.js / <name>.css / <name>.preview.js / <name>.figma.ts
    img/<icon>-<state>.svg  (one per actual Figma variant)
    ui/<sub>.js / <sub>.css  (if local children)

Token delta:
  + --<name>: <value>  |  = --<existing> (reused)

SSIM plan:
  ✦ <type>/Default/Default — nodeId: <id> — width: <W>dip [× height: <H>dip for single]
  threshold: 0.92 (SVG icons) | 0.95 default

Confirm →
```

---

## Execution — build order bottom-up

After user confirms:
- Asset sets → download all SVG variants to `img/` immediately (before Phase 2B)
- Component ✅ in registry → skip build, import from `path`
- Component ❌ not in registry → STOP: "Build `<Name>` first, then re-run"
- This component → run Phases 1–5

---

## Phase 1 — Token sync

1. `get_variable_defs(nodeId, fileKey)` → compare against token file by hex value
2. Conflict rules: same-name+diff-value → update local; diff-name+same-value → flag rename; new → add `--{category}-{variant}`
3. EC11: no Figma Variables → prompt: extract as tokens OR write raw `/* unmapped-token */`

## Phase 1.5 — Decompose (if composite)

- Private child → `<slice>/ui/<sub>.js`
- Reusable (2+ parents) → `shared/ui` (flag, don't force)
- Layout wrapper (no logic/states) → flatten into parent

## Phase 2A — Download SVG Assets

> Icon rules: see `@plugins/component-creator/docs/reference-sciter-icons.md` (Sciter methods) and `@.claude/docs/reference-icon-connection.md` (project's detected pattern).

For each icon from Phase 0.5 asset set (actual Figma variants only):
1. `tools/fetch-figma-svg.sh <fileKey> <variantNodeId> <layer>/img/<icon>-<state>.svg`
2. On 404 → `mcp__figma__get_screenshot(nodeId)` → save as `.png`
3. **If project's `icon_pattern.color_change == "svg-swap-display"`** (read from `@.claude/docs/reference-icon-connection.md`) — ensure a pair of SVG files is downloaded per state (default + active, or normal + active per project convention in `icon_pattern.path_convention`). If Figma exposes only one variant but the project pattern requires a pair, fetch the closest matching variant and rename per project's state suffix convention; flag in component header-comment.

Icon naming algorithm: see `@plugins/component-creator/docs/reference-sciter-icons.md#icon-naming-algorithm` — do not re-implement.

---

## Phase 2B — Sciter CSS + JS

> Icon rules: read `@plugins/component-creator/docs/reference-sciter-icons.md` AND `@.claude/docs/reference-icon-connection.md` before any icon-related code emission.

**CSS rules:**

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Layout | `flow: horizontal` / `flow: vertical` | `display: flex` |
| Flex fill | `width: *` / `height: *` | `flex: 1` |
| Overflow | `overflow: none` | `overflow: hidden` |
| Units | `dip` (1:1 Figma px) | `px` |
| Colors | CSS vars only | hardcoded hex |
| Typography | `@mixin name;` | `font: var()` |
| Centering | `vertical-align: middle` on each child | `content-vertical-align` on parent |
| Button root | `display: block` first | inline-block default (adds 2px gap) |
| Pixel-perfect | if token ≠ Figma value → raw `dip` | token reuse over accuracy |

**JS rules:**

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Base class | `class Name extends Element` | functional |
| HTML attr | `class="..."` | `className` |
| Imports | include `.js` extension | bare paths |
| Disabled | `state-disabled={this.disabled}` | `disabled=` |

> Icon path / connection method — handled by the **Icon Connection** sub-section below (interactive). Do not hard-code `__DIR__ + "img/..."` here.

### Icon Connection — interactive strategy choice

**When this runs:** ONLY if Phase 0.5 asset set is non-empty (component contains icons). Otherwise skip this sub-section.

**Step 1 — Read sources:**

- `@.claude/docs/reference-icon-connection.md` — project's detected `icon_pattern` (connection, color_change, wrapper_component, notes)
- `@.claude/docs/reference-component-creation-template.md` `## Icon usage patterns` section — agent-facing summary
- `@plugins/component-creator/docs/reference-sciter-icons.md#sciter-official-recommended-method` — fallback baseline if user opts for official Sciter recommendation

**Step 2 — Present options via `AskUserQuestion`:**

Render preview before the question (replace `<placeholders>` with values from the JSON):

```
Detected project pattern (from reference-icon-connection.md):
  Connection:   <icon_pattern.connection>
  Color change: <icon_pattern.color_change>
  Wrapper:      <wrapper_component.name or "none">

Sciter official recommendation (from reference-sciter-icons.md):
  Connection:   <official.connection — e.g. "css-foreground-icon" or "css-foreground-image">
  Color change: <official.color_change — e.g. "css-fill" or "css-token-fill">
```

Question: `"Какую стратегию использовать для компонента <ComponentName>?"`

Options (bounded — only these two):

| Header | Label | Description |
| ---- | ---- | ---- |
| Project | Follow project pattern (recommended) | Apply detected pattern. Header-comment: `// Icon pattern follows project convention — see .claude/docs/reference-icon-connection.md` |
| Sciter | Use Sciter official recommendation | Apply the official method from `reference-sciter-icons.md#sciter-official-recommended-method`. Header-comment: `// Icon pattern: Sciter official recommendation — see reference-sciter-icons.md#sciter-official-recommended-method` |

**Auto-default rules:**

- `icon_pattern.connection != null` AND `notes` is empty → default = **Project**
- `icon_pattern.connection == null` (greenfield) → default = **Sciter**
- `icon_pattern.notes` contains a conflict / non-recommended warning → default = **Project**, but append the warning verbatim to that option's description so the user sees it before choosing
- `icon_pattern.color_change ∈ { "js-src-swap", "svg-swap-display" }` → keep the default per rules above, but append to the **Project** option's description: `"⚠ Detected swap-based color-change (<value>). Sciter-idiomatic alternatives are CSS-pseudo-driven (css-fill / css-token-fill / css-filter). See reference-sciter-icons.md § Color-Change Methods. Pick 'Sciter' if you want to migrate this component to the recommended path."` This makes the trade-off visible at decision time without overriding the user's project-consistency intent.

> Rationale for no "Custom" option: free-text strategy cannot be applied deterministically by the generator. If the user needs an off-pattern approach for a specific component, they should choose "Sciter" (which uses the official method) or accept the generated code and edit afterwards. A deliberate divergence from project pattern is a manual decision, not a templated one.

**Step 3 — Apply choice:**

1. Look up the chosen `(connection, color_change)` pair in `reference-sciter-icons.md#decision-matrix`
2. If choice == **Project** AND `wrapper_component.name` is populated → emit `<WrapperName name={icon} state={state} />` instead of raw markup
3. Generate code per the matrix cell
4. Prepend the appropriate header-comment (per option's Description above)
5. Record the choice in the component's registry entry under field `icon_strategy: project | sciter-official` — `update-component` reads this to maintain consistency on subsequent updates

**Also:** write `<name>.preview.js` (full grid, all types) + add `@import` to main CSS entry.

---

## Phase 3 — SSIM

Threshold: scan agent memory → SVG+border-radius → `0.92` | default → `0.95`

For each type (COMPONENT_SET) or once (single COMPONENT):
1. Create `<name>.preview-<type>.js` (temp):
   - Fixed size → render directly
   - `width:*` or `height:*` → wrap: `<div style="width:<W>dip; height:<H>dip;"><Name /></div>`
2. `tools/fetch-figma-screenshot.sh <fileKey> <variantNodeId> /tmp/figma-<type>.png` (keep in /tmp/ only)
3. Ask user: "Close previous preview window → confirm when ready"
4. `tools/preview-component.sh --js <name>.preview-<type>.js <width> /tmp/figma-<type>.png`
5. Read SSIM from stdout → on pass save to ScreenshotHistory; on fail fix → retry (max 3)
6. Delete `*.preview-<type>.js` after all types pass

Failure diagnosis order: size → padding/margins → element positions → colors (never start with background)

On 3 failures → EC14: show diff, ask user to explain, save fix to agent memory.

---

## Phase 4 — Registry

Write to `.claude/state/component-registry.json` (never to markdown).
Validate against `rules/registry-schema.md` before writing.
Key fields: `figma_node_id` = component set nodeId (not variant), `uses[]` = child primitive names, `states[]` = Figma state axis values (not hover), `ssim_score` = min across all types.

## Phase 5 — Code Connect

1. `get_code_connect_map(nodeId, fileKey)` → if mapping exists show old→new, ask to replace
2. Use `.figma.ts` (not `.figma.js`) — CLI transpiles `.ts→.js`
3. Project must NOT have `"type": "module"` in `package.json`
4. `figma connect publish --dry-run` → publish if OK
5. EC13: no primitive found → prompt user for simple primitive URL, run onboarding inline
