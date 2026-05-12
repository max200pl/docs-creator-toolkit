---
description: "Sciter.js icon connection methods, color-change patterns, naming, and the decision matrix used by sciter-create-component Phase 2B. Single source of truth for icon-related rules in this plugin."
---

# Sciter.js — Icon Connection Reference

> Read by `sciter-create-component` Phase 2A/2B and `update-component`. Cross-referenced from `reference-sciter-css.md` and `reference-component-decompose.md`.

## Schema Contract — `icon_pattern`

This block is the canonical shape produced by docs-creator's `analyze-frontend` (`design-system-scanner` agent) and consumed by `sciter-create-component`. Any change here must be synced with `plugins/docs-creator/docs/reference-icon-patterns.md`.

```yaml
icon_pattern:
  connection: <enum | null>
    # img-tag | img-imported-svg | css-foreground-image
    # css-foreground-icon | css-foreground-path | css-background-image
    # inline-svg | inline-svg-use-sprite
    # icon-wrapper-component | icon-library
  color_change: <enum | null>
    # svg-swap-display | css-filter | css-fill
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

## Sciter Official Recommended Method

Sourced from official Sciter documentation. Used as fallback baseline when a project has no detected icon convention (greenfield) or when the user explicitly opts in via the interactive strategy choice in `sciter-create-component` Phase 2B.

### Canonical embedding

Sciter docs treat **`foreground-image` + vector content** as the idiomatic method. Stock icons via `icon:name`, custom inline icons via `icon(vbox; d-path)`, external SVG via `url(...)`.

> "icon(name)" — stock icon function. "icon(vbox; d-path)" — custom icon function where _vbox_ is a string that contains 4 numbers = the position and dimension, in user space, of an [SVG] viewport, and _d-path_ are path commands of d attribute in SVG.
> — https://docs.sciter.com/docs/CSS/paths-and-vector-images

```css
/* Stock icon */
icon.heart { foreground-image: icon(heart); }

/* Custom inline icon */
icon.heart {
  foreground-image: icon(0 0 100 100;M 10,30 A 20,20 0,0,1 50,30
    A 20,20 0,0,1 90,30 Q 90,60 50,90 Q 10,60 10,30 z);
  foreground-repeat: no-repeat;
  foreground-size: contain;
  fill: none;
  stroke: red;
  stroke-width: 1px;
}

