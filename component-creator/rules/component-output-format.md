---
description: "Output format rules for create-component — naming conventions, file layout, registry entry schema, and component-done checklist shape. Read from naming_conventions frontmatter in reference-component-inventory.md when available; these are the generic defaults."
---

# Component Output Format

> Generic defaults. Adapter-specific overrides (dip units, flow: layout, @mixin) live in the adapter's own SKILL.md.
> naming_conventions source: `token_file:` frontmatter in `frontend-design-system.md` + `naming_conventions:` in `reference-component-inventory.md`

## Naming Conventions

Read `naming_conventions:` from `reference-component-inventory.md` frontmatter first. These are the generic fallbacks.

| Item | Convention | Example |
| ---- | ---- | ---- |
| Folder | `kebab-case` | `left-panel/` |
| JS file | `kebab-case`, matches folder | `left-panel.js` |
| CSS file | `kebab-case`, matches folder | `left-panel.css` |
| Preview file | `<name>.preview.js`, co-located | `left-panel.preview.js` |
| Code Connect file | `<name>.figma.{ext}`, discovered from primitive | `left-panel.figma.ts` |
| Component class | `PascalCase` of folder name | `LeftPanel` |
| CSS root class | folder name | `.left-panel` |
| CSS child classes | BEM | `.left-panel__icon--active` |
| Icon files | `kebab-case` + state suffix | `scan-normal.svg`, `scan-active.svg` |
| Tokens | `--{category}-{variant}` | `--color-primary`, `--space-md` |

**Rules:**
- Folder, JS, and CSS names must match exactly
- Derive names from Figma component name — never use generic names (`Frame123`, `Group456`)
- Icon names describe purpose, not appearance (`close.svg` not `x-shape.svg`)
- For components with special chars in Figma name: apply `naming_conventions.component_file` rule, show converted name to user for confirmation (EC6)

## File Layout

```text
<layer>/<slice-name>/
├── <slice-name>.js          ← main component (public API)
├── <slice-name>.css
├── <slice-name>.preview.js  ← isolated demo, co-located with component
├── <slice-name>.figma.{ext} ← Code Connect (format discovered from primitive)
├── ui/                      ← private sub-components (optional)
│   ├── <sub>.js
│   └── <sub>.css
├── model/                   ← state / signals (optional)
└── img/                     ← local SVG assets only
```

**`<layer>`** — one of the FSD layers detected in `reference-component-creation-template.md`:

| Layer | Contents | Import rule |
| ---- | ---- | ---- |
| `shared/ui` | Generic primitives, no business logic | imported by all layers |
| `entities` | Domain objects | imports shared only |
| `features` | User interactions | imports entities + shared |
| `widgets` | Composite UI blocks | imports features + entities + shared |
| `pages` | Full page views | imports widgets and below |

Import direction is one-way: pages import widgets, never reverse. Determine layer from `reference-component-creation-template.md` `## Component Placement Rules` section if present; otherwise classify by scope and dependencies (EC7 reads `styling_system` for wiring, not layer).

## Registry Entry Schema

Write after Phase 4 completes. `figma_connected` updated to `true` after Phase 5 Code Connect publish.

```json
{
  "name": "<PascalCase>",
  "type": "primitive | feature | local",
  "layer": "<fsd-layer>",
  "path": "<relative-path-from-project-root>/",
  "figma_node_id": "<nodeId>",
  "figma_file_key": "<fileKey>",
  "figma_connected": false,
  "uses": [],
  "parent": null,
  "created_at": "<ISO-UTC>",
  "last_verified_at": null,
  "last_figma_sync_at": null,
  "figma_last_modified": null,
  "ssim_score": null,
  "status": "in-progress"
}
```

**`type` classification:**

| Type | Criteria |
| ---- | ---- |
| `primitive` | lives in `shared/ui` or has a generic UI name (Button, Input, Badge, Icon) |
| `feature` | lives in `entities/`, `features/`, `widgets/` or has a domain-specific name |
| `local` | lives inside another component's `ui/` subdirectory (child/nested) |

**`status` values:** `in-progress` → `done` → `stale` → `needs-review`
- `stale` is auto-set by `validate-registry` when `figma_last_modified` > `last_figma_sync_at`

**Registry is the source of truth** — never scan filesystem to check component existence. Always load `component-registry.json`.

## Component-Done Checklist

Run in Phase 2 Stream B after generating files. All sections must pass before Phase 3.

| Section | Checks |
| ---- | ---- |
| **FSD structure** | Layer correct, import direction respected, no reverse imports |
| **Naming** | Folder = JS = CSS names match; class = PascalCase of folder; no generic names |
| **Code correctness** | Component renders; no syntax errors; all imports resolve |
| **CSS correctness** | No hardcoded colors or spacing (must use tokens); no values that exist as tokens |
| **Design system tokens** | All colors/spacing/typography from token file via CSS vars |
| **Sizing** | All dimensions from Figma (no magic numbers) |
| **Visual accuracy** | Component matches Figma reference (verified by Phase 3 adapter) |
| **Architecture** | No business logic in `shared/ui`; state in `model/` if complex |
| **Registry** | Entry written to `component-registry.json` with correct type/layer/path |
| **Code Connect** | `.figma.{ext}` file present and published (Phase 5) |

Checklist output format — one line per section:

```text
[PASS] FSD structure — layer: shared/ui, no reverse imports
[PASS] Naming — left-panel matches folder/js/css
[FAIL] CSS correctness — hardcoded #2d2d2d on line 14 (should use --color-surface-dark)
[PASS] Design system tokens — 8 tokens used, 0 hardcoded colors
[SKIP] Visual accuracy — no adapter visual_verify configured
[PASS] Registry — entry written, status: in-progress
[SKIP] Code Connect — pending Phase 5
```

A `[FAIL]` blocks advancing — fix before proceeding. A `[SKIP]` is non-blocking.

## Anti-Patterns

Never do these in generated output:

- **Never** use filesystem scan instead of registry to check component existence
- **Never** hardcode colors/spacing/sizing that exist as design tokens
- **Never** use CDN URLs for icon assets — always download locally to `img/`
- **Never** place preview files in the project repo root — keep co-located with component
- **Never** build a parent component before its children exist in registry
- **Never** create primitives silently inside a composite build — flag and stop
- **Never** use `px` units in component CSS — always use the unit system from `styling_system.type`
- **Never** use generic Figma auto-generated names as component names
