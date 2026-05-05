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

## Usage

```text
/sciter-create-component ButtonPrimary
/sciter-create-component LeftPanel https://figma.com/design/FILE?node-id=1:234
```

## Execution

**First — show the full plan.** Call TodoWrite with all items as `pending` before doing any work:

```
☐ Step 0    — Pre-flight (docs + Figma token + variant check + agent memory)
☐ Phase 1   — Context: Figma design + Reuse check + Token/typography sync
☐ Phase 1.5  — Decompose (if composite)
☐ Phase 2A  — Download assets (SVG icons)
☐ Phase 2B  — Generate Sciter CSS + JS + preview + @import
☐ Phase 3   — Visual verify: fetch Figma screenshot + preview-component.sh + SSIM
☐ Phase 4   — Registry upsert (with ssim_score)
☐ Phase 5   — Code Connect
```

Mark each item `in_progress` before starting, `completed` immediately after finishing.

**Then — follow `sequences/sciter-create-component.mmd` for Sciter overrides, `sequences/create-component.mmd` for everything else.**

## What to Read and When

| File | Read at | Purpose |
| ---- | ---- | ---- |
| `reference-component-creation-template.md` | Step 0 | **Primary** code pattern — file structure, Sciter conventions |
| `frontend-analysis.json` | Step 0 | `naming_conventions`, `styling_system` |
| `frontend-design-system.md` | Step 0 | `token_file`, `typography_file` paths |
| `component-registry.json` | Phase 1 Agent 2 | Reuse check only |
| Existing component files | **Phase 5 only** | Code Connect format from primitive |

**Never read an existing component (e.g. `button-feedback`) as a code generation reference.** Use `reference-component-creation-template.md` as the canonical pattern. Existing components are read only in Phase 5 to discover Code Connect format.

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

1. `tools/fetch-figma-screenshot.sh <fileKey> <nodeId> /tmp/figma-<name>.png`
   → copy to `tools/ScreenshotHistory/{ts}_figma_{name}.png`
2. Loop max 3: `tools/preview-component.sh <preview.js> <Name> <width> /tmp/figma-<name>.png`
   → SSIM >= 0.95 = PASS; < 0.95 = show diff, fix, retry
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
