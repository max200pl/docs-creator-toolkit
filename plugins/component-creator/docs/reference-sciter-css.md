---
description: "Sciter.js CSS quick-reference — properties, values, and patterns that differ from standard CSS. Use alongside adapter rules in sciter-create-component/SKILL.md."
---

# Sciter.js CSS — Quick Reference

## Layout (`flow:`)

| Value | Equivalent | Notes |
| ---- | ---- | ---- |
| `flow: horizontal` | `display: flex; flex-direction: row` | default |
| `flow: vertical` | `display: flex; flex-direction: column` | |
| `flow: stack` | `position: relative` + absolute children | z-order overlay |
| `flow: horizontal-wrap` | `flex-wrap: wrap` | multi-row |
| `flow: vertical-wrap` | multi-column | |
| `flow: grid(cols)` | CSS Grid | e.g. `flow: grid(1 2 3)` |
| `flow: text` | paragraph/inline text | |

## Sizing

| Property | Sciter | Wrong |
| ---- | ---- | ---- |
| Fixed | `width: 159dip` | `width: 159px` |
| Fill container | `width: *` | `flex: 1` |
| Fixed + fill | `width: 100dip *` | mixed flex |
| Gap | `gap: 8dip` or `border-spacing: 8dip` | `margin` between items |

**`dip`** — device-independent pixel, 1:1 from Figma. Always use `dip` — never `px` in component CSS.

## Overflow

| Value | Meaning |
| ---- | ---- |
| `overflow: none` | clip content (= `hidden`) |
| `overflow: scroll-indicator` | show scroll indicator |
| `overflow: auto` | **not supported** — use `scroll-indicator` |

## Alignment

```css
/* Centering children in flow: horizontal */
/* content-vertical-align on parent is IGNORED when any child uses width: * */
/* Fix: add vertical-align: middle to EVERY child individually */
.row { flow: horizontal; height: 48dip; }
.icon  { size: 32dip; vertical-align: middle; }
.label { width: *;    vertical-align: middle; }

/* display: block required on <button> root */
/* default inline-block adds 2px line-height gap below element */
.button { display: block; flow: horizontal; }
```

## Interactive Elements

| Property | Values | Notes |
| ---- | ---- | ---- |
| `behavior:` | `checkbox`, `radio`, `slider`, `select`, `edit`, `textarea` | attaches native Sciter behavior |
| `prototype:` | `ClassName url(file.js)` | CSS → JS class binding |
| `styleset:` | `url(styles.css#block)` | scoped style sets |
| `hit-margin:` | `4px` | invisible click zone expansion |
| `popup-position:` | `bottom-right` etc. | popup anchor |

## Icons + Images

| Use case | Correct | Wrong |
| ---- | ---- | ---- |
| Icon is main content | `<img src="..." />` | |
| Icon decorates interactive element | `foreground-image: url(...)` + `foreground-size: contain` | `background-image` |
| Many icons from one sprite | `@image-map` | individual files |

```css
/* <img> in flow: vertical must have display: block to center */
.icon-container { flow: vertical; content-horizontal-align: center; }
.icon-container img { display: block; horizontal-align: center; }
```

## Typography

```css
/* CORRECT — use @mixin, no parens, no comma, ends with ; */
.label { @font-md-medium; }

/* WRONG — font shorthand with var() is silently ignored in Sciter */
.label { font: var(--font-body); }

/* @font-face must be in main.css BEFORE all @import rules */
/* URL resolution breaks when declared in imported component CSS */
```

**Cross-engine rendering diff:** Sciter uses CoreText (macOS) / DirectWrite (Windows); Figma uses Skia. Accept ~1-2dip glyph width difference — do NOT compensate with `letter-spacing`.

## Miscellaneous

```css
clear: before;          /* force new row/column before this element */
clear: after;
flow-rows: 40px 1* 40px;
flow-columns: 200px 1*;
```

## Adapter Override Rules (sciter-create-component)

### CSS rules

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
| `<button>` block | `display: block` as first property | default inline-block (adds 2px gap) |
| Pixel-perfect | Figma value = source of truth; token ≠ Figma → raw `dip` | sacrificing accuracy for token reuse |

### JS rules

| Rule | Correct | Wrong |
| ---- | ---- | ---- |
| Base class | `class Name extends Element` | functional component |
| HTML attr | `class="..."` | `className="..."` |
| Icon paths | `__DIR__ + "img/..."` | `"./img/..."` |
| Imports | must include `.js` extension | bare paths |
| State | native Sciter element methods | React hooks |
| Disabled | `state-disabled={this.disabled}` | `disabled={this.disabled}` (HTML attr, not Sciter state) |