/* External SVG file */
button.save { foreground-image: url(this://app/img/save.svg); }
```

### URL schemes that exist (correct)

| Scheme | Use | Source |
| ---- | ---- | ---- |
| `icon:name` | Stock icon catalogue | https://docs.sciter.com/docs/CSS/paths-and-vector-images |
| `path:d-commands` | Inline SVG path data | same |
| `home://` | Relative to `sciter.dll`/exe location | https://docs.sciter.com/docs/URL-sciter-schemes |
| `this://app/` | packfolder archive (typical for shipped apps) | same |
| `file://` | Local filesystem | same |
| `sciter:resource` | Embedded Sciter resources (e.g. `sciter:icon-alert.png`) | same |

### URL schemes that do NOT exist

| Scheme | Status |
| ---- | ---- |
| `stock:` | **Not documented in Sciter docs.** If a project uses `url(stock:name)`, that is either a typo for `icon:name` or undocumented behavior — `notes` should flag it as `non-recommended` |

### Color tinting — what works, what does not

> "highlight element by defining semitransparent foreground-color: rgba(255,0,0,0.5)"
> — https://docs.sciter.com/docs/CSS/properties

- `foreground-color` is **NOT a fill tint** — it is a semi-transparent overlay drawn on top of element content. Do not use it expecting it to tint an SVG.
- `fill: <color>` works on vector content produced by `icon()`/`path()`/inline `<svg>` — NOT on raster `foreground-image: url(file.png)`.
- `foreground-image-transformation: brightness()/hue()/saturation()/contrast()/gamma()/opacity()/flip-x()/flip-y()` is the canonical way to recolor raster icons via filters (analogous to CSS `filter`).
- `currentColor` and `var(--token)` on `fill:` — **not explicitly documented** for Sciter vector images. Treat as untested.

### State-driven changes (hover / active / checked / disabled)

Sciter docs do not provide a dedicated icon-state mechanism. Use standard CSS state pseudo-classes to change `fill`, `stroke`, or swap `foreground-image`:

```css
button { foreground-image: icon(arrow-right); fill: var(--icon-color); }
button:hover     { fill: var(--icon-color-hover); }
button:disabled  { fill: var(--icon-color-disabled); }
button:checked   { foreground-image: icon(check); }
```

## Connection Methods (Sciter)

Five Sciter-applicable values for `icon_pattern.connection`:

| Enum value | Syntax | When to use | Sciter-recommended? |
| ---- | ---- | ---- | ---- |
| `img-tag` | `<img src={__DIR__ + "img/icon.svg"}>` | Icon is the entire content of an element (no surrounding text/buttons) | Allowed but not idiomatic — see Decision Matrix |
| `css-foreground-image` | `foreground-image: url(this://app/img/icon.svg)` in CSS | Icon decorates an interactive element (button, menu item) | ✓ Idiomatic |
| `css-foreground-icon` | `foreground-image: icon(name)` (stock) or `icon(vbox; d-path)` (custom) | Stock icon or inline d-path; no external file | ✓ Most idiomatic for stock + inline |
| `css-foreground-path` | `background-image: path(d-commands)` | Inline SVG path on background (rare) | Niche |
| `css-background-image` | `background-image: url(...)` | Backwards-compat / non-Sciter projects | Discouraged for Sciter — `foreground-image` is preferred |
| `@image-map` | `@image-map` at-rule + `image-map(map, name)` reference | Many small icons from one sprite atlas | ✓ For sprites |

## Color-Change Methods (Sciter)

Five Sciter-applicable values for `icon_pattern.color_change`:

| Enum value | Mechanism | Works with | Notes |
| ---- | ---- | ---- | ---- |
| `svg-swap-display` | Two `<img>` elements per state; CSS `display: none/block` toggle on `:hover`/etc. | `img-tag` connection only | Most reliable for raster icons; doubles asset count |
| `css-filter` | `foreground-image-transformation: brightness(N)` or `filter: brightness(N)` | Any raster icon | Coarse — only luminance/hue shifts |
| `css-fill` | `fill: <color>` in state pseudo-class | `css-foreground-icon`, inline `<svg>`, `path()` content | Cleanest for vector content |
| `css-token-fill` | `fill: var(--icon-color)` + token override per state | Vector content + design tokens | Most maintainable; not explicitly documented but works in practice |
| `css-foreground-color` | `foreground-color: <color>` | **DO NOT USE for tinting** — see Sciter Official section above | Common mistake; this is an overlay, not a tint |

## Icon Naming Algorithm

Moved verbatim from `reference-component-decompose.md` (was lines 206-222). When `sciter-create-component` Phase 2A downloads SVG assets, file names must follow this convention.

Convert Figma `layerName` to kebab-case SVG filename:

1. Remove section prefix (`"Icon / "`, `"Icons / "`, `"Ic "`)
2. Replace `/` and spaces with `-`
3. Lowercase everything
4. Add `.svg`

```
"Icon / <Name> / Normal"  → <name>-normal.svg
"Icon / <Name> / Active"  → <name>-active.svg
"Ic_<Name>"               → ic-<name>.svg
"<Name> icon"             → <name>-icon.svg
```

Icon names must describe **purpose**, not appearance (`close.svg` not `x-shape.svg`).

## Decision Matrix

Used by `sciter-create-component` Phase 2B to pick the code template per `(connection × color_change)`. Header-comment in the generated file cites which row was applied and why.

| connection \ color_change | `none` | `svg-swap-display` | `css-fill` / `css-token-fill` | `css-filter` |
| ---- | ---- | ---- | ---- | ---- |
| `img-tag` | Single `<img>` with static SVG | Two `<img>` (default + active) + CSS `display:` toggle | Not applicable (raster `<img>` does not respond to `fill:`) | `foreground-image-transformation: brightness(N)` in state pseudo |
| `css-foreground-image` | `foreground-image: url(...)` static | Swap `foreground-image: url(...)` in state pseudo | Not applicable for raster; valid for vector SVG | `foreground-image-transformation: ...` in state pseudo |
| `css-foreground-icon` | `foreground-image: icon(name)` | Re-emit `foreground-image: icon(other)` per state | `fill: var(--icon-color)` + state tokens | n/a |
| `css-foreground-path` | `background-image: path(...)` | Re-emit `path(...)` per state | `fill: var(--icon-color)` | n/a |
| `@image-map` | `image-map(map, name)` | Re-reference different cell per state | n/a (sprite is raster) | `foreground-image-transformation: ...` |

If `wrapper_component.name` is populated, the generator emits `<WrapperName name={icon} state={state} />` instead of the raw markup — wrapper internals are out of scope.

## Real-Project Reality Notes

Two reference Sciter projects use **different** methods. Detector treats both as valid and follows the project's pattern; user can override via the interactive strategy choice in Phase 2B.

### sciterjsMacOS

- **Connection:** `img-tag` — `<img src={__DIR__ + "img/icon-state.svg"}>` (e.g. `res/widgets/aside-panel/aside-panel.js:5-6`)
- **Color change:** `svg-swap-display` — two `<img>` elements per state, CSS toggles `display: none/block` on `:hover` (e.g. `res/widgets/aside-panel-nav-bar/ui/aside-panel-nav-bar-item.css:40-52`)
- **Outlier:** one component uses `css-filter` (`filter: brightness(100)` for close-button hover, `res/widgets/caption-bar/ui/caption-bar-menu-button.css:21-23`)
- **No wrapper component** — every widget imports icon constants locally
- **Conflict — fed into `icon_pattern.notes`:** the project's `chore/update-claude-docs` branch contains `checklist-component-done.md` that mandates `foreground-image` for new components, but no shipped component follows that rule. Detector reports both — code reality (`img-tag`) wins; `notes` flags the docs-vs-code conflict for user attention. Resolution is out of scope.

### my-sciter-app

- **Connection:** `css-foreground-image` — `foreground-image: url(images/test.svg)` (e.g. `toolbar/tool-bar.css:12`)
- **Color change:** native CSS state pseudos (`:hover`, `:current`, `:checked`, `:disabled`) directly swap `foreground-image` (e.g. `menu/menu-bar.css:52,65-79`)
- **Quirk — fed into `notes`:** uses `url(stock:checkmark)` which is **not** a documented Sciter URL scheme (see "URL schemes that do NOT exist" above). Likely a project shortcut or typo for `icon:checkmark`. Detector flags as `non-recommended` so the generator can offer the official Sciter recommendation as an alternative in the interactive choice.
- **No wrapper component** — pure CSS approach
