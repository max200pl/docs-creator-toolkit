# Changelog

All notable changes to the `claude-docs-creator` plugin. Format loosely follows [Keep a Changelog](https://keepachangelog.com) and [Semantic Versioning](https://semver.org).

## 0.12.0 — 2026-04-21

M8 v2 pivot — `/analyze-frontend` reframed as **context envelope for downstream component-creation agents**, not as generic frontend documentation.

### The pivot

Previous framing: `/analyze-frontend` produces 5 independent artefacts (design system, inventory, architecture, data flow, components rule) — a downstream agent would have to read all of them and reconstruct a recipe for creating new components.

New framing: `/analyze-frontend` produces **one primary file** — `.claude/docs/component-creation-template.md` — a prescriptive, framework-idiomatic recipe that a component-creation agent reads first. The 4 previous artefacts are supporting reference data cross-linked from the template.

### Added

- **`rules/component-creation-template-format.md`** — public-layer rule specifying the primary output's shape: required sections (File layout, Imports, Props, Styling model, Class naming, State wiring, Events, A11y, Tests, Design tokens, Framework idioms, Canonical skeleton, Anti-patterns, Cross-references), size target (150-300 lines), concrete-skeleton requirement (must include 20-50 lines of copy-pasteable code). `/sleep` can enforce shape once the enforcement section is implemented.
- **`agents/framework-idiom-extractor.md`** — new 7th subagent. Critically uses **pattern-first detection**, not framework whitelist. Works on BOTH industry frameworks (Next, Vue, SvelteKit, Angular, Remix, Astro, Solid, Qwik, etc.) AND custom in-house frameworks (like Sciter-JS `AssetBaseComponent` patterns). Classifies as `industry` / `custom` / `vanilla`; emits prescriptive framework-specific rules for new-component creation.

### Changed

- **`skills/analyze-frontend/SKILL.md`** — execution reframed as **two-wave fan-out**:
  - **Wave 1 (serial gate per frontend)**: `tech-stack-profiler` establishes `stack_profile` including `framework`, `rendering_mode`, `styling_model`, `class_naming`, `state_libs[]`.
  - **Wave 2 (parallel, stack-informed)**: 6 specialists (5 old + new `framework-idiom-extractor`) receive `stack_profile` so their scans narrow. `design-system-scanner` skips `styled-components` lookup when Wave 1 says Tailwind. `component-inventory` globs `.vue` vs `.tsx` based on framework. Etc.
  - **Assembly**: orchestrator builds `component-creation-template.md` from Wave 1 + Wave 2 per the new rule.

- **`agents/tech-stack-profiler.md`** — return shape now includes explicit `styling_model` (enum: `tailwind-utilities-inline` / `css-modules` / `css-in-js-styled-components` / `shadcn-copy-with-cva` / `framework-scoped-sfc` / `sciter-scss-local` / etc.) and `class_naming` (enum: `none-tailwind-only` / `bem` / `css-modules-auto` / `styled-var-name` / `cva-variants` / `cn-helper-composition` / `custom-prefix` / `auto-scoped` / etc.). These fields drive the primary template's Styling and Class-naming sections — the downstream agent uses them to know whether custom class names exist in this project at all.

- **`sequences/analyze-frontend/analyze-frontend.mmd`** — reflects the two-wave flow: serial Wave 1 participant (TSP), parallel Wave 2 participant (Wave2 group), primary-template assembly phase before supporting references.

### Primary deliverable for downstream agents

`.claude/docs/component-creation-template.md` — reads like a recipe:

1. WHERE new component files go (framework-specific path convention)
2. HOW to import (path aliases, barrel files)
3. Props declaration pattern (interface vs type, naming, forwardRef convention)
4. **Styling model** (Tailwind utilities inline / CSS Modules / etc.)
5. **Class naming** (including "are classes even used?" definitively answered)
6. State and data wiring (where useState is OK, where global state goes, how fetching is done)
7. Event handling conventions
8. Framework-specific idioms (industry OR custom, extracted from code)
9. **Canonical skeleton** — 20-50 lines of real code from the project, copy-pasteable
10. Anti-patterns to avoid
11. Cross-references to supporting files (tokens, architecture, inventory, data-flow)

Downstream agent reads this ONE file, gets complete actionable context. No reconstruction, no guessing.

### Why custom-framework support matters

Many real projects have proprietary or in-house component frameworks (custom React wrappers, Sciter-JS AssetBaseComponent patterns, internal Angular CLI extensions, etc.). A whitelist approach to framework detection would classify all of these as `unknown` and skip framework-specific guidance — exactly when prescriptive guidance is most needed. Pattern-first detection reads the code, classifies `industry | custom | vanilla`, and extracts idioms from the base class / factory definition directly for custom cases.

## 0.11.2 — 2026-04-21

Auto-patch-bump in the publish GitHub Action — removes the "forgot-to-bump" mistake class.

### Added

- `.github/workflows/publish-plugin.yml` now inspects private and public plugin versions before sync. If a plugin-layer change reached `main` without an explicit bump in `.claude-plugin/plugin.json`, the Action automatically bumps **patch** in the public repo's manifests (`plugin.json` + both fields in `marketplace.json`). Public commit message documents the auto-bump with the before/after versions. Manual `minor`/`major` bumps in the private repo are detected (version mismatch) and respected — no double-bump.

### Changed

- Private and public plugin versions may diverge by patch increments after the first auto-bump. This is by design: private tracks author-intent releases (minor/major bumps), public tracks every distribution checkpoint. Release-engineering discipline for `minor`/`major` bumps stays fully manual — edit `plugin.json` in the private repo as before.

### Release-workflow summary

| Change type | Where author edits version | What happens |
| ---- | ---- | ---- |
| Docs typo, small fix, dependency tweak | — (don't edit version) | On push, GHA auto-bumps patch in public. |
| New feature, scoped rule, new subagent | — (don't edit version — auto-patch is fine) OR manual bump minor in private | Public advances to the same minor as private, or to next patch. |
| Breaking change to skill API | Manual bump major in private's `plugin.json` before push | Public matches private's new major version. |

## 0.11.1 — 2026-04-21

Public-distribution preparation + /init-project hotfix.

### Added

- `LICENSE` (MIT) at repo root.
- `CHANGELOG.md` — version history.
- `.github/workflows/publish-plugin.yml` — GitHub Action that syncs the plugin-layer (skills/, agents/, rules/, docs/, sequences/, hooks/, output-styles/, .claude-plugin/, README, LICENSE, CHANGELOG) from the private dev repo to a public distribution repo on each `main` push.

### Fixed

- **B3** — `/init-project` Interactive Wizard no longer asks the user what language to use for generated docs. Generated docs MUST be English per `rules/docs-english-only.md`; the question was redundant and could produce non-compliant output.
- **B4** — `/init-project`, `/update-docs`, `/analyze-frontend` Report-phase instructions now inline the exact first-line metadata template with negative constraints. Previous indirection through "see `rules/report-format.md`" led to a real divergence where one LLM emitted JSON-in-comment with alias keys (`run_ts`, `artefact_count`) instead of the key=value format (`ts`, `artefacts`).
- **G8** — per-phase timestamp capture in all three orchestrator skills is now REQUIRED (was "optional but preferred"). A bash template is inlined to reduce ambiguity.

### Changed

- `plugin.json` and `marketplace.json` `homepage` + `repository` fields updated to point to the public distribution repo URL.

### Housekeeping

- Scrubbed `pc_cleaner` product-name references from 3 public-layer files (`.claude/docs/milestones.md`, `agents/module-documenter.md`, `skills/init-project/SKILL.md`) per `rules/no-project-context.md`. Replaced with generic "reference monorepo" / `<project>/<module-name>` placeholders. Historical data in gitignored `.claude/state/reports/` retains the real name as an internal record.

## 0.11.0 — 2026-04-21

M8 — Frontend Analysis Suite + `/sleep` Batch 1.

### Added

- `skills/analyze-frontend/SKILL.md` — orchestrator: detect frontend root(s), fan out to 5 specialist subagents in parallel per frontend, collect results, write scoped `.claude/` artefacts, update root `CLAUDE.md` Architecture section, emit run report.
- `sequences/analyze-frontend/analyze-frontend.mmd` — flow diagram.
- Six new subagents in `agents/`: `frontend-detector` (gating), `tech-stack-profiler`, `design-system-scanner`, `component-inventory`, `data-flow-mapper`, `architecture-analyzer`.
- `/init-project` Pass-2b frontend detection: sets `has_frontend` flag + candidate roots; end-of-run dashboard offers `/analyze-frontend` (y/n/d) when applicable.
- `/update-docs --refresh frontend[:area]` flag — thin wrapper that delegates to `/analyze-frontend [--only <area>]`.
- `/status` extension: conditional "Frontend Analysis" section with per-artefact freshness + targeted `--refresh` suggestion on stale.
- `/sleep` Batch 1 — four new lint checks surfaced by `/distill`: orchestrator skills must reference `rules/report-format.md`; `agents/*.md` frontmatter schema (`name`, `description`, `tools`, `model`); version-bump-pending (committed + uncommitted delta since last `plugin.json` version change); sequence-diagram subagent participants must match a real agent file.

### Changed

- `skill-scopes.md`, `two-layer-architecture.md`, `menu/SKILL.md`, `architecture-overview.mmd` — manifests reflect new skill + 6 new public agents.

## 0.10.0 — 2026-04-21

Close M2: subagent delegation verified.

### Summary

Fan-out refactor in `/init-project` Generate-module-docs phase delivered unexpected but valuable outcome on reference-monorepo baseline: wall-clock parity (+2%, within noise) but +41% richer module docs and 5 real codebase issues surfaced via subagent Notes. Reframed M2 success criteria from wall-clock reduction to context reduction + depth. Detailed comparison in internal `.claude/state/reports/postchange-m2.md`.

## 0.9.1 — 2026-04-21

Fan-out `module-documenter` in `/init-project` Generate phase.

### Added

- `agents/module-documenter.md` — read-only per-module subagent returning `{summary_row YAML, claude_md_content markdown body}` with `SKIP` sentinel for trivial modules.
- `.claude/docs/subagent-fanout-pattern.md` — toolkit-maintainer reference documenting the fan-out decision heuristic, return-shape contract, pitfalls, checklist, and M8 applicability.

### Changed

- `skills/init-project/SKILL.md` Generate-module-docs phase — delegates per-module deep-scan + `CLAUDE.md` generation to parallel `module-documenter` subagents via the fan-out pattern.
- `sequences/init-project/generation-and-report.mmd` — `loop` → `par` block.
- `.claude/agents/skill-architect.md` — gains explicit fan-out rule + report-phase rule.

## 0.9.0 — 2026-04-21

Report-phase for orchestrator skills.

### Added

- `rules/report-format.md` — public-layer rule: report path (`.claude/state/reports/<skill>-<ts>.md`), filename convention, first-line machine-diff metadata contract, required body sections.
- Report-phase in `/init-project` and `/update-docs` — persists run dashboard to a gitignored file per the new rule.

### Changed

- `/init-project` gitignore block now includes `.claude/state/` so generated reports never accidentally commit.

## 0.8.0 — 2026-04-20

Initial plugin packaging (M5 — partial).

### Added

- `.claude-plugin/plugin.json` manifest.
- `.claude-plugin/marketplace.json` marketplace manifest with `source: "./"` so the repo IS the marketplace.
- Plugin-layout migration from `.claude/<subdir>/` to repo-root `<subdir>/` for all public-layer content.
- `hooks/hooks.json` extracted from `.claude/settings.json`, paths use `${CLAUDE_PLUGIN_ROOT}`.

### Known

- No LICENSE file yet (to be added in 0.11.1).
- No CHANGELOG yet (to be added in 0.11.1).
- Release discipline (semver tags, migration docs) formalized in 0.11.1.
