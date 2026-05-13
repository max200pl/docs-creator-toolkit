---
description: "Seed content for Sciter agent memory files. sciter-create-component writes these on first run if the memory directory is empty."
---

# Agent Memory Seed — Sciter Adapter

`sciter-create-component` reads from `.claude/agent-memory/sciter-create-component/` in the target project before generating code. On first run (empty directory), it creates the seed files below to pre-load known recurring fixes.

## Seed: `feedback_ssim_typography.md`

```markdown
# SSIM Fix: typography
Component: (seed — applies to all components)
Symptom: SSIM score stuck below 0.95 despite correct layout — text regions show the biggest delta in diff images
Root cause: font shorthand with var() is silently ignored in Sciter — font metrics are never applied. Wrong font-size/line-height causes text elements to have incorrect pixel dimensions, which shifts everything positioned relative to them. SSIM fails on layout/positioning, not color.
Fix applied: replace `font: var(--font-body)` with `@mixin typography-name;` (no parens, no comma, ends with semicolon). Map each Figma text style to the matching @mixin from the typography file.
Result: SSIM typically jumps from 0.70-0.80 to 0.95+ after applying correct @mixin
Apply to: ALL components — check every text element in CSS before running preview
```

## Seed: `feedback_ssim_svg_icon_border.md`

```markdown
# SSIM Fix: SVG icon + rounded border ceiling
Component: (seed — applies to all components with SVG icons + border-radius)
Symptom: SSIM stuck at ~0.942 despite visually perfect overlay — user confirms alignment is correct
Root cause: Engine-level anti-aliasing differences between Figma renderer and Sciter:
  1. Complex SVG icons (many curved paths) — pixel-level anti-aliasing differs
  2. border with border-radius — corner curve rendering differs
  3. High-contrast backgrounds amplify sub-pixel differences in SSIM metric
Fix applied: none needed — overlay visually matches; ~0.92-0.94 is the practical ceiling
Result: accepted as PASS at 0.942
Apply to: ALL components with complex SVG icons + rounded borders
Adaptive threshold: use 0.92 instead of 0.95 for components matching this pattern
Note: do NOT escalate to EC14 Level 2+ for this pattern — it is a known rendering ceiling, not a real defect
```

## Seed: `feedback_ssim_display_block.md`

```markdown
# SSIM Fix: <button> default inline-block adds 2dip gap
Component: (seed — applies to all components with <button> root)
Symptom: button has correct width/height in DevTools but visually sits 2dip too low; SSIM diff highlights a horizontal stripe below the button
Root cause: <button> defaults to display: inline-block in Sciter. Inline-block reserves space below the baseline for descenders, adding a 2dip gap below the element
Fix applied: add `display: block;` as the FIRST property in the .button selector, before flow:/width:/etc.
Result: SSIM recovers from 0.88-0.92 → 0.95+
Apply to: any component whose ROOT element is <button> (or any inline-block element used as a block container)
Full recipe: see reference-sciter-layout-strategy.md § Pitfall 4
```

## Seed: `feedback_ssim_centering.md`

```markdown
# SSIM Fix: content-vertical-align ignored with width:* children
Component: (seed — applies to any flow: horizontal row with mixed-width children)
Symptom: vertical centering breaks the moment one child of flow: horizontal has width:*. Icon/label/chevron fall to baseline instead of centering. SSIM diff highlights vertical offsets in all row children
Root cause: when ANY child of a flow: horizontal parent uses width:*, the row switches to a sizing-distribution mode where parent content-vertical-align is silently ignored. No parse-time warning
Fix applied: add `vertical-align: middle` to EVERY child individually (icon, label, trailing). Do NOT rely on parent content-vertical-align when width:* is present. Wrap icons/trailing elements in flow: stack containers for robust centering
Result: SSIM recovers; all row children visually centered
Apply to: any row with icon + label + chevron / any flow: horizontal with width:* child
Full recipe: see reference-sciter-layout-strategy.md § Pattern 1 + Pitfall 3
```

## Seed: `feedback_ssim_icon_in_flow.md`

```markdown
# SSIM Fix: <img> icon offset top-left despite content-*-align on parent
Component: (seed — applies to any component embedding an <img> icon)
Symptom: <img> icon anchors to top-left of its container; content-vertical-align: middle + content-horizontal-align: center on parent have no effect. SSIM diff highlights icon position only (not size or shape)
Root cause: <img> defaults to display: inline-block in Sciter. content-*-align on a parent only positions BLOCK children — inline-block children align by text-baseline, not by content-align
Fix applied: add `display: block` + `horizontal-align: center` to the <img>. Wrap the icon container in flow: stack with content-vertical-align: middle + content-horizontal-align: center to isolate alignment
Result: icon visually centered; SSIM passes
Apply to: ALL components with <img> icons inside containers that should center them
Symmetric to: feedback_ssim_display_block (covers <button> root); this one covers <img> children
Full recipe: see reference-sciter-layout-strategy.md § Pattern 3 + Pitfall 2
```

## Memory File Format

Each file captures one recurring fix pattern:

```markdown
# SSIM Fix: <topic>
Component: <name that triggered this, or "seed" / "all">
Symptom: SSIM score was <X> — <region> looked different
Root cause: <explanation>
Fix applied: <what changed in CSS/JS>
Result: SSIM reached <Y>
Apply to: <pattern — "all components" / "components with icons" / etc.>
```

## Memory Directory Layout

```text
<project-root>/.claude/agent-memory/sciter-create-component/
  feedback_ssim_typography.md          ← seeded on first run
  feedback_ssim_svg_icon_border.md     ← seeded on first run
  feedback_ssim_display_block.md       ← seeded on first run
  feedback_ssim_centering.md           ← seeded on first run
  feedback_ssim_icon_in_flow.md        ← seeded on first run
  feedback_ssim_<topic>.md             ← additional fixes written when user explains
```

Memory files accumulate over time as the user explains SSIM failures. `sciter-create-component` reads all matching files at Step 0 and applies known fixes proactively in Phase 2, before running preview.

The five seeded files above capture the recurring SSIM-layout failures documented in [`reference-sciter-layout-strategy.md`](reference-sciter-layout-strategy.md) § Pitfalls. The seeds carry the terse cause+fix; the strategy doc carries the full recipe.
