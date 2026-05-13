---
description: "Sciter.js layout strategy — recipes for translating Figma Auto-Layout / absolute frames into idiomatic Sciter CSS. Decision tree for flow vs stack vs absolute; centering patterns; pitfalls and their fixes. Companion to reference-sciter-css.md (property syntax) and reference-sciter-icons.md (icon specifics)."
---

# Sciter.js — Layout Strategy

> Consumed by: `sciter-create-component` Phase 2B before emitting CSS, `update-component` Phase 4 when changing layout.
> Companion files: [`reference-sciter-css.md`](reference-sciter-css.md) for property syntax, [`reference-sciter-icons.md`](reference-sciter-icons.md) for icon-container specifics.

## Reading Guide

| Section | When to read |
| ---- | ---- |
| [Layout Model — Sciter vs Standard CSS](#layout-model--sciter-vs-standard-css) | First time generating any Sciter CSS — understand the mental model |
| [Figma Pattern → Sciter Recipe](#figma-pattern--sciter-recipe) | Translating a Figma frame into CSS — pick the recipe by pattern |
| [Centering Recipes](#centering-recipes) | Component has vertical or horizontal centering — pick the recipe by container/child shape |
| [Absolute & Overlay Positioning](#absolute--overlay-positioning) | Figma frame has overlapping children (badge in corner, popover, tooltip) |
| [Pitfalls & Their Fixes](#pitfalls--their-fixes) | SSIM failing on layout positioning — look up the symptom |
| [Decision Tree](#decision-tree) | Quick reference at generation time |

## Layout Model — Sciter vs Standard CSS

Sciter uses `flow:` instead of `display: flex/grid`. The mental model is similar to flexbox but with built-in primitives for the patterns flexbox needs three properties to express.

| Standard CSS | Sciter equivalent | Notes |
| ---- | ---- | ---- |
| `display: flex; flex-direction: row` | `flow: horizontal` | default for non-text content |
| `display: flex; flex-direction: column` | `flow: vertical` | |
| `display: grid` | `flow: grid(cols-spec)` | rarely needed — `flow: horizontal/vertical` covers most cases |
| `position: relative` + absolute children (overlay) | `flow: stack` | single-cell container; children stack via z-order |
| `flex: 1` | `width: *` (or `height: *` for vertical flow) | distributes leftover space |
| `gap: 8px` | `gap: 8dip` (or `border-spacing: 8dip`) | not all flows respect `gap` — see Pitfalls |
| `flex-wrap: wrap` | `flow: horizontal-wrap` | |
| `overflow: hidden` | `overflow: none` | `hidden` is NOT a Sciter value |
| `overflow: auto` | `overflow: scroll-indicator` | `auto` is NOT supported |
| `px` | `dip` | device-independent pixel, 1:1 from Figma |
| `background-image` (icon) | `foreground-image` | see [reference-sciter-icons.md](reference-sciter-icons.md) |

> **Rule:** the generator MUST emit Sciter primitives, not standard CSS values. `display: flex` / `flex: 1` / `overflow: hidden` / `px` are silently ignored or partially supported — bugs surface at SSIM-verification time.

## Figma Pattern → Sciter Recipe

### Pattern 1 — Horizontal row with icon + label + trailing element

> Common shape: menu item, list row, nav item — icon on the left, label fills middle, chevron/arrow/badge on the right.

```css
.row {
  flow: horizontal;
  width: *;                 /* fill parent width */
  height: 48dip;            /* fixed row height — labels too! */
  padding: 0 10dip;
  border-radius: var(--radius-md);
}

.row__icon-wrap {
  size: 32dip;              /* fixed icon container size */
  vertical-align: middle;   /* per-child: required when label uses width:* */
  flow: stack;              /* single-cell wrapper for centering */
  content-vertical-align: middle;
  content-horizontal-align: center;
}

.row__icon {
  display: block;           /* <img> must be block to center in flow: stack */
  horizontal-align: center;
}

.row__label {
  width: *;                 /* fill remaining width */
  height: 48dip;            /* MATCH row height — see Pitfall 1 */
  vertical-align: middle;
  margin-left: var(--space-sm);
  @font-md-medium;
  color: var(--color-text);
}

.row__trail-wrap {           /* mirror of icon-wrap for trailing chevron/badge */
  size: 16dip;
  vertical-align: middle;
  flow: stack;
  content-vertical-align: middle;
  content-horizontal-align: center;
}

.row__trail {
  display: block;
}
```

**Why the wrappers exist:** without `flow: stack` wrappers around the icon and trailing element, the inner `<img>` does NOT respect `vertical-align: middle` from its parent's `content-vertical-align` (see Pitfall 2). The wrapper isolates the child into a single-cell context where `content-vertical-align` works.

**Why `height: 48dip` on the label:** `flow: horizontal` does NOT auto-fill child height. If the label's height is unset, it shrinks to text-line height and the label baseline is offset from the icon. Setting label height equal to row height makes them share the same alignment box.

### Pattern 2 — Vertical list of fixed-height items

```css
.list {
  flow: vertical;
  width: *;
  gap: var(--space-xs);     /* gap between items */
  padding: 10dip;
}
```

Items use Pattern 1. Do NOT add `margin-bottom` to items — use the parent's `gap:` instead. Mixing `gap:` and `margin` produces double spacing.

### Pattern 3 — Centered icon in fixed-size container

> For toolbar buttons, icon-only buttons, indicator dots.

```css
.icon-button {
  size: 32dip;
  flow: stack;              /* single-cell, centering-friendly */
  content-vertical-align: middle;
  content-horizontal-align: center;
}

.icon-button__icon {
  display: block;           /* <img> default is inline-block → ignores content-*-align */
}
```

### Pattern 4 — Two-column split (sidebar + content)

```css
.layout {
  flow: horizontal;
  width: *;
  height: *;
}

.layout__sidebar {
  width: 240dip;            /* fixed */
  height: *;
}

.layout__content {
  width: *;                 /* fill */
  height: *;
}
```

If sidebar should be collapsible — toggle `width: 240dip` ↔ `width: 56dip` in a state class. Do not animate via JS layout reads — use CSS `transition: width 200ms` on `.layout__sidebar`.

### Pattern 5 — Wrapping row (chip/tag list)

```css
.tags {
  flow: horizontal-wrap;
  gap: var(--space-xs);
  width: *;
}
```

`flow: horizontal-wrap` wraps when row is full. Do not specify item width with `*` — that defeats wrapping. Use fixed or `min-content` sizing for chips.

## Centering Recipes

> Centering in Sciter has three distinct mechanisms — picking the wrong one is the #1 cause of SSIM layout failures.

| Need | Mechanism | Constraint |
| ---- | ---- | ---- |
| Vertically center children in `flow: horizontal` row | `vertical-align: middle` **on every child** | `content-vertical-align: middle` on the PARENT is silently ignored when any child uses `width: *` — see Pitfall 3 |
| Horizontally center children in `flow: vertical` column | `content-horizontal-align: center` on parent | Works reliably |
| Center single child in any-flow container | Wrap in `flow: stack` container with `content-vertical-align: middle` + `content-horizontal-align: center` | The wrapper isolates the child from siblings — works regardless of child sizing |
| Center `<img>` inside its container | `display: block; horizontal-align: center` on the `<img>` + wrap container as above | `<img>` defaults to `inline-block`, which ignores `content-vertical-align` — see Pitfall 2 |
| Center `<button>` content / center `<button>` itself | `display: block` on the `<button>` first, THEN apply centering | `<button>` defaults to `inline-block`, adding a 2dip line-height gap below — see Pitfall 4 |

## Absolute & Overlay Positioning

Sciter's primary overlay primitive is **`flow: stack`** — not `position: absolute`. Use absolute positioning only when stack cannot express the overlap (rare).

### `flow: stack` — the default overlay tool

```css
.card {
  flow: stack;              /* all children occupy the same cell */
  size: 200dip 120dip;
}

.card__background  { width: *; height: *; }       /* layer 0 — fills */
.card__content     {
  vertical-align: middle;   /* center vertically within stack cell */
  horizontal-align: center;
}
.card__badge {
  vertical-align: top;      /* anchor to top of cell */
  horizontal-align: right;  /* anchor to right of cell */
  margin: 8dip;             /* inset from edges */
}
```

**Anchor keywords on a stack child:**

- `vertical-align: top | middle | bottom`
- `horizontal-align: left | center | right`
- `margin: <inset>` — pads the child from the anchored edge

This expresses 90% of what `position: absolute` does in CSS — corner badges, centered overlays, watermarks.

### `position: absolute` — when stack is not enough

Sciter supports `position: absolute` but it's rarely needed. Use when:

- The overlay must escape its parent's bounds (tooltip, dropdown that flows outside container)
- The position depends on runtime measurement (popover anchored to a moving element)

```css
.container { position: relative; }    /* establish coordinate space */
.popover {
  position: absolute;
  top: 100%;                          /* below the anchor */
  left: 0;
  width: 240dip;
}
```

For most popover/dropdown work in Sciter, the recommended approach is `popup-position:` (see `behavior:` family in [`reference-sciter-css.md`](reference-sciter-css.md#interactive-elements)). It handles viewport-edge collision automatically — `position: absolute` does not.

### Decision: stack vs absolute

| Need | Use |
| ---- | ---- |
| Overlay stays inside parent bounds | `flow: stack` + anchor keywords |
| Overlay must overflow parent | `position: absolute` (or `popup-position:` for popovers) |
| Position computed at runtime | `position: absolute` + JS |
| Standard component composition (badge, watermark, centered content) | `flow: stack` |

## Pitfalls & Their Fixes

> These are the recurring SSIM-layout failures. Each pitfall maps to an agent-memory `feedback_ssim_*.md` seed (see [`reference-sciter-agent-memory.md`](reference-sciter-agent-memory.md)).

### Pitfall 1 — Label baseline offset from icon in `flow: horizontal`

**Symptom:** SSIM diff shows label text shifted up or down relative to icon in a horizontal row. Visual: icon centered, label not.

**Root cause:** label has no `height` set — it shrinks to text-line height (~20dip). The row's `content-vertical-align` is ignored because label uses `width: *` (see Pitfall 3). Result: label's vertical-center is at text-line midpoint, not row midpoint.

**Fix:** set `height: <row-height>dip` on the label. Both label and row share the same alignment box.

### Pitfall 2 — `<img>` icon offset top-left in centered container

**Symptom:** icon appears anchored to top-left of its container instead of centered. `content-vertical-align: middle` + `content-horizontal-align: center` on the container have no effect.

**Root cause:** `<img>` defaults to `inline-block` in Sciter. `content-*-align` on a parent only positions `block` children. Inline-block children align by text-baseline, not by content-align.

**Fix:** add `display: block` AND `horizontal-align: center` to the `<img>`. Also wrap the icon container in `flow: stack` to isolate alignment.

### Pitfall 3 — `content-vertical-align` ignored when child uses `width: *`

**Symptom:** vertical centering breaks the moment one child of a `flow: horizontal` parent has `width: *`. All children fall to baseline.

**Root cause:** `width: *` children switch the row into a sizing-distribution mode where `content-vertical-align` is silently ignored. There is no warning at parse time.

**Fix:** apply `vertical-align: middle` to EVERY child individually (icon, label, trailing). Do not rely on parent `content-vertical-align` when any child uses `*` sizing.

### Pitfall 4 — `<button>` adds 2dip gap below itself

**Symptom:** generated button has correct dimensions in DevTools but visually sits 2dip too low, creating a gap below it.

**Root cause:** `<button>` defaults to `inline-block`. Inline-block elements reserve space below the baseline for descenders even when text content is empty.

**Fix:** add `display: block;` as the FIRST property in the `<button>` selector. Then layout as normal.

### Pitfall 5 — `gap:` ignored in `flow: stack`

**Symptom:** children of a `flow: stack` container ignore the parent's `gap:`.

**Root cause:** `flow: stack` is single-cell — there is no "between" to gap. By design.

**Fix:** if you need spacing between stacked layers, use `margin:` on the individual children. For row/column gaps, use `flow: horizontal` / `flow: vertical` instead.

### Pitfall 6 — `font:` shorthand with `var()` silently ignored

**Symptom:** SSIM stuck below 0.95 despite correct layout. Text regions show the biggest delta in diff images.

**Root cause:** Sciter does not resolve `var()` inside the `font:` shorthand. Font metrics are never applied; text takes default font and size.

**Fix:** replace `font: var(--font-body)` with `@mixin typography-name;` (no parens, no comma, ends with semicolon). See [`reference-sciter-css.md` Typography](reference-sciter-css.md#typography).

## Decision Tree

Use this when picking layout at generation time. Walk top-down.

```text
Is the frame a sibling row or column (children laid out one after another)?
├── Yes → flow: horizontal | flow: vertical
│         └── Any child fills leftover space? → width: * / height: * on that child
│         └── Any child contains a single icon/image? → wrap in flow: stack (Pattern 3)
│         └── Vertical centering needed? → vertical-align: middle on EVERY child (Pitfall 3)
│
└── No → Are children overlapping / stacked (badge on card, centered watermark)?
         ├── Yes → flow: stack
         │         └── Anchor each child with vertical-align + horizontal-align + margin
         │
         └── No → Does any child need to overflow the parent bounds (tooltip, popover)?
                  ├── Yes → behavior: popup + popup-position: (preferred)
                  │         └── Or position: absolute if not a popover use case
                  │
                  └── No → reconsider — probably one of the above after all
```

## Cross-References

- [`reference-sciter-css.md`](reference-sciter-css.md) — property syntax quick-reference
- [`reference-sciter-icons.md`](reference-sciter-icons.md) — icon-container patterns (interplay with this doc on icon centering)
- [`reference-sciter-agent-memory.md`](reference-sciter-agent-memory.md) — seed `feedback_ssim_*.md` files for the pitfalls above
- [Sciter `flow:` docs](https://docs.sciter.com/docs/CSS/properties#flow) — upstream reference
- [Sciter `position:` docs](https://docs.sciter.com/docs/CSS/properties) — upstream reference
