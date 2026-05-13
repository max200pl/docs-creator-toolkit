---
description: "Cross-framework icon connection enums and grep/AST detection signals used by design-system-scanner. Source of truth for the icon_pattern field shape and detection heuristics."
---

# Icon Patterns — Detection Reference

> Read by `design-system-scanner` agent during `analyze-frontend`. Defines the canonical enum values and detection signals that produce the `design_system.icon_pattern` block of `.claude/state/frontend-analysis.json`.
>
> Framework-specific enum values, syntax mappings, and stack-specific detection signals are defined in framework adapter docs under `plugins/component-creator/docs/`. The scanner reads this file first, then loads the adapter doc matching the detected stack (`framework_hint`) for any framework-specific values listed below.

## Connection Enum

How icons get into the DOM. Detector picks the **dominant** value (most occurrences across components).

| Value | Description | Scope |
| ---- | ---- | ---- |
| `img-tag` | Bare `<img src="...">` referencing an asset file | Universal — any HTML-rendering framework |
| `img-imported-svg` | SVG imported as a module + rendered via `<img src={imported} />` | Bundler-based frameworks (Vite/webpack/Rollup) |
| `css-background-image` | CSS `background-image: url(...)` | Universal CSS |
| `inline-svg` | `<svg>...</svg>` rendered directly in component JSX/template | Universal JSX/template |
| `inline-svg-use-sprite` | `<svg><use xlinkHref="sprite.svg#id"/></svg>` referencing a sprite atlas | Universal SVG |
| `icon-wrapper-component` | Project-local wrapper (e.g. `<Icon>`, `<ImageSprite>`, `<SvgIcon>`) that renders one of the above | Universal — component-based frameworks |
| `icon-library` | Third-party icon library import (e.g. `lucide-react`, `@heroicons/react`) | Framework with package ecosystem |
| `css-foreground-image` | Non-standard CSS property `foreground-image: url(...)` | Framework-specific — see adapter doc |
| `css-foreground-icon` | Non-standard CSS function `foreground-image: icon(name)` or `icon(vbox; d-path)` | Framework-specific — see adapter doc |
| `css-foreground-path` | Non-standard CSS function `background-image: path(d-commands)` | Framework-specific — see adapter doc |
| `@image-map` | Custom `@image-map` at-rule + `image-map(map, name)` reference | Framework-specific — see adapter doc |

## Color-Change Enum

How icon color shifts for hover / active / disabled / theme changes.

| Value | Mechanism | Compatible connections |
| ---- | ---- | ---- |
| `none` | No state-driven color change | any |
| `svg-swap-display` | Two `<img>` (default + active); CSS `display: none/block` toggle on state pseudo | `img-tag`, `img-imported-svg` |
| `js-src-swap` | Single `<img>` per slot; parent holds a state-keyed map of URLs, computes new `src` per state and passes as prop; child re-renders | `img-tag`, `img-imported-svg`, `icon-wrapper-component` |
| `css-filter` | CSS `filter: brightness/hue-rotate/invert/...` on the element | raster sources: `img-*`, `css-background-image`, `css-foreground-image` |
| `css-fill` | `fill: <color>` hard-coded per state pseudo | vector content: `inline-svg`, `inline-svg-use-sprite`, `css-foreground-icon`, `css-foreground-path` |
| `css-token-fill` | `fill: var(--icon-color)` + token override per state/theme | same as `css-fill` |
| `icon-prop` | Prop passed into wrapper (`<Icon color={...}>`) | `icon-wrapper-component`, `icon-library` |
| `currentColor` | SVG uses `fill="currentColor"`, parent CSS sets `color:` | `inline-svg`, `inline-svg-use-sprite` (depends on `<use>` semantics) |
| `css-foreground-color` | Non-standard CSS property `foreground-color: <color>` — framework-specific overlay (NOT a fill tint) | Framework-specific — see adapter doc |

## Detection Signals

Stack-aware grep / regex patterns. `design-system-scanner` first reads the `tech-stack-profiler` output to know the stack, then runs the universal signal set below **plus** the framework-specific signal set from the matching adapter doc (when one applies).

### Connection signals — universal

