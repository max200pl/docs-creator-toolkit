---
description: "Sciter.js icon connection methods, color-change patterns, naming, and the decision matrix used by sciter-create-component Phase 2B. Single source of truth for icon-related rules in this plugin."
---

# Sciter.js — Icon Connection Reference

> Consumed by: `sciter-create-component` (Phase 2A/2B), `update-component`, and `design-system-scanner` (docs-creator) for Sciter-specific detection signals.
> Cross-referenced from `reference-sciter-css.md` and `reference-component-decompose.md`.

## Reading Guide

| Section | When to read | Consumer |
| ---- | ---- | ---- |
| [Schema Contract](#schema-contract--icon_pattern) | Need the `icon_pattern` field shape | `analyze-frontend` (produce), `sciter-create-component` (consume) |
| [Sciter CSS Properties for Icons](#sciter-css-properties-for-icons) | Need the flat list of properties involved in icon rendering | reference table |
| [Sciter Idiomatic Method](#sciter-official-recommended-method) | Need the fallback baseline for greenfield / user-opt-in to official Sciter way | `sciter-create-component` Phase 2B |
| [URL Schemes](#url-schemes) | Need to know which `url(...)` prefixes are documented | detection + generation |
| [Connection Methods](#connection-methods) | Need enum values for `icon_pattern.connection` with Sciter syntax | generation |
| [Color-Change Methods](#color-change-methods) | Need enum values for `icon_pattern.color_change` with mechanism | generation |
| [Reactor Re-render Rule](#sciter-reactor-re-render-rule) | Generating any JS-state-driven swap | generation — MUST read |
| [Decision Matrix](#decision-matrix) | Picking the code template per `(connection × color_change)` | `sciter-create-component` Phase 2B |
| [Detection Signals](#detection-signals-sciter) | Running `analyze-frontend` against a Sciter project | `design-system-scanner` |
| [Icon Naming Algorithm](#icon-naming-algorithm) | Downloading SVG assets from Figma | `sciter-create-component` Phase 2A |
| [Project Archetypes](#project-archetypes) | Sanity-check against real-world combinations | reference |

## Schema Contract — `icon_pattern`

Canonical shape produced by docs-creator's `analyze-frontend` (`design-system-scanner` agent) and consumed by `sciter-create-component`. Any change here must be synced with `plugins/docs-creator/docs/reference-icon-patterns.md`.

```yaml
icon_pattern:
  connection: <enum | null>
    # img-tag | img-imported-svg | css-foreground-image
    # css-foreground-icon | css-foreground-path | css-background-image
    # inline-svg | inline-svg-use-sprite
    # icon-wrapper-component | icon-library
  color_change: <enum | null>
    # svg-swap-display | js-src-swap | css-filter | css-fill
    # css-foreground-color | css-token-fill | icon-prop | currentColor | none
  library_name: <string | "none">         # e.g. "lucide-react"
  path_convention: <string>               # e.g. "__DIR__ + 'img/<name>.svg'"
  wrapper_component:
    name: <string | null>                 # e.g. "ImageSprite", "Icon"
    path: <relative path | null>
  examples:                                # max 3
    - { path: <file>, connection: <enum>, color_change: <enum> }
  notes: <free-text — flags conflicts between code and project rules>
```

## Sciter CSS Properties for Icons

Condensed from [docs.sciter.com/CSS/properties](https://docs.sciter.com/docs/CSS/properties). All properties below accept standard state pseudo-classes (`:hover`, `:focus`, `:current`, `:checked`, `:disabled`).

| Family | Property | Purpose / accepted shape |
| ---- | ---- | ---- |
| **foreground-image** | `foreground-image` | Overlay image: `url(...)` / `icon(name)` / `icon(vbox; d-path)` / `path(...)` |
| | `foreground-position`, `foreground-position-top/left/right/bottom` | Position |
| | `foreground-size`, `foreground-width`, `foreground-height` | Sizing |
| | `foreground-repeat`, `foreground-clip`, `foreground-attachment` | Layout |
| | `foreground-image-frame` | Sprite cell index |
| | `foreground-blend-mode` | Blend with background |
| | `foreground-image-cursor` | Cursor override over overlay |
| | `foreground-image-transformation` | Image filter chain: `contrast()` / `brightness()` / `gamma()` / `hue()` / `saturation()` / `opacity()` / `flip-x()` / `flip-y()` |
| | `foreground-color: rgba(...)` | **Semi-transparent overlay — NOT a fill tint.** Easily mistaken. Do NOT use to recolour icons. |
| **background-image** | `background-image` and `background-*` family | Mirror of foreground-* with same shape |
| | `background-image-transformation` | Same filter functions as `foreground-image-transformation` |
| | `background-image-frame` | Sprite cell index |
| **fill/stroke** (SVG, applied to vector content) | `fill`, `fill-opacity`, `fill-rule` | Vector fill |
| | `stroke`, `stroke-width`, `stroke-linecap`, `stroke-linejoin`, `stroke-miterlimit`, `stroke-dasharray`, `stroke-dashoffset`, `stroke-opacity` | Vector stroke |
| | `marker`, `marker-start`, `marker-mid`, `marker-end` | Path endpoint symbols |
| | `stop-color`, `stop-opacity` | Gradient stops |
| **filter** | `filter` | Element-wide visual effect chain (covers the whole element, not just fg-image) |
| | `backdrop-filter` | Filter applied behind the element |
| **shape** | `border-shape: path(...)` | Arbitrary element clipping path — useful for non-rectangular icon containers |

> **`filter` vs `foreground-image-transformation`:** `filter` affects the entire element (border, text, children). `foreground-image-transformation` affects only the foreground-image layer. Choose the latter when you want to recolour the icon without recolouring its container.

## Sciter Official Recommended Method

Used as fallback baseline when a project has no detected icon convention (greenfield) or when the user explicitly opts in via the interactive strategy choice in `sciter-create-component` Phase 2B.

> **⚠ Sciter project rule:** avoid swap-based color-change patterns (`js-src-swap`, `svg-swap-display`) when CSS-pseudo can express the trigger. Reasons: `js-src-swap` requires a manual `this.componentUpdate()` after every state mutation (Reactor does NOT auto-render — see [Sciter Reactor Re-render Rule](#sciter-reactor-re-render-rule)) and the foot-gun only surfaces at SSIM-verification time; `svg-swap-display` doubles asset count and DOM weight. Prefer `css-fill` / `css-token-fill` / `css-filter` (`foreground-image-transformation`) / CSS-pseudo `foreground-image:` redeclaration. Swap is the **fallback** when the trigger is genuinely JS-only (click-persistent selection, route-active highlight) and CSS pseudo cannot reach it.

Sciter docs treat **`foreground-image` + vector content** as idiomatic. Stock icons via `icon:name`, custom inline icons via `icon(vbox; d-path)`, external SVG via `url(...)`. State-driven changes use standard CSS pseudo-classes (`:hover`, `:current`, `:checked`, `:disabled`) to re-declare `fill`, `stroke`, or `foreground-image`.

```css
/* Stock icon */
icon.heart { foreground-image: icon(heart); }

/* Custom inline icon */
icon.heart {
  foreground-image: icon(0 0 100 100;
    M 10,30 A 20,20 0,0,1 50,30 A 20,20 0,0,1 90,30 Q 90,60 50,90 Q 10,60 10,30 z);
  fill: none;
  stroke: red;
  stroke-width: 1px;
}

/* External SVG file with state-driven recolour */
button.save     { foreground-image: url(this://app/img/save.svg); fill: var(--icon-color); }
button.save:hover    { fill: var(--icon-color-hover); }
button.save:checked  { foreground-image: icon(check); }
```

Source: [paths-and-vector-images](https://docs.sciter.com/docs/CSS/paths-and-vector-images).

## URL Schemes

| Scheme | Status | Use |
| ---- | ---- | ---- |
| `icon:<name>` | ✓ documented | Stock icon catalogue |
| `path:<d-commands>` | ✓ documented | Inline SVG path data |
| `home://` | ✓ documented | Relative to sciter.dll/exe location |
| `this://app/` | ✓ documented | packfolder archive (typical for shipped apps) |
| `file://` | ✓ documented | Local filesystem |
| `sciter:<resource>` | ✓ documented | Embedded Sciter resources (e.g. `sciter:icon-alert.png`) |
| `stock:<name>` | ✗ **NOT documented** | If observed → flag in `icon_pattern.notes` as `non-recommended`. Likely a typo for `icon:<name>` |

### URL schemes that do NOT exist

`stock:` is the recurrent example. Append the following to `icon_pattern.notes` when detected:

```text
Non-recommended pattern: url(stock:<name>) — likely a typo for icon:<name>.
Reference: https://docs.sciter.com/docs/URL-sciter-schemes
```

Source: [URL-sciter-schemes](https://docs.sciter.com/docs/URL-sciter-schemes).

## Connection Methods

Six Sciter-applicable values for `icon_pattern.connection`:

| Enum value | Syntax | When to use | Idiomatic? |
| ---- | ---- | ---- | ---- |
| `img-tag` | `<img src={__DIR__ + "img/icon.svg"}>` | Icon is the entire content of an element | Allowed |
| `css-foreground-image` | `foreground-image: url(this://app/img/icon.svg)` | Icon decorates an interactive element | ✓ Idiomatic |
| `css-foreground-icon` | `foreground-image: icon(name)` (stock) or `icon(vbox; d-path)` (custom) | Stock icon or inline d-path; no external file | ✓ Most idiomatic for stock + inline |
| `css-foreground-path` | `background-image: path(d-commands)` | Inline SVG path on background | Niche |
| `css-background-image` | `background-image: url(...)` | Backwards-compat | Discouraged — `foreground-image` is preferred |
| `@image-map` | `@image-map` at-rule + `image-map(map, name)` | Many small icons from one sprite atlas | ✓ For sprites |

## Sciter Reactor Re-render Rule

> ⚠ Mutation of `this.<field>` does NOT auto-trigger a Reactor re-render.

**Critical for any `color_change` that depends on JS state** (`js-src-swap`, `icon-prop`, and JS-state-driven variants of `svg-swap-display`).

Unlike React/Vue, Sciter Reactor does **NOT** automatically re-render when class fields are mutated. After mutating state in an event handler, you **MUST** call `this.componentUpdate()` explicitly **before** any side-effect (navigate, network, etc.):

```js
["on click at .my-button"](evt, el) {
  this.activeItem = id;
  this.componentUpdate();   // REQUIRED — without this, <img src=> stays stale
  navigate(id);             // side-effect AFTER re-render
}
```

| Trigger | Needs `componentUpdate()`? |
| ---- | ---- |
| `:hover`, `:focus`, `:current`, `:checked`, `:disabled` (CSS pseudo) | No — browser swaps styling |
| `on click` / event handler mutating `this.<field>` (JS state) | **Yes** |
| Reactor Signals API | No — signals trigger render automatically |

Source: [Reactor/component-update](https://docs.sciter.com/docs/Reactor/component-update).

## Color-Change Methods

Seven Sciter-applicable values for `icon_pattern.color_change`. Recommendation column captures the Sciter-project rule (see [Sciter Idiomatic Method](#sciter-official-recommended-method) above).

| Enum value | Mechanism | Works with | Trigger | Sciter recommendation |
| ---- | ---- | ---- | ---- | ---- |
| `none` | No state-driven change | any | n/a | ✓ Default |
| `css-fill` | `fill: <color>` in state pseudo | `css-foreground-icon`, inline `<svg>`, `path()` content | CSS pseudo | ✓ **Preferred** for vector content |
| `css-token-fill` | `fill: var(--icon-color)` + token override per state | Vector content + design tokens | CSS pseudo | ✓ **Preferred** for vector + themed |
| `css-filter` | `foreground-image-transformation: brightness(N)` (or `filter:` for whole element) | Any raster icon | CSS pseudo | ✓ **Preferred** for raster |
| `svg-swap-display` | Two `<img>` per state; CSS `display: none/block` toggle | `img-tag` | CSS pseudo | ⚠ Discouraged — doubles asset count + DOM weight; use only if `css-filter` cannot achieve the visual change |
| `js-src-swap` | Single `<img>` per slot; parent state-keyed URL map; child re-renders | `img-tag`, `img-imported-svg` | **JS state — `componentUpdate()` required** | ⚠ Discouraged — last-resort fallback when the trigger is JS-only (click-persistent selection, route-active) and CSS pseudo cannot reach it |
| `css-foreground-color` | `foreground-color: <color>` | **DO NOT USE for tinting** — see [CSS Properties table](#sciter-css-properties-for-icons) | n/a | ✗ Misuse |

**Picking the method for Sciter projects:**

1. Vector icon (`icon()` / `path()` / inline `<svg>`) → `css-fill` or `css-token-fill`
2. Raster icon (`<img>` / `url(...)`) → `css-filter` via `foreground-image-transformation`
3. Pseudo-state isn't expressive enough (e.g. click-driven persistent active item) → first try CSS-pseudo `foreground-image:` redeclaration (a `css-filter`/static swap inside `:current`/`:checked`); only if that fails, fall back to `svg-swap-display` or `js-src-swap`.
4. Never reach for swap without verifying CSS-pseudo cannot handle the trigger.

## Detection Signals (Sciter)

Used by `design-system-scanner` (docs-creator's `analyze-frontend`) when `framework_hint = "Sciter"`. Read **in addition** to the cross-framework signals in `plugins/docs-creator/docs/reference-icon-patterns.md`. Scoring rules from the cross-framework file apply unchanged.

### Connection signals — Sciter-specific

| Enum | Signal | File extensions |
| ---- | ---- | ---- |
| `img-tag` (Sciter widget pattern) | `<img\s+src=\{?\s*__DIR__\s*\+\s*["']img\/` — `__DIR__`-rooted asset path | `.js` (Sciter JSX) |
| `css-foreground-image` | `foreground-image:\s*url\(` | `.css`, `.scss` |
| `css-foreground-icon` | `foreground-image:\s*icon\(` | `.css` |
| `css-foreground-path` | `(foreground\|background)-image:\s*path\(` | `.css` |
| `@image-map` | `@image-map\s+[\w-]+\s*\{` | `.css` |

### Color-change signals — Sciter-specific

| Enum | Signal | File extensions |
| ---- | ---- | ---- |
| `css-foreground-color` | `:hover\b[^}]*\{[^}]*foreground-color:` — flag as overlay misuse if applied to icon container | `.css` |
| `css-filter` (Sciter variant) | `foreground-image-transformation:` inside a state pseudo-class block | `.css` |

### Conflict-detection signals — Sciter-specific

- `url(stock:<name>)` → non-canonical scheme; append to `notes` per template in [URL Schemes](#url-schemes) above.

## Icon Naming Algorithm

When `sciter-create-component` Phase 2A downloads SVG assets, file names must follow this convention. Convert Figma `layerName` to kebab-case SVG filename:

1. Remove section prefix (`"Icon / "`, `"Icons / "`, `"Ic "`)
2. Replace `/` and spaces with `-`
3. Lowercase everything
4. Add `.svg`

```text
"Icon / <Name> / Normal"  → <name>-normal.svg
"Icon / <Name> / Active"  → <name>-active.svg
"Ic_<Name>"               → ic-<name>.svg
"<Name> icon"             → <name>-icon.svg
```

Icon names must describe **purpose**, not appearance (`close.svg` not `x-shape.svg`).

## Decision Matrix

Used by `sciter-create-component` Phase 2B to pick the code template per `(connection × color_change)`. Header-comment in the generated file cites which row was applied and why.

> 🔑 **Preferred Sciter columns are `css-fill` / `css-token-fill` and `css-filter`.** Swap columns (`svg-swap-display`, `js-src-swap`) are **fallback only** — pick them only when CSS pseudo cannot express the trigger. `js-src-swap` cells additionally require `this.componentUpdate()` in the event handler that mutates state — see [Sciter Reactor Re-render Rule](#sciter-reactor-re-render-rule).

| connection \ color_change | `none` | `css-fill` / `css-token-fill` ✓ | `css-filter` ✓ | `svg-swap-display` ⚠ fallback | `js-src-swap` ⚠ fallback |
| ---- | ---- | ---- | ---- | ---- | ---- |
| `img-tag` | Single `<img>` with static SVG | n/a (raster) | `foreground-image-transformation: brightness(N)` in state pseudo | Two `<img>` (default + active) + CSS `display:` toggle | Single `<img>`; parent `ICONS = { id: {normal, active} }` map |
| `css-foreground-image` | `foreground-image: url(...)` static | n/a for raster; valid for vector SVG | `foreground-image-transformation: ...` in state pseudo | Swap `foreground-image: url(...)` in state pseudo | Re-render parent with new CSS variable `--icon-url` |
| `css-foreground-icon` | `foreground-image: icon(name)` | `fill: var(--icon-color)` + state tokens | n/a | Re-emit `foreground-image: icon(other)` per state | Re-render with new `icon(name)` value via CSS var or inline `style=` |
| `css-foreground-path` | `background-image: path(...)` | `fill: var(--icon-color)` | n/a | Re-emit `path(...)` per state | Same as `css-foreground-icon` JS-state column |
| `@image-map` | `image-map(map, name)` | n/a (raster) | `foreground-image-transformation: ...` | Re-reference different cell per state | Re-render with new cell name via JS state |

If `wrapper_component.name` is populated, the generator emits `<WrapperName name={icon} state={state} />` instead of the raw markup — wrapper internals are out of scope.

## Project Archetypes

Real combinations observed in production Sciter codebases. Detector follows the project's pattern; user can override via Phase 2B interactive choice. The **Rule** column captures the Sciter-project rule from [Sciter Idiomatic Method](#sciter-official-recommended-method).

| Archetype | Connection | Color-change | Trigger | When observed | Rule |
| ---- | ---- | ---- | ---- | ---- | ---- |
| C | `css-foreground-image` | CSS-pseudo `foreground-image:` redeclaration | CSS pseudo | Projects following the official Sciter foreground-image idiom; all state via pseudo-classes | ✓ **Recommended baseline** — new components should target this |
| A | `img-tag` (`__DIR__`-rooted) | `css-filter` (`foreground-image-transformation` or `filter:`) | CSS pseudo | Toolbar/menu icons; state is interactive (hover/focus); no per-item active-selection | ✓ Acceptable — CSS-pseudo-driven |
| B | `img-tag` (`__DIR__`-rooted) | `js-src-swap` (parent `ICONS` map + `componentUpdate()`) | JS state | List/nav widgets with persistent selection state | ⚠ Discouraged for new code — swap-based; reach for it only when the trigger is JS-only and CSS pseudo cannot reach it. Even then, prefer mounting the same swap on a `css-foreground-image` connection with `:current`/`:checked` redeclaration over a JS-driven `<img src=>` swap. |

### Common conflict signals across archetypes

- **Docs-vs-code divergence:** project ships a checklist mandating one method while shipped components use another → detector follows code; `notes` flags divergence for user attention.
- **Non-canonical URL scheme** (`url(stock:<name>)`): see [URL Schemes](#url-schemes).
- **Dormant scaffold vs removed precedent:** when both an active state-driven swap (e.g. `ICONS` map + `componentUpdate()`) and a removed-precedent CSS-toggle exist, the active scaffold takes priority — new work follows what currently mutates state.

## Cross-References

### Upstream Sciter docs

- [CSS properties](https://docs.sciter.com/docs/CSS/properties) — full property reference
- [Paths and vector images](https://docs.sciter.com/docs/CSS/paths-and-vector-images) — `icon()`, `path()`, vector content
- [URL Sciter schemes](https://docs.sciter.com/docs/URL-sciter-schemes) — `home://`, `this://`, `sciter:`, etc.
- [Reactor / component-update](https://docs.sciter.com/docs/Reactor/component-update) — `this.componentUpdate()` semantics

### Sibling references in this plugin

- `plugins/docs-creator/docs/reference-icon-patterns.md` — framework-agnostic enum schema + universal detection signals
- `plugins/component-creator/docs/reference-sciter-css.md` — Sciter CSS layout/positioning specifics
- `plugins/component-creator/docs/reference-component-decompose.md` — icon detection inside composite components
