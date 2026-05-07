---
description: "Tooling rules for component building — preview-component.sh usage, SSIM strategy, window capture, and diagnosis. Read during Phase 3 (visual verify)."
---

# Component Build — Tooling Reference

## preview-component.sh

```bash
# Standard mode — derives preview path from module path
tools/preview-component.sh <module.js> <ClassName> <width_dip> <figma.png>

# --js mode — explicit preview file (REQUIRED for per-type SSIM)
tools/preview-component.sh --js <preview-<type>.js> <width_dip> <figma.png>
```

Use `--js` for per-type SSIM — standard mode appends `.preview.js` to the path and will not find `preview-<type>.js`.

## SSIM Strategy

**One run per type, sequential. Never run against the full-grid `preview.js`.**

| Step | Action |
| ---- | ---- |
| A | Create `<name>.preview-<type>.js` per type — one variant only |
| B | `tools/fetch-figma-screenshot.sh <fileKey> <default_nodeId> /tmp/figma-<type>.png` |
| C | Ask user: "Close previous preview window → confirm when ready" |
| D | `tools/preview-component.sh --js <name>.preview-<type>.js <width> /tmp/figma-<type>.png` |
| E | Read SSIM score from stdout before moving to next type |
| F | Delete `*.preview-<type>.js` after all types pass |

**Threshold:**
- `0.95` — default
- `0.92` — ceiling when component has SVG icons + border-radius (anti-aliasing limit, not a defect)

## Window Capture Rules

- **Window reuse bug:** `preview-component.sh` captures the first open window named "Preview". Always close the previous window before running the next type.
- **Preview must be visible:** do not minimize the preview window during capture — screencapture will grab a stale or wrong window.
- **Force close between types:** if unsure, run `pkill -f sciterjsMacOS` before the next run.

## Figma PNG Storage

- Always store at `/tmp/figma-<type>.png` — never in `tools/ScreenshotHistory/`
- `find-component.py save_history()` clears **all** PNGs in ScreenshotHistory on every run — reference PNGs stored there will be deleted by the next SSIM run

## Flex Container Wrapping

Components using `width: *` or `height: *` render at natural content size in an isolated preview window — no parent to fill. Wrap in a container with real layout dimensions from Figma.

```js
// Get parent frame dimensions: get_metadata(parentNodeId) → width × height → convert to dip
// Example: AsidePanel fills 540dip height (600dip window - 60dip caption bar)
document.body.content(
  <div style="height: 540dip;">
    <AsidePanel activeItem="scan" />
  </div>
);
```

Without wrapping, SSIM comparison is meaningless — the component renders at a different size than in Figma.

## SSIM Failure Diagnosis Order

When SSIM fails, diagnose in this order. Do NOT start with color/background.

1. **Size** — does the bounding box match Figma? (width × height)
2. **Padding / margins** — extra space around the component? (`display: block` gap, body margin)
3. **Element positions** — text/icon centered correctly?
4. **Colors** — only after layout is confirmed correct
