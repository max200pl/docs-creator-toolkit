# Component-Creation Template Format

## Rule

The `/analyze-frontend` skill's primary output is a single narrative file — `.claude/docs/reference-component-creation-template.md` in the target project — that serves as **the context envelope for a downstream component-creation agent**.

This rule defines the required shape of that file. Other frontend-analysis artefacts (design system, inventory, data flow, architecture) are **supporting reference data** that the template cross-links to via `@`-imports, not independent deliverables.

## Why a single primary artefact

When a downstream agent is tasked with "create a new `<Name>` component", it reads ONE file — this template — and gets a complete actionable recipe. The alternative (read 5 files, reconstruct a recipe from raw detection data) wastes context, invites reconstruction errors, and produces inconsistent output across agent invocations.

The template is **prescriptive** ("do this"), not descriptive ("this exists"). It is **framework-idiomatic** (the recipe reflects the actual framework's conventions, not generic OOP patterns). It ends with a **concrete skeleton** — 20-50 lines of real code that compiles on the target project's toolchain.

## Required shape

The template file MUST contain the following sections, in this order, with these exact headings. Sections that are not applicable (e.g., "Data wiring" for a pure static site) are written with a single line stating the reason — not omitted.

### Frontmatter (optional)

```yaml
---
generated-by: analyze-frontend
plugin-version: <x.y.z>
frontend-root: <project-relative path>
framework: <name-version>
ts: <iso-8601>
---
```

### H1 — `# How to Create a Component in <Project-Or-Frontend-Name>`

One sentence describing the scope: single-frontend project vs one frontend out of multi-frontend monorepo.

### `## File layout`

Concrete path, filename casing, co-located files.

| Field | Example value | Notes |
| ---- | ---- | ---- |
| File path | `src/components/<PascalCase>/<PascalCase>.tsx` | include actual prefix / folder structure |
| Casing | `PascalCase.tsx` / `kebab-case.tsx` / `snake_case.tsx` | observed in existing components |
| Co-located files | `<Component>.test.tsx`, `<Component>.stories.tsx`, `<Component>.module.css` | only what is actually conventional here — skip hypotheticals |
| Barrel file? | `src/components/index.ts` required / optional / absent | observed |

### `## Imports block`

Canonical top-of-file imports that new components use. NOT an exhaustive list — the PATTERN.

````markdown
```tsx
import { useState, type FC } from "react"
import { cn } from "@/lib/utils"
import type { ButtonProps } from "@/components/ui/button"
```
````

Include project-specific aliases (`@/`, `~/`, `src/`). Include framework-specific imports if load-bearing.

### `## Props declaration`

Exact pattern:

- `interface` vs `type` — pick the one the project consistently uses
- Naming suffix — `<Name>Props` (most common) or alternative
- Default-vs-named export — state the project's rule
- `extends HTMLAttributes<...>` — if the project patterns components after DOM primitives
- Ref-forwarding convention — `forwardRef` wrap always / opt-in / never

### `## Styling model` — THE critical section

State ONE primary styling approach that new components MUST follow:

- `tailwind-utilities-inline` — no custom class names, no `.module.css`. Utilities directly in `className=`. Use `cn()` for conditional composition.
- `css-modules` — create `<Component>.module.css` next to the component; `import styles from "./<Component>.module.css"`; `className={styles.button}`.
- `css-in-js-styled-components` — `const StyledX = styled.button\`...\``; no `.css` files for this component.
- `css-in-js-emotion` — `const xStyle = css\`...\`` OR `sx={{...}}` prop.
- `vanilla-css-bem` — global stylesheet, BEM naming `.component__element--modifier`.
- `vanilla-scss-modules` — `.scss` co-located, `@import` partials, scoped via build.
- `shadcn-copy-with-cva` — `components/ui/<name>.tsx` with `cva("base", {variants})`; file is copy-pasteable and editable in-place.
- `framework-scoped` — SFC scoped styles (Vue `<style scoped>`, Svelte `<style>` block).
- `mixed` — explicitly describe which model applies per area (e.g., "Tailwind for `ui/`; SCSS modules for `pages/`").

### `## Class naming`

Say what the class-naming rules ARE, and crucially whether **custom class names exist at all**:

- `none-tailwind-only` — no custom classes. Utility classes composed inline. Custom class creation is **forbidden**.
- `bem` — block `.component`, element `.component__part`, modifier `.component--state`. Project-wide.
- `css-modules-auto` — class names are local scope; camelCase in `.module.css`; never reference globally.
- `styled-var-name` — no class names for user-authored; variable names like `StyledButton` carry the identity.
- `cva-variants` — base class + variant-specified class composition.
- `cn-helper-composition` — `cn("base", variant === "primary" && "primary-class")`.
- `custom-prefix` — e.g., `app-button`, `sciter-asset-bridge-button`; state the prefix.

The "**are classes even used?**" question must have a definitive one-sentence answer.

### `## State and data wiring`

- **Local state**: what's the default (useState / reactive / signal / store.subscribe)?
- **Global app state**: where (Zustand store / Redux / Context / Pinia / SvelteKit writable)?
- **Server data**: how (TanStack Query in a hook / RTK Query endpoint / `load` function / Server Action)?
- **Where the query/mutation lives** (in-component OR in a `api.ts` file next to components OR in `features/<feature>/api/`)?
- **Form state**: which library or pattern?

Each item: one-sentence rule + reference to the authoritative file (`@.claude/sequences/frontend-data-flow.mmd`, `@src/stores/auth.ts`).

### `## Event handling`

- Event-handler prop naming: `on<Event>` vs `handle<Event>` vs custom
- Typed events: `(e: React.MouseEvent<HTMLButtonElement>) => void` OR simplified
- Callback prop signatures for custom events from component up: `(value: T) => void`

### `## Accessibility patterns`

Only if observed in existing code — otherwise one line "No systematic a11y patterns observed; follow WAI-ARIA defaults."

- ARIA attributes — which ones are systematically used (`aria-label`, `aria-expanded`, `role`)
- Keyboard handling — Enter/Space on clickable non-buttons, Escape on modals
- Focus management — programmatic focus calls, focus-trap libraries, etc.

### `## Test and story conventions`

- Test file location: co-located `<Component>.test.tsx` OR `__tests__/<Component>.tsx` OR no tests
- Test runner + assertion style: Vitest + Testing Library, Jest + enzyme, etc.
- Story file: `<Component>.stories.tsx` present? If so — CSF3 vs CSF2, typical story structure

If the project has neither tests nor stories — say so plainly. A new component MUST follow suit unless user explicitly asks for coverage.

### `## Design-token usage`

Short: point to design-system rule, don't duplicate the palette.

`See @.claude/rules/frontend-design-system.md for the full palette, spacing, and typography scale.`

Then give 1-2 **examples** of how an existing component actually references tokens, so the agent pattern-matches:

````markdown
```tsx
<button className="bg-brand-500 text-white px-4 py-2 rounded-md hover:bg-brand-600">
```
````

### `## Framework-specific idioms`

Fed by the `framework-idiom-extractor` subagent. Not generic — specific to the detected framework + its version. Examples:

- **Next.js 14 App Router**: `"use client"` directive only where needed; prefer Server Components. Data fetching inline in Server Components via native `fetch`; client mutations via Server Actions in same file.
- **Vue 3 with `<script setup>`**: `defineProps<{ ... }>()` typed; no `data()` function; emit via `defineEmits()`.
- **Sciter JS**: every component C++ class derives `AssetBaseComponent`; method signatures open with `LOG_CALL()`; internal dispatches via `RpcClientHolder::Kernel::Instance()`.
- **Angular**: standalone component default since v14; `input()` signal inputs since v17; use `ChangeDetectionStrategy.OnPush` per project convention.

### `## Canonical skeleton`

A **real, copy-pasteable** ~20-50-line component that compiles on the target project's toolchain. Not pseudocode. Not abstracted. The agent uses this as its primary pattern-matching anchor.

Must include:

- Top-of-file imports matching the project's conventions
- Props type declaration
- Actual body using the project's styling model, state model, event handlers
- Export at the bottom matching the project's convention

Take the skeleton from an existing, high-quality component in the project (component-inventory subagent identifies a good candidate) — paraphrase identifiers to placeholders, keep structure verbatim.

### `## Anti-patterns`

Only patterns that exist in the project's legacy code that new components MUST NOT imitate. Each item: the pattern + why + where to look if curious.

If no anti-patterns detected: write "No observable anti-patterns at the component layer."

### `## Feature data flows`

Present only when `feature_flows` is non-null in `frontend-analysis.json`. If absent, omit the section entirely.

A table of the detected feature-flow patterns and links to per-pattern sequence diagrams:

```markdown
| Feature | Pattern | Diagram |
| ---- | ---- | ---- |
| <FeatureName> | <pattern> | [sequences/features/<pattern>.mmd](.claude/sequences/features/<pattern>.mmd) |
```

Provide one row per feature in `feature_flows.features[]`. Group rows by pattern (all `scan-loop` rows together, then `query-display`, etc.).

After the table, one sentence per detected pattern that names the key actors (e.g., "The scan-loop pattern wires `ResidualFilesView` → `ResidualFilesAsset` (C++ kernel) → events back.").

If `feature_flows.trivial == true`: write "No user-facing feature boundaries detected — project is a component library or static site."

### `## Cross-references`

A compact bullet list of supporting files the agent may consult for deeper context:

- `@.claude/rules/frontend-design-system.md` — tokens, palette, typography
- `@.claude/rules/frontend-components.md` — component conventions rule (activates on component paths)
- `@.claude/docs/reference-architecture-frontend.md` — full architecture + routing + SSR boundaries
- `@.claude/docs/reference-component-inventory.md` — inventory of existing components to reuse
- `@.claude/sequences/frontend-data-flow.mmd` — top-level state + API data-flow diagram
- `@.claude/sequences/features/<pattern>.mmd` — per-pattern feature flow (one file per detected pattern)

## Size Target

Template target size: **150-300 lines**. Longer means too descriptive (move details to reference files). Shorter means too terse (a new agent won't have enough to pattern-match).

## What This File Is NOT

- A full style guide (that's `frontend-design-system.md`)
- A component catalog (that's `reference-component-inventory.md`)
- An architecture doc (that's `reference-architecture-frontend.md`)
- A data-flow diagram (that's `frontend-data-flow.mmd`)

It is: **the single document a component-creation agent reads to know how to create a correct component in THIS project.**

## Enforcement

`/sleep` check for this file when the target project has `reference-component-creation-template.md`:

- All required sections present (by `## <heading>` match)
- Canonical skeleton section contains a fenced code block ≥ 15 lines
- No `<TODO>` / `{{placeholder}}` / "not yet determined" phrases
- Cross-references use `@` prefix for files in the same project
- Size between 150 and 300 lines inclusive

Flag `[WARN]` per missing section. The file is regenerated by `/analyze-frontend` or `/update-docs --refresh frontend:template`, not hand-edited.
