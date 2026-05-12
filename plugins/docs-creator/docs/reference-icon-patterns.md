---
description: "Cross-framework icon connection enums and grep/AST detection signals used by design-system-scanner. Source of truth for the icon_pattern field shape and detection heuristics."
---

# Icon Patterns — Detection Reference

> Read by `design-system-scanner` agent during `analyze-frontend`. Defines the canonical enum values and detection signals that produce the `design_system.icon_pattern` block of `.claude/state/frontend-analysis.json`.
>
> Sciter-specific syntax mapping for these enums lives in `plugins/component-creator/docs/reference-sciter-icons.md` and is consumed by `sciter-create-component`. This file is framework-agnostic.

## Connection Enum

How icons get into the DOM. Detector picks the **dominant** value (most occurrences across components).

| Value | Description | Frameworks |
| ---- | ---- | ---- |
| `img-tag` | Bare `<img src="...">` referencing an asset file | React, Vue, Svelte, Sciter, plain HTML |
| `img-imported-svg` | SVG imported as a module + rendered via `<img src={imported} />` | React + bundler, Vue + Vite |
| `css-foreground-image` | CSS `foreground-image: url(...)` (Sciter-specific property) | Sciter |
| `css-foreground-icon` | CSS `foreground-image: icon(name)` or `icon(vbox; d-path)` | Sciter |
| `css-foreground-path` | CSS `background-image: path(d-commands)` | Sciter |
| `css-background-image` | CSS `background-image: url(...)` | React + CSS, Vue, Tailwind `bg-[url(...)]`, fallback for Sciter |
| `inline-svg` | `<svg>...</svg>` rendered directly in component JSX/template | React, Vue, Svelte |
| `inline-svg-use-sprite` | `<svg><use xlinkHref="sprite.svg#id"/></svg>` referencing a sprite atlas | React, Vue, Sciter (rare) |
| `icon-wrapper-component` | Project-local wrapper (e.g. `<Icon>`, `<ImageSprite>`, `<SvgIcon>`) that renders one of the above | React, Vue |
| `icon-library` | Third-party icon library import (`lucide-react`, `@heroicons/react`, etc.) | React, Vue |
| `@image-map` | Sciter `@image-map` at-rule + `image-map(map, name)` reference | Sciter |

## Color-Change Enum

How icon color shifts for hover / active / disabled / theme changes.

| Value | Mechanism | Compatible connections |
| ---- | ---- | ---- |
| `none` | No state-driven color change | any |
| `svg-swap-display` | Two `<img>` (default + active); CSS `display: none/block` toggle on state pseudo | `img-tag`, `img-imported-svg` |
| `css-filter` | CSS `filter: brightness/hue-rotate/invert/...` on the element | raster sources: `img-*`, `css-background-image`, `css-foreground-image` (Sciter: `foreground-image-transformation`) |
| `css-fill` | `fill: <color>` hard-coded per state pseudo | vector content: `inline-svg`, `inline-svg-use-sprite`, `css-foreground-icon`, `css-foreground-path` |
| `css-token-fill` | `fill: var(--icon-color)` + token override per state/theme | same as `css-fill` |
| `css-foreground-color` | `foreground-color: <color>` on Sciter elements (NOTE: this is a semi-transparent overlay, not a tint — flag in `notes` if used for tinting) | Sciter only |
| `icon-prop` | Prop passed into wrapper (`<Icon color={...}>`) | `icon-wrapper-component`, `icon-library` |
| `currentColor` | SVG uses `fill="currentColor"`, parent CSS sets `color:` | `inline-svg`, `inline-svg-use-sprite` (depends on `<use>` semantics) |

## Detection Signals

Stack-aware grep / regex patterns. `design-system-scanner` first reads the `tech-stack-profiler` output to know the stack (Sciter / React / Vue / Angular), then runs the relevant signal set below.

### Connection signals

