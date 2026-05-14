---
description: "Sciter.js component styling — 4-step stepper for detection and generation. Same numbered order in design-system-scanner (analyze) and sciter-create-component Phase 2B (emit). Single source of generator rules and detected-pattern decisions."
---

# Sciter.js — Styling Stepper

> **Role:** strategy / flow doc — *how* to apply Sciter CSS mechanisms in component generation. Companion **base** doc with mechanism syntax: [`reference-sciter-css.md`](reference-sciter-css.md) (properties + `@set` / `@mixin` / `@const` / `--var` syntax in § Style Organization).
>
> Consumed by: **`design-system-scanner`** (analyze direction, Steps 1→4) AND **`sciter-create-component`** Phase 2B (generate direction, Steps 1→4 with append at Step 1 wiring).
> Other companion files: [`reference-sciter-layout-strategy.md`](reference-sciter-layout-strategy.md) for layout recipes, [`reference-sciter-icons.md`](reference-sciter-icons.md) for icon strategy.
> Full upstream-research provenance (toolkit-internal): [`research-sciter-stylesets.md`](../../../.claude/docs/research-sciter-stylesets.md), [`research-sciter-styling-patterns.md`](../../../.claude/docs/research-sciter-styling-patterns.md), [`research-sciter-style-encapsulation.md`](../../../.claude/docs/research-sciter-style-encapsulation.md).

## Reading Guide

