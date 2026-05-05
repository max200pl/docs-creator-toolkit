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
  feedback_ssim_typography.md     ← seeded on first run
  feedback_ssim_centering.md      ← written after user explains icon centering fix
  feedback_ssim_<topic>.md        ← any other recurring fix
```

Memory files accumulate over time as the user explains SSIM failures. `sciter-create-component` reads all matching files at Step 0 and applies known fixes proactively in Phase 2, before running preview.
