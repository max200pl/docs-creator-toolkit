---
name: sciter-create-component
description: "Sciter.js adapter for create-component. Implements adapter.generate() with dip/flow/@mixin rules and adapter.visual_verify() with preview-component.sh + SSIM 0.95 gate. Invoke instead of /create-component on Sciter.js projects."
scope: api
argument-hint: <component-name> [figma-url]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Sciter Create Component

> **Delta only:** this skill overrides adapter hooks from `create-component`. Follow `skills/create-component/SKILL.md` for all phases not listed here.
> **Flow delta:** `sequences/sciter-create-component.mmd` — shows Sciter-specific overrides only.
> **Workflow rules:** `rules/component-creation-workflow.md` — preconditions, EC handling, Tool Failure Pattern (unchanged).
> **Output format:** `rules/component-output-format.md` — naming, layout, registry schema (unchanged; Sciter CSS overrides below take precedence for CSS rules).

## Usage

```text
/sciter-create-component ButtonPrimary
/sciter-create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
```

## What This Skill Overrides

| Phase | Generic | Sciter override |
| ---- | ---- | ---- |
| Pre-Phase 2 | — | Load agent memory |
| Phase 2 Stream B | `adapter.generate()` | Sciter CSS/JS rules (dip, flow:, @mixin, __DIR__) |
| Phase 3 | `adapter.visual_verify()` | preview-component.sh + SSIM 0.95 + EC14 + ScreenshotHistory |
| Phase 5 | `adapter.cc_publish()` | same — discovered from primitive |

## Execution

### Step 0 — Pre-flight (generic + memory load)

Follow `create-component` Step 0 exactly, then additionally:

5. **Validate node type** — after parsing Figma URL, call `mcp__figma__get_design_context(nodeId, fileKey)`:
   - If response indicates a **variant** (has `variantProperties`, or is a child of a component set) → stop immediately:
     > "The provided node is a variant, not a component set. In Figma, right-click the parent ◆◆ component set in the layers panel → Copy link to selection. Provide that URL."
   - Standalone component or component set → proceed

6. Load agent memory:
   - Check if `.claude/agent-memory/sciter-create-component/` exists in the target project.
   - If the directory is absent or empty → create it and seed `feedback_ssim_typography.md` with this content:
     ```
     # SSIM Fix: typography
     Component: (seed — applies to all components)
     Symptom: SSIM score stuck below 0.95 — text regions show the biggest delta in diff images
     Root cause: font shorthand with var() is silently ignored in Sciter — font metrics are never applied.
     Wrong font-size/line-height causes text elements to have incorrect pixel dimensions,
     which shifts everything positioned relative to them. SSIM fails on layout/positioning, not color.
     Fix applied: replace `font: var(--font-body)` with `@mixin typography-name;` — no parens, no comma.
     Result: SSIM typically jumps from 0.70-0.80 to 0.95+ after applying correct @mixin
     Apply to: ALL components — check every text element in CSS before running preview
     ```
   - Read all `feedback_*.md` files → extract known fix patterns and apply proactively in Phase 2 code generation.

### Phase 1 — Context (unchanged + Sciter typography note)

Follow `create-component` Phase 1 exactly.

**Critical for Sciter — typography mixin matching (Agent 3):** typography sync is especially important here because wrong mixin = wrong font metrics = SSIM failure. After Agent 3 resolves mixins, verify each matched mixin exists in `typography_file` as `@mixin <name>` (not just as a comment or variable). If the mixin exists but the font file is not loaded (e.g. weight 600 .ttf missing) → flag this to the user before Phase 2: "Mixin `@font-md-semibold` exists but `SemiBold.ttf` is not loaded — use `@font-md-medium` instead or add the font file."

### Phase 1.5 — Decompose (unchanged)

Follow `create-component` Phase 1.5 exactly.

### Phase 2 — Implement (Sciter overrides)

**Stream A — Download assets:** unchanged.

**Stream B — Generate code (Sciter rules):**

Follow the generic stream except replace `adapter.generate()` with direct Sciter code generation using these rules:

**CSS generation rules:**

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Layout | `flow: horizontal` / `flow: vertical` | `display: flex` |
| Flex fill | `width: *` / `height: *` | `flex: 1` |
| Hidden overflow | `overflow: none` | `overflow: hidden` |
| Dimensions | all values in `dip` (1:1 from Figma px) | `px` values |
| Colors | CSS vars from token file only | hardcoded hex |
| Typography | `@mixin typography-name;` | `font` shorthand with `var()` |
| Mixin values | no commas inside `@mixin` | comma-separated values |
| Centering with `width: *` | add `vertical-align: middle` to EVERY child individually | `content-vertical-align: middle` on parent |
| `<img>` in `flow: vertical` | `display: block` + `horizontal-align: center` | default block |