| Section | When to read |
| ---- | ---- |
| [Stepper Overview](#stepper-overview) | Quick reference of the 4-step flow and what each step produces / consumes |
| [Step 1 — Topology](#step-1--topology) | File layout (`<comp>.css` location) + `@import` topology |
| [Step 2 — Scope](#step-2--scope) | `@set` vs plain class decision + encapsulation type |
| [Step 3 — Naming](#step-3--naming) | BEM block derivation + sub-component naming convention |
| [Step 4 — Ingredients](#step-4--ingredients) | Tokens (`--var`) + Typography (`@mixin`) |
| [Project-Observed Conventions](#project-observed-conventions) | What the reference Sciter project actually does (Sciter default) |
| [Cross-References](#cross-references) | Companion docs, research provenance, upstream Sciter docs |

## Stepper Overview

Both **detection** (`design-system-scanner` analyzes existing project) and **generation** (`sciter-create-component` Phase 2B emits new component) execute these 4 steps in the same order. Step 1 has a generation-time append at the very end (writing `@import` to main entry).

| # | Step | What | Detection produces | Generation consumes |
| ---- | ---- | ---- | ---- | ---- |
| **1** | **Topology** | Where CSS files live + how `@import` is organized | `css_file_layout`, `import_strategy`, `main_entry` | Decides new file path; at end of generation appends `@import` to `main_entry` |
| **2** | **Scope** | Does project use `@set` wrapper? What encapsulation mechanism? | `styleset_usage`, `encapsulation.scope` | Picks `@set` per variant or plain BEM class; sets encapsulation type |
| **3** | **Naming** | BEM block prefix + sub-component naming convention | `encapsulation.naming_prefix_pattern`, `encapsulation.sub_component_naming` | Derives block name; enforces BEM rules on every selector |
| **4** | **Ingredients** | Tokens (`--var`) + typography (`@mixin`) | `token_file`, `typography_file`, `typography_mechanism` | Inside rules: references existing `--var` and `@mixin`; appends new ones to `token_file`/`typography_file` |

> **Dependency direction:** Step N depends on Step N-1's output. Step 1 must run first because all later decisions assume a known file path. Step 4 is the leaf — values referenced inside rules whose shell came from Steps 1–3.

## Step 1 — Topology

> "Where does the CSS file live and where does its `@import` go?" — the foundation of every other decision.

### Detection

```text
1. Glob **/*.css under frontend root.
2. For each .css file, check sibling for <name>.js / <name>.tsx / <name>.vue:
   - Sibling present → "co-located"
   - No sibling but file lives in src/styles or similar → "centralized"
3. Grep `@import` across all .css files:
   - Find files containing @import statements
   - If exactly 1 file → "main-entry-aggregate"; that file is main_entry
   - If most component CSS files have @imports → "per-component-inline"
   - Else → "mixed"
4. Note import order in main_entry (tokens / typography / pages / widgets / ui)
   — captured as a hint for Step 1 append logic.
```

### Schema output

```yaml
css_file_layout: <"co-located" | "centralized" | "mixed">
import_strategy: <"main-entry-aggregate" | "per-component-inline" | "mixed">
main_entry: <relative path | null>          # populated when import_strategy = "main-entry-aggregate"
```

### Generation

**At Phase 2B start:**

- Read `css_file_layout` and `main_entry` from `frontend-analysis.json`
- Decide new component CSS file path:
  - `co-located` + component: `<layer>/<component>/<component>.css`
  - `co-located` + sub-component: `<parent-layer>/<parent>/ui/<sub>.css`
  - `centralized`: `<centralized-dir>/<component>.css`
- Decide JS file path next to it (same dir)

**At Phase 2B end (after Steps 2–4 produced file contents):**

- Append `@import "<relative-path>";` to `main_entry`
- Order group: insert in the correct section (after `tokens.css` + `typography.css`; with widgets before sub-components; pages with pages)

### Rules

- **Forbidden:** `@import` inside a component CSS file. Sciter's `@font-face` URL resolution breaks if `@import` lives in an imported file.
- **Forbidden:** `@font-face` declared inside a component CSS file. Always in `main_entry` before any other `@import`.
- **Required:** every new component CSS path appended to `main_entry`'s `@import` list — generator failure if missing.
- **Required:** import order in `main_entry`: `tokens.css → typography.css → pages → widgets → ui/`.

## Step 2 — Scope

> "Should this component be wrapped in `@set`, or just a plain BEM class?" — gating decision that shapes Step 3.
> Syntax of `@set` / `style-set:` / `styleset=`: see [`reference-sciter-css.md` § Style Organization](reference-sciter-css.md#style-organization-at-rules).

### Detection

```text
1. Count occurrences of @set declarations:
   - grep `@set\s+\w+` across all .css files → S
2. Count occurrences of style-set applications:
   - grep `style-set\s*:` across all .css files → C
   - grep `styleset\s*=` across all .js/.jsx/.tsx files → J
3. Count total CSS rules in project:
   - approx: count `{ ... }` blocks at top level across all .css files → R
4. Compute ratio: (S + C + J) / R
   - < 1%  → styleset_usage: "none"
   - 1-10% → styleset_usage: "occasional"
   - > 10% → styleset_usage: "primary"

5. Determine encapsulation.scope:
   - If any style-set: / styleset= present → "prefixed-class"
     (BEM is still used INSIDE sets; sets layer on top)
   - Inspect top-level selectors per file: if ≥80% share a block prefix
     (e.g. all selectors in popover-menu-item.css start with .popover-menu-item)
     → "prefixed-class"
   - If [data-*=] attribute selectors are the dominant pattern → "data-attribute"
   - Else → "global" (rare; flag in notes)
```

### Schema output

```yaml
styleset_usage: <"none" | "occasional" | "primary">
encapsulation:
  scope: <"global" | "prefixed-class" | "data-attribute">
```

### Generation

| `styleset_usage` detected | Phase 2B behaviour |
| ---- | ---- |
| `"none"` | Always emit plain BEM class. Never `@set`. Matches reference project default. |
| `"occasional"` | Emit BEM by default. **Interactive prompt** when component has 2+ visual variants: *"Use `@set` (matches existing project sets) or modifier classes (matches majority pattern)?"* Record choice in registry. |
| `"primary"` | Default to `@set` per variant. Use parent inheritance for shared base: `@set ghost < primary`. Prompt only when component has 1 variant. |

### Rules

- **Required when emitting `@set`:** use default `content-isolate: isolate`. Never `none` without explicit user request.
- **Forbidden:** mixing `@set` for some variants and modifier classes for others within the same component — pick one mechanism per component.
- **Encapsulation invariant:** `encapsulation.scope` stays `"prefixed-class"` regardless of `styleset_usage`. BEM applies inside `@set` (descendants get block prefix) AND inside plain class.
- **`@set` override caveat:** external rules cannot override `@set` declarations without `!important`. If generator detects user later needs to override, surface this in agent-memory (see `feedback_ssim_styleset.md`).

## Step 3 — Naming

> "What's the block prefix for this component? How are sub-components named?" — applies inside whichever scope Step 2 chose.

### Detection

```text
1. For each component .css file, identify the dominant top-level selector prefix:
   - Strip leading `.`, take first segment up to `__`, `--`, or whitespace
   - Verify: ≥80% of top-level selectors in the file share this prefix
2. Determine naming_prefix_pattern:
   - If prefix == kebab-case(component-name-derived-from-file-path) → pattern is "<component-name>"
   - Else record actual pattern observed

3. Sub-component naming detection:
   - For each <parent>/ui/<sub>.css file, read its dominant block selector
   - If block name == <parent>-<sub> → "namespaced"
   - If block name == <parent>__<sub> → "chained"
   - No <parent>/ui/ sub-components found → "none"
   - Mix → record dominant; flag split in notes

4. Verify BEM dialect: confirm presence of `.<block>__<elem>` and `.<block>--<mod>` selectors
   - Absence is a yellow flag (project uses non-BEM convention; may need alternative naming rules)
```

### Schema output

```yaml
encapsulation:
  naming_prefix_pattern: <string template, e.g. "<component-name>">
  sub_component_naming: <"namespaced" | "chained" | "none">
```

### Generation

**Block name derivation:**
- `block = kebab-case(component-name)`
- Sub-component block: `<parent>-<sub>` (namespaced) or `<parent>__<sub>` (chained) per detected convention

**Selector emission rules (BEM):**
- All top-level selectors prefixed with block class: `.popover-menu-item`, `.popover-menu-item__icon`, `.popover-menu-item--active`
- Elements: `.<block>__<element-name>`
- Modifiers: `.<block>--<modifier-name>`
- State compound: `.<block>--<state> .<block>__<element>` — repeat block name, don't collapse
- Pseudo-classes attach to block or modifier: `.<block>:hover`, `.<block>--<modifier>:hover`

### Rules

**Forbidden (generator MUST auto-reject):**
- Bare generic selectors: `.icon`, `.label`, `.row`, `.title`, `.active`, `.disabled`
- Bare pseudo-class rules: `:hover { ... }`, `:checked { ... }`
- Class names without block prefix
- Sub-component as element when a dedicated file exists for it

**Required:**
- Every top-level selector starts with `<block>` class
- State selectors compound with block class
- Sub-component CSS uses ITS OWN block (per Step 1.5 Decompose result)

## Step 4 — Ingredients

> "What goes inside the rules — colors, sizes, fonts." — leaves of the styling tree, referenced inside selectors built in Step 3.
> Syntax of `@mixin` / `@const` / `--var` / `var()`: see [`reference-sciter-css.md` § Style Organization](reference-sciter-css.md#style-organization-at-rules).

### Detection

```text
1. Find token file:
   - Grep `:root\s*{` across all .css files
   - The file with the most `--*` declarations inside :root is the token_file
   - Record path; list declared --* names

2. Find typography file + mechanism:
   - Grep `@mixin\s+\w+` → if present, the file is the typography mixin source
   - List mixin names (font-xs, font-md-medium, etc.)
   - Set typography_mechanism = "mixin"
   - If no @mixin but components use dedicated typography classes (.text-md, .h1) → "css-class"
   - If most components inline `font-family/size/weight` → "inline"
   - If mixed → "mixed"

3. Inventory usage patterns for Step 4 generation:
   - List which components reference each token (helps token-sync in Phase 1)
   - List which mixins are most used (helps generator pick closest match)
```

### Schema output

```yaml
token_file: <relative path | "none">
typography_file: <relative path | "none">
typography_mechanism: <"mixin" | "css-class" | "inline" | "mixed">
```

### Generation

**Tokens (colors / spacing / radii / shadows / sizes):**
- Each design-value needed by component → look up `--<name>` in `token_file`:
  - **Match found** → emit `var(--name)` in component CSS
  - **No match** → Phase 1 Token sync appends new `--<name>` to `token_file :root`; then emit `var(--name)` in component CSS
- Never declare `--var` inside component CSS unless it's a page-scoped override (rare; surface to user)

**Typography:**
- Each Figma text style → match to existing `@font-*` mixin in `typography_file`:
  - **Match found** → emit `@<mixin-name>;` inside relevant selector
  - **No match** → prompt user to extend `typography.css` with new `@mixin font-<size>[-<weight>]`; do NOT auto-add
- Invocation syntax: `@font-md-medium;` (no parens for basic) or `@like-button(var(--accent));` (with parens for parametric)

### Rules

**Forbidden:**
- `@const` for design tokens (compile-time, not reactive — see [`reference-sciter-css.md` § Style Organization](reference-sciter-css.md#style-organization-at-rules))
- `font:` shorthand with `var()` (silently ignored by Sciter — see [reference-sciter-css.md § Typography](reference-sciter-css.md#typography))
- Hardcoded color/spacing values when a token exists for them
- New `--var` declared inside `__element` or `--modifier` selectors
- New `@mixin` auto-added without user prompt

**Required:**
- Tokens always via `--var`
- Typography always via `@mixin` invocation
- New tokens appended to `token_file :root`
- Order in component CSS: `@mixin` invocations BEFORE rule-specific overrides (mixin redeclaration is order-aware)

## Project-Observed Conventions

Default pattern detected in the reference Sciter project (sciterjsMacOS, 19 CSS files surveyed). New components default to this profile unless detection finds a different project pattern.

```yaml
styling_patterns:
  css_file_layout: "co-located"            # Step 1
  import_strategy: "main-entry-aggregate"   # Step 1
  main_entry: "res/app/main.css"            # Step 1
  styleset_usage: "none"                    # Step 2 — zero @set in reference project
  encapsulation:
    scope: "prefixed-class"                 # Step 2 — pure BEM
    naming_prefix_pattern: "<component-name>"   # Step 3
    sub_component_naming: "namespaced"      # Step 3 — `<parent>-<sub>`, not `<parent>__<sub>`
  token_file: "res/shared/lib/tokens.css"   # Step 4 — single :root for --color-*, --space-*, --radius-*
  typography_file: "res/shared/lib/typography.css"  # Step 4 — 17 @mixin font-* declarations
  typography_mechanism: "mixin"             # Step 4
```

**Reference layout:**

```text
res/
├── app/main.css                            ← main_entry (only @import host)
├── shared/lib/
│   ├── tokens.css                          ← :root { --color-*, --space-*, --radius-* }
│   └── typography.css                      ← @mixin font-* declarations
├── pages/<page>/<page>.css                 ← co-located per page
└── widgets/<widget>/
    ├── <widget>.css                        ← co-located per widget root
    └── ui/<widget>-<sub>.css               ← sub-components in ui/ (namespaced naming)
```

## Cross-References

### Companion plugin docs

- [`reference-sciter-css.md`](reference-sciter-css.md) — pure property-syntax quick-ref (flow, dip, overflow, alignment)
- [`reference-sciter-layout-strategy.md`](reference-sciter-layout-strategy.md) — Figma pattern → Sciter layout recipe
- [`reference-sciter-icons.md`](reference-sciter-icons.md) — icon connection + color-change strategy
- [`reference-sciter-agent-memory.md`](reference-sciter-agent-memory.md) — feedback seed files (incl. `feedback_ssim_styleset.md`)

### Research provenance (toolkit-internal)

- [`research-sciter-stylesets.md`](../../../.claude/docs/research-sciter-stylesets.md) — full `@set`/`@mixin`/`@const`/`--var` upstream semantics
- [`research-sciter-styling-patterns.md`](../../../.claude/docs/research-sciter-styling-patterns.md) — project-pattern survey
- [`research-sciter-style-encapsulation.md`](../../../.claude/docs/research-sciter-style-encapsulation.md) — BEM rules + isolation comparison

### Upstream Sciter docs

- [Style Sets](https://docs.sciter.com/docs/CSS/style-sets)
- [Media, Const, Mixin](https://docs.sciter.com/docs/CSS/media-const-mixin)
- [Variables and Attributes](https://docs.sciter.com/docs/CSS/variables-and-attributes)