| Enum | Signal | File extensions |
| ---- | ---- | ---- |
| `img-tag` | `<img\s+src=["']` (plain string src, not bracket-interpolated) | `.tsx`, `.jsx`, `.htm`, `.html`, `.vue`, `.svelte` |
| `img-imported-svg` | `import\s+\w+\s+from\s+["'][^"']+\.svg["']` paired with `<img\s+src=\{\w+\}` for the same identifier | `.tsx`, `.jsx`, `.vue` |
| `css-background-image` | `background-image:\s*url\(` | `.css`, `.scss`, `.module.css` |
| `inline-svg` | `<svg[^>]*>[\s\S]*?</svg>` literally in JSX/template (not imported) | `.tsx`, `.jsx`, `.vue`, `.svelte` |
| `inline-svg-use-sprite` | `<use\s+[^>]*(?:xlinkHref\|href)=` | `.tsx`, `.jsx`, `.vue`, `.svelte`, `.htm` |
| `icon-wrapper-component` | Component file matching `**/[Ii]con*.{tsx,jsx,vue}` or `**/[Ss]vg*.{tsx,jsx,vue}` or `**/[Ii]mage[Ss]prite*` whose render tree contains `<svg>`, `<img>`, or `<use>`; require 2+ usages elsewhere in project | n/a — structural |
| `icon-library` | `import\s+.*\s+from\s+["']@?(lucide-react\|@heroicons/react\|react-icons\|@tabler/icons-react\|@mui/icons-material\|@radix-ui/react-icons\|lucide-vue\|@vicons)` | `.tsx`, `.jsx`, `.ts`, `.js`, `.vue` |

Framework-specific connection signals (e.g. for non-standard CSS properties or stack-specific asset-path conventions) are listed in the matching adapter doc.

Scoring rule: for each enum, count grep matches across all component files (both universal and framework-specific signals); pick the value with the highest count. If two values tie or are within 20% of each other, record the runner-up in `examples` and mention the split in `notes`.

### Color-change signals — universal

| Enum | Signal | File extensions |
| ---- | ---- | ---- |
| `svg-swap-display` | CSS rule sequence: `display:\s*none` on one selector AND `display:\s*block` on a sibling selector under the same `:hover`/`:current`/`:checked` parent, where both selectors target `<img>`/`<svg>` children | `.css`, `.scss` |
| `js-src-swap` | An object/map of `{ id: { normal: <url>, active: <url> } }` (or similar `{ default, active, hover }` shape) in JS, paired with a render expression like `src={icons.active}` / `src={isActive ? a : b}` driven by component state | `.js`, `.jsx`, `.tsx`, `.vue` |
| `css-fill` | `:hover\b[^}]*\{[^}]*fill:\s*#` (hex literal fill in state pseudo) | `.css` |
| `css-token-fill` | `:hover\b[^}]*\{[^}]*fill:\s*var\(` (var-token fill in state pseudo) | `.css` |
| `icon-prop` | Prop drilling pattern: usage `<Icon\s+[^>]*color=\{[^}]+\}` | `.tsx`, `.jsx`, `.vue` |
| `currentColor` | `fill=["']currentColor["']` in inline `<svg>` OR `fill:\s*currentColor` in CSS | `.tsx`, `.svg`, `.css` |

Framework-specific color-change signals (e.g. for non-standard CSS overlays or filter properties) are listed in the matching adapter doc.

If no state-driven color change is detected (after running both universal and framework-specific signal sets) → `color_change: "none"`.

## Wrapper Component Heuristic

`design-system-scanner` reports `wrapper_component: { name, path }` when ALL of:

1. A component file exists whose default export name matches `/^(Icon|Svg.*|Image.*|.*Icon|.*Sprite)$/` (case-insensitive).
2. Its render tree contains at least one of: `<svg>`, `<img>`, `<use>`, `image-map()`.
3. It is **used** from 2+ other components (grep for `<WrapperName\s` or import + invocation).

Otherwise `wrapper_component: { name: null, path: null }`.

## Conflict Detection (populates `notes`)

After determining `connection` and `color_change` from code, scan project documentation for divergent rules:

- `**/.claude/rules/**.md` containing the words `icon`, `foreground-image`, `<img>`, `fill:`, etc.
- `**/checklist*.md`
- Project `README.md`, `CONTRIBUTING.md`, `*conventions*.md`

If a doc prescribes method X but observed code uses method Y → append to `notes`:

```text
Code uses <Y>; project rule "<doc path>" mandates <X>. Detector follows code; user should reconcile.
```

If a project uses an undocumented or non-canonical URL scheme for icon assets → append:

```text
Non-recommended pattern: <description>. Reference: <official-docs-URL>.
```

Framework-specific conflict checks (non-canonical schemes, misused properties) are listed in the matching adapter doc.

## Framework Adapter Docs

For each framework with non-standard icon mechanisms, an adapter doc under `plugins/component-creator/docs/` provides:

- Syntax mapping for the framework-specific enum values listed above
- Framework-specific detection signals (connection + color-change)
- Framework-specific conflict-detection signals
- Generation rules and the decision matrix used by `component-creator`

The scanner loads the adapter doc whose framework matches `tech-stack-profiler`'s `framework_hint`.

## Cross-References

- Component-creation template format that embeds `icon_pattern`: `plugins/docs-creator/rules/component-creation-template-format.md`
- Standalone-doc format for `.claude/docs/reference-icon-connection.md`: `plugins/docs-creator/rules/icon-connection-doc-format.md`
