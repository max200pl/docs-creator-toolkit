---
name: sciter-create-primitive
description: "Sciter.js adapter for create-primitive. Creates a minimal component with Sciter CSS/JS rules and SSIM 0.95 visual verify. Run once during project onboarding before /sciter-create-component. Establishes the project's Code Connect pattern."
scope: api
argument-hint: "[figma-url]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent]
---

# Sciter Create Primitive

> **Extends:** `create-primitive/SKILL.md` — follow that skill for all phases not listed here.
> **Adds:** Sciter CSS/JS rules (Phase 2) + SSIM 0.95 visual verify (Phase 3) + agent memory seed (Step 0).
> **Result used by:** `sciter-create-component` Phase 5 — reads this primitive to discover Code Connect format + publish command.

## Usage

```text
/sciter-create-primitive
/sciter-create-primitive https://figma.com/design/FILE?node-id=1:234
```

## Execution

### Step 0 — Pre-flight (generic + variant check + memory seed)

Follow `create-primitive` Step 0 exactly, then additionally:

6. Load agent memory: read all `.claude/agent-memory/sciter-create-component/feedback_*.md` files.
   If directory is absent or empty → seed `feedback_ssim_typography.md`:
   ```
   # SSIM Fix: typography
   Component: (seed — applies to all components)
   Symptom: SSIM score stuck below 0.95 — text regions show the biggest delta in diff images
   Root cause: font shorthand with var() is silently ignored in Sciter — font metrics are never
   applied. Wrong font-size/line-height causes text elements to have incorrect pixel dimensions,
   which shifts everything positioned relative to them. SSIM fails on layout/positioning, not color.
   Fix applied: replace `font: var(--font-body)` with `@mixin typography-name;` — no parens, no comma.
   Result: SSIM typically jumps from 0.70-0.80 to 0.95+ after applying correct @mixin
   Apply to: ALL components — check every text element in CSS before running preview
   ```

### Phase 1 — Design context (unchanged)

Follow `create-primitive` Phase 1 exactly.

### Phase 2 — Generate files (Sciter rules)

Follow `create-primitive` Phase 2 structure, but apply Sciter CSS/JS rules from `sciter-create-component/SKILL.md` § Phase 2 Stream B instead of generic rules.

Apply known fixes from agent memory before generating — do not wait for SSIM failure.

### Phase 3 — Visual verify (Sciter SSIM)

Follow `sciter-create-component/SKILL.md` § Phase 3 exactly:

1. `tools/fetch-figma-screenshot.sh <fileKey> <nodeId> /tmp/figma-<name>.png`
   Copy to `tools/ScreenshotHistory/{ts}_figma_{name}.png`
2. Loop max 3 attempts: `tools/preview-component.sh <preview.js> <Name> <width> /tmp/figma-<name>.png`
   - SSIM >= 0.95 → PASS
   - SSIM < 0.95 → show diff, apply fix, retry
3. After PASS: copy preview screenshot → `tools/ScreenshotHistory/{ts}_code_{name}.png`
   If any fix applied → write agent memory `feedback_ssim_<topic>.md`
4. After 3 failures → EC14 escalation (Level 1 → Level 2 → Level 3)

### Phase 4 — Registry (+ ssim_score)

Follow `create-primitive` Phase 4, add `ssim_score` from Phase 3 result.

### Phase 5 — Establish Code Connect pattern (unchanged)

Follow `create-primitive` Phase 5 exactly.

### Finish

```text
✓ Primitive: <name>
  Layer:       <layer>/<slice-name>/
  CC format:   <name>.figma.{ext}
  Publish cmd: <command>
  SSIM:        <score>
  Registry:    entry created (type: primitive, figma_connected: true)

/sciter-create-component will now discover this primitive to determine Code Connect format.
```