| Enum | Signal | File extensions |
| ---- | ---- | ---- |
| `img-tag` | `<img\s+src=["']` (plain string src, not bracket-interpolated) | `.tsx`, `.jsx`, `.htm`, `.html`, `.vue`, `.svelte` |
| `img-tag` (Sciter) | `<img\s+src=\{?\s*__DIR__\s*\+\s*["']img\/` (Sciter widget pattern) | `.js` (inside Sciter JSX) |
| `img-imported-svg` | `import\s+\w+\s+from\s+["'][^"']+\.svg["']` paired with `<img\s+src=\{\w+\}` for the same identifier | `.tsx`, `.jsx`, `.vue` |
| `css-foreground-image` | `foreground-image:\s*url\(` | `.css`, `.scss` |
| `css-foreground-icon` | `foreground-image:\s*icon\(` | `.css` |
| `css-foreground-path` | `(foreground\|background)-image:\s*path\(` | `.css` |
| `css-background-image` | `background-image:\s*url\(` | `.css`, `.scss`, `.module.css` |
| `inline-svg` | `<svg[^>]*>[\s\S]*?</svg>` literally in JSX/template (not imported) | `.tsx`, `.jsx`, `.vue`, `.svelte` |
| `inline-svg-use-sprite` | `<use\s+[^>]*(?:xlinkHref\|href)=` | `.tsx`, `.jsx`, `.vue`, `.svelte`, `.htm` |
| `icon-wrapper-component` | Component file matching `**/[Ii]con*.{tsx,jsx,vue}` or `**/[Ss]vg*.{tsx,jsx,vue}` or `**/[Ii]mage[Ss]prite*` whose render tree contains `<svg>`, `<img>`, or `<use>`; require 2+ usages elsewhere in project | n/a — structural |
| `icon-library` | `import\s+.*\s+from\s+["']@?(lucide-react\|@heroicons/react\|react-icons\|@tabler/icons-react\|@mui/icons-material\|@radix-ui/react-icons\|lucide-vue\|@vicons)` | `.tsx`, `.jsx`, `.ts`, `.js`, `.vue` |
| `@image-map` | `@image-map\s+[\w-]+\s*\{` | `.css` |

Scoring rule: for each enum, count grep matches across all component files; pick the value with the highest count. If two values tie or are within 20% of each other, record the runner-up in `examples` and mention the split in `notes`.

### Color-change signals

| Enum | Signal | File extensions |
| ---- | ---- | ---- |
| `svg-swap-display` | CSS rule sequence: `display:\s*none` on one selector AND `display:\s*block` on a sibling selector under the same `:hover`/`:current`/`:checked` parent, where both selectors target `<img>`/`<svg>` children | `.css`, `.scss` |
| `css-filter` | `:hover\b[^}]*\{[^}]*filter:\s*(brightness\|hue-rotate\|invert\|saturate\|grayscale)` OR Sciter `foreground-image-transformation:` inside a state pseudo | `.css` |
| `css-fill` | `:hover\b[^}]*\{[^}]*fill:\s*#` (hex literal fill in state pseudo) | `.css` |
| `css-token-fill` | `:hover\b[^}]*\{[^}]*fill:\s*var\(` (var-token fill in state pseudo) | `.css` |
| `css-foreground-color` | `:hover\b[^}]*\{[^}]*foreground-color:` (Sciter — flag as overlay misuse if applied to icon container) | `.css` |
| `icon-prop` | Prop drilling pattern: usage `<Icon\s+[^>]*color=\{[^}]+\}` | `.tsx`, `.jsx`, `.vue` |
| `currentColor` | `fill=["']currentColor["']` in inline `<svg>` OR `fill:\s*currentColor` in CSS | `.tsx`, `.svg`, `.css` |

If no state-driven color change is detected → `color_change: "none"`.

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
- For Sciter projects: also branch-named docs like `chore/update-claude-docs` (rare — only if file exists in current branch's tree)

If a doc prescribes method X but observed code uses method Y → append to `notes`:

```
Code uses <Y>; project rule "<doc path>" mandates <X>. Detector follows code; user should reconcile.
```

If a project uses an undocumented or non-canonical URL scheme (e.g. `url(stock:...)` in Sciter — `stock:` is not a documented Sciter scheme) → append:

```
Non-recommended pattern: <description>. Reference: <official-docs-URL>.
```

## Cross-References

- Sciter syntax mapping for the enums above: `plugins/component-creator/docs/reference-sciter-icons.md`
- Component-creation template format that embeds `icon_pattern`: `plugins/docs-creator/rules/component-creation-template-format.md`
- Standalone-doc format for `.claude/docs/reference-icon-connection.md`: `plugins/docs-creator/rules/icon-connection-doc-format.md`
