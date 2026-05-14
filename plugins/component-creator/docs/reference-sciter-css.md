---
description: "Sciter.js CSS quick-reference — properties, values, and patterns that differ from standard CSS. Use alongside adapter rules in sciter-create-component/SKILL.md."
---

# Sciter.js CSS — Quick Reference

> This file is a **property-syntax quick lookup**. For layout-strategy recipes (Figma pattern → Sciter recipe, centering decision trees, absolute/overlay positioning, SSIM-layout pitfalls and fixes) see [`reference-sciter-layout-strategy.md`](reference-sciter-layout-strategy.md). For styling mechanisms (`@set` / `@mixin` / `@const` / `--var` / BEM / encapsulation rules) see [`reference-sciter-styling.md`](reference-sciter-styling.md). For icon-container specifics see [`reference-sciter-icons.md`](reference-sciter-icons.md).

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

> Icon connection methods, color-change patterns, naming algorithm, and the decision matrix are the single source of truth in **`reference-sciter-icons.md`**. This page only covers layout/positioning concerns specific to icon containers.

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

## Style Organization At-Rules

Four CSS-organization mechanisms in Sciter. Use this section as **syntax reference** — for *when* to use each mechanism in component generation see [`reference-sciter-styling.md`](reference-sciter-styling.md) (4-step stepper). Full upstream provenance in [`research-sciter-stylesets.md`](../../../.claude/docs/research-sciter-stylesets.md).

| Mechanism | Form | Reactive? | Inherited? | Used in | Purpose |
| ---- | ---- | ---- | ---- | ---- | ---- |
| `--name: <value>` / `var(name): <value>` | CSS custom property | ✓ runtime | ✓ DOM | Stepper Step 4 | Design tokens, theme switching |
| `@const name : <value>` | Compile-time constant | ✗ | n/a | (avoid for tokens) | Immutable globals (asset URLs) — rare |
| `@mixin name { ... }` / `@mixin name(p) { ... }` | Declaration-group injection | n/a | n/a | Stepper Step 4 | Typography stacks; reusable property groups |
| `@set name { :root {...} child {...} }` | Style module applied via `style-set:` | n/a | n/a | Stepper Step 2 | Multi-variant component skin (`primary`/`secondary`/`ghost`) |

### `@set` — style module

```css
@set my-button [< parent-set-name] {
  :root          { background: var(--primary); padding: 8dip 16dip; }
  :root > .icon  { size: 16dip; }
  .label         { @font-md-medium; color: var(--color-text); }
}
```

Inside `@set`, `:root` is the **host** (the element with `style-set:` applied), NOT the document root. Selectors evaluate relative to the host — they cannot leak globally.

Three application paths:

```css
.btn { style-set: my-button; }                              /* CSS */
```

```html
<div styleset="styles.css#my-button">...</div>              <!-- HTML -->
```

```jsx
<div styleset={__DIR__ + "styles.css#my-button"}>...</div>  /* JSX */
```

**Inheritance:** `@set ghost < primary { ... }` inherits all parent rules; child rules append. More-specific inherited rule may win over less-specific self rule.

**Override mechanism:** external rules require `!important` to override `@set` declarations. `content-isolate: isolate` (default) seals from later same-name redefinition.

### `@mixin` — declaration injection

```css
/* Basic — no parameters */
@mixin font-md-medium {
  font-family: 'Inter';
  font-size: 14dip;
  font-weight: 500;
  line-height: 20dip;
}

/* Parametric */
@mixin like-button(color) {
  background-color: @color;
  border-radius: 3dip;
  padding: 0.5em 1em;
}
```

Invocation (always semicolon, no parens for basic):

```css
.label  { @font-md-medium; }
.button { @like-button(var(--accent)); color: white; }   /* color: white redefines mixin's value */
```

**Order-aware redefinition:** declarations AFTER `@mixin-name;` in the same rule override the mixin's values. Idiomatic for typography where components want the base stack but tweak color or weight.

### `@const` — compile-time constant

```css
@const BACKGROUND: no-repeat url(home://app/bg.svg) 50% 50%;

body { background: @BACKGROUND; }
```

Invoked with `@` prefix (no parens). Resolved at CSS parse time, not at runtime. Use ONLY for genuinely immutable globals — never for design tokens.

### `--var` (CSS custom properties) — preferred token mechanism

Standard W3C form + Sciter ergonomic form (both equivalent):

```css
/* Standard */
:root { --color-text: #000; }
.label { color: var(--color-text); }

/* Sciter ergonomic */
:root { var(color-text): #000; }
.label { color: color(color-text); }
```

Typed accessors: `var(name, default)`, `length(name)`, `color(name)` — all accept fallback as second argument.

**`--var` vs `@const` — pick by reactivity:**

| Property | `--var` (custom property) | `@const` |
| ---- | ---- | ---- |
| Resolution | Runtime | Compile-time |
| Mutable via JS | ✓ `element.style.setProperty()` | ✗ |
| Inherited through DOM | ✓ | ✗ |
| Page-scoped override possible | ✓ | ✗ |
| Use for design tokens | **✓ always** | ✗ never |

## Miscellaneous

```css
clear: before;          /* force new row/column before this element */
clear: after;
flow-rows: 40px 1* 40px;
flow-columns: 200px 1*;
```

## Generator rules

Generator override rules (CSS rules + JS rules) are **moved** to dedicated docs to avoid duplication. See:

- CSS generation rules per stepper Step → [`reference-sciter-styling.md`](reference-sciter-styling.md) (Steps 1–4 each have a `### Rules` subsection)
- Layout-specific rules (alignment, centering, `<button>` block) → [`reference-sciter-layout-strategy.md`](reference-sciter-layout-strategy.md) § Pitfalls + § Required Generator Rules
- Icon-specific rules → [`reference-sciter-icons.md`](reference-sciter-icons.md)
- JS rules (`class Name extends Element`, `class="..."`, `__DIR__ + "img/..."`, `state-disabled`, etc.) → live with the relevant skill rule files and `feedback_ssim_*.md` agent-memory seeds

This file remains a **pure property-syntax reference** — what each Sciter CSS property accepts and how it maps to standard CSS. For decision-flow (when to use which mechanism) see the styling stepper.