**JS generation rules:**

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Component base | `class Name extends Element` | functional component |
| HTML attribute | `class="..."` | `className="..."` |
| Icon paths | `__DIR__ + "img/..."` | `"./img/..."` |
| Imports | must include `.js` extension | bare module paths |
| State hooks | native Sciter element methods | React hooks |
| Tailwind | never | — |

**Preview wrapper for flex components:**

If the component uses `height: *` or `width: *` — call `mcp__figma__get_metadata(parentNodeId)` to get the parent frame dimensions. Convert 1:1 to `dip`. Wrap the preview instance in a container with those exact dimensions.

Read applied memory fixes back and confirm they match what was generated.

### Phase 3 — Visual verify (Sciter implementation)

Follow `sequences/sciter-create-component.mmd` exactly.

1. Run `tools/fetch-figma-screenshot.sh <fileKey> <nodeId> /tmp/figma-<name>.png`
   — flags: `scale=2`, `use_absolute_bounds=true`
   Copy result to `tools/ScreenshotHistory/{ts}_figma_{name}.png`

2. Loop (max 3 attempts):
   - Run `tools/preview-component.sh <preview.js> <ComponentName> <width> /tmp/figma-<name>.png`
   - **Never close or kill the preview window** — leave open for user inspection
   - SSIM result via `find-component.py --direct`:
     - `>= 0.95` → PASS, exit loop
     - `< 0.95` → show user the diff + score + region description; apply targeted fix

3. After PASS:
   - Copy `/tmp/preview-screenshot.png` → `tools/ScreenshotHistory/{ts}_code_{name}.png`
   - If any fix was applied during retries → write agent memory:
     `.claude/agent-memory/sciter-create-component/feedback_ssim_<topic>.md`

4. After 3 failures — EC14 escalation (see `rules/component-creation-workflow.md` § EC14):
   - Level 1: user explains root cause → apply fix → re-run SSIM → if passes, write memory
   - Level 2: systematic issue → propose workflow doc change (show proposal, do NOT write to file)
   - Level 3: tool/script bug → structured bug report; accept with `status: needs-review`
   - In all cases: save code screenshot to ScreenshotHistory

### Phase 4 — Registry (unchanged)

Follow `create-component` Phase 4 exactly. Add `ssim_score` field with the achieved score (or `null` if Phase 3 was skipped due to EC14 Level 3).

### Phase 5 — Code Connect (unchanged)

Follow `create-component` Phase 5 exactly. Discover format from primitive.

## Agent Memory Convention

Agent memory lives in the **target project** at:

```text
<project-root>/.claude/agent-memory/sciter-create-component/
  feedback_ssim_typography.md   ← typography @mixin issues
  feedback_ssim_centering.md    ← icon/flex centering patterns
  feedback_ssim_<topic>.md      ← any other recurring fix
```

Memory file format:

```text
# SSIM Fix: <topic>
Component: <name that triggered this>
Symptom: SSIM score was <X> — <region> looked different
Root cause: <explanation from user or analysis>
Fix applied: <what changed in CSS/JS>
Result: SSIM reached <Y>
Apply to: all components with <pattern>
```

Load all memory files at Step 0. Apply matching fixes proactively in Phase 2 without waiting for SSIM failure.

## EC13 — Inline Primitive Onboarding (Sciter)

Same as `create-component` EC13, but the inline primitive creation flow uses Sciter rules:
- Phase 2: Sciter CSS/JS generation (dip, flow:, @mixin, __DIR__)
- Phase 3: SSIM 0.95 gate via `preview-component.sh` (same as regular Sciter flow)

Show the user:
> "No Code Connect pattern found yet — let's set it up first (one-time step).
> Pick a **simple Sciter primitive** — something without child components (Button, Icon, Badge).
> Paste its Figma URL (component set ◆◆, not a variant ◆):"

After primitive created with SSIM PASS → return to original component Phase 5, continue from step 2.

## What This Skill Does NOT Do

- Override Phase 0, 1, 1.5, 4, 5 from `create-component` — delegate unchanged
- Use Storybook or dev-server previewing — Sciter uses `preview-component.sh`
- Accept SSIM < 0.95 without EC14 escalation
- Auto-apply Level 2 workflow proposals — show for human review only
