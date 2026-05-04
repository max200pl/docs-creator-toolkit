# Changelog

All notable changes to the `claude-docs-creator` plugin. Format loosely follows [Keep a Changelog](https://keepachangelog.com) and [Semantic Versioning](https://semver.org).

## [Unreleased] — M5 monorepo restructure (2026-04-28)

### Breaking changes

- **Plugin renamed** from `claude-docs-creator` to `docs-creator`. Skills namespace changes accordingly: `/claude-docs-creator:<skill>` → `/docs-creator:<skill>`.
- **Install path changed**: `--plugin-dir ~/Projects/claude-docs-creator` → `--plugin-dir ~/Projects/claude-docs-creator/plugins/docs-creator`.
- **Public distribution repo renamed**: `claude-docs-creator-plugin` → `docs-creator-toolkit`. Install now: `--plugin-dir ~/clone/docs-creator-toolkit/docs-creator`.

### Added

- `plugins/docs-creator/` and `plugins/component-creator/` — true monorepo layout. Each plugin is independently installable and independently published.
- `component-creator` plugin scaffold — placeholder for the upcoming component-creation agent that reads `docs-creator`'s `frontend-analysis.json`.
- `.github/workflows/publish-plugins.yml` — dynamic matrix GHA: detects which plugin changed, syncs only that one to the shared public repo. Minor version bump triggered automatically when a milestone row transitions to `done` in `milestones.md`.
- `.github/workflows/validate-plugins.yml` — PR lint: checks `plugin.json` required fields, semver version format, `README.md` presence, and `SKILL.md` frontmatter including valid `scope` values.
- `scripts/migrate-paths.sh` — one-time migration helper used to rewrite root-level path references in internal `.claude/` docs to the new `plugins/docs-creator/` prefix.

### Migration

See `docs/migration-from-add-dir.md` for step-by-step upgrade instructions for existing users.

---

## 0.15.0 — 2026-04-24

API contracts suite — **detect, document, and spec external communication boundaries**.

### Added

- **`skills/analyze-api-contracts/SKILL.md`** — read-only two-wave fan-out: Wave 1 (`protocol-detector`) discovers all external communication boundaries (HTTP, GraphQL, gRPC, WebSocket, SSE, message queues, custom RPC). Wave 2 invokes `protocol-mapper` once per boundary in parallel. Writes `.claude/state/api-contracts-analysis.json` only — no human-facing docs yet.
- **`skills/create-api-contracts-docs/SKILL.md`** — reads `api-contracts-analysis.json` and materializes `docs/reference-api-contracts.md` (boundary table + per-endpoint details), `sequences/api-data-flow.mmd` (global flow diagram), and per-boundary sequence diagrams in `sequences/api-contracts/`. Optionally updates root `CLAUDE.md` Architecture section.
- **`skills/update-api-contracts-docs/SKILL.md`** — targeted refresh: re-runs the `protocol-mapper` for one specific boundary (by doc name or boundary ID) and merges the result into existing docs without re-scanning the full codebase.
- **`skills/create-api-contract/SKILL.md`** — spec-first contract wizard. Design a new HTTP / GraphQL / WebSocket / custom contract from scratch (no scanning): interactive prompt → writes `docs/contract-<name>.md` + matching sequence diagram.
- **`agents/protocol-detector.md`** — Wave 1 gating agent. Fast first-level scan; returns a list of boundary descriptors with signals (file patterns, import patterns, config keys found) that drive the Wave 2 fan-out.
- **`agents/protocol-mapper.md`** — generic Wave 2 agent. Invoked once per boundary descriptor; maps any protocol type (standard or custom in-house) by following the signals from the detector. Replaces the four fixed-specialist agents from the initial design (`http-mapper`, `auth-mapper`, `realtime-mapper`, `errors-mapper`).
- **`rules/skill-naming.md`** — documents the `analyze-` / `create-` / `update-` triplet pattern, the fixed-specialist vs generic-N× agent decision rule, and agent naming conventions. Enforced by `/sleep`.

### Changed

- `sequences/api-contracts/` — per-boundary sequence diagrams generated alongside the main `api-data-flow.mmd`. Each boundary gets its own `.mmd` file named `<boundary-id>.mmd`.

---

## 0.14.0 — 2026-04-23

### Added

- **`agents/feature-flow-detector.md`** — 8th public subagent. Identifies individual user-facing features in a frontend root and classifies each feature's data flow into one of six universal patterns: `scan-loop`, `query-display`, `settings-rw`, `action-executor`, `orchestrator`, `dashboard`. Works across any stack (React+Redux, Vue+Pinia, Angular+NgRx, Sciter JS+C++, Rust/Tauri, Vanilla JS). Invoked as a Wave 2 specialist by `/analyze-frontend`.

### Changed

- Generated artefact naming convention: files produced by `create-api-contracts-docs`, `create-frontend-docs`, and similar materializer skills now use the `reference-` prefix (e.g. `reference-api-contracts.md`, `reference-component-creation-template.md`) to distinguish toolkit-generated reference material from hand-authored project docs.

---

## 0.13.0 — 2026-04-22

M8 closeout — **frontend suite split into three composable skills** + scope reclassification of toolkit-dev skills.

### Frontend skill split (analyze → create → update)

`/analyze-frontend` used to detect + analyze + write all `.claude/` artefacts in a single run. That made targeted refresh awkward and mixed the read-only "analyze" step with the write-heavy "materialize" step. 0.13.0 separates concerns along the toolkit's existing `init-project` / `create-docs` / `update-docs` pattern:

- **`/analyze-frontend`** — now **read-only**. Runs the two-wave fan-out (stack profile → 6 parallel specialists) and persists structured results to `.claude/state/frontend-analysis.json` (gitignored). Writes **no** user-facing `.md` or `.mmd`. Downstream component-creation agents can consume the JSON directly without parsing markdown.
- **`/create-frontend-docs`** — NEW. Reads `frontend-analysis.json` and materializes it as human-readable artefacts: `component-creation-template.md` (primary envelope) + 4 supporting references (`frontend-design-system.md`, `frontend-components.md`, `architecture-frontend.md`, `component-inventory.md`, `frontend-data-flow.mmd`) + surgical update to root `CLAUDE.md` Architecture section.
- **`/update-frontend-docs <area>`** — NEW. Targeted refresh. Re-invokes the subagent matching `<area>` (valid values: `design-system`, `components`, `data-flow`, `architecture`, `framework-idioms`, `template`), merges fresh data into JSON, regenerates only the affected `.md` / `.mmd`. Replaces the deprecated `/update-docs --refresh frontend[:area]` flag (still works as a thin delegation wrapper for back-compat).

### Added

- **`skills/create-frontend-docs/SKILL.md`** + **`sequences/create-frontend-docs.mmd`** — JSON → artefacts materializer. Preflight validates `frontend-analysis.json` exists + matching `schema_version`; stale JSON (>30 days) prompts before proceeding.
- **`skills/update-frontend-docs/SKILL.md`** + **`sequences/update-frontend-docs.mmd`** — area-scoped refresh. Special `template` area re-assembles `component-creation-template.md` from current JSON without re-running any subagent — useful when `rules/component-creation-template-format.md` changes.
- **`skills/create-sequences/SKILL.md`** + **`sequences/create-sequences.mmd`** — new api skill for users authoring sequence diagrams in their own project's `.claude/sequences/`. Purpose-built wrapper delegating diagram-authoring logic to the internal `/create-mermaid`. Mermaid style rules remain shared via `rules/mermaid-style.md`.

### Changed — scope reclassification

Three previously-shared skills moved from `scope: shared` (public, packaged with plugin) to `scope: internal` (toolkit-dev only, not distributed):

- `/create-mermaid` — was shared; now internal. Reasoning: target-project users need `/create-sequences` (purpose-built for sequence diagrams in `.claude/sequences/`), not a generic Mermaid authoring tool. The generic multi-type authoring is only useful for toolkit-repo maintenance.
- `/research` — was shared; now internal. Toolkit maintainers use this to author research reports informing toolkit rules/roadmap. End users on target projects have no equivalent use case.
- `/create-tutorial` — was shared; now internal. Generates ELI5 tutorials for toolkit onboarding into the toolkit's own `docs/`. Not relevant to target-project work.

File moves: `skills/create-{mermaid,tutorial}/` + `skills/research/` → `.claude/skills/...`. Sequences: `sequences/create-{mermaid,tutorial}.mmd` + `sequences/research.mmd` → `.claude/sequences/...`. Frontmatter now has `scope: internal` + `disable-model-invocation: true` (belt-and-suspenders — physical location already prevents plugin distribution; flag prevents accidental invocation if the dir is attached via `--add-dir`).

### Changed — analyze-frontend refocused

- **`skills/analyze-frontend/SKILL.md`** — reframed as read-only analyzer. Replaces the Assemble-primary-template + Write-supporting-references + Update-CLAUDE.md phases with a single Persist-analysis phase that serializes Wave 1 + Wave 2 outputs to JSON. Merge behavior: full run overwrites JSON; `--only <area>` partial run merges (preserves sections outside the filter).

### Changed — manifests

- **`.claude-plugin/plugin.json`** — description enumerates the 9 api skills (including the three new ones) + 1 shared; calls out the internal skills that stay in the private dev repo; adds `doc-reviewer` to the subagent list (was missing).
- **`.claude/rules/skill-scopes.md`** + **`.claude/rules/two-layer-architecture.md`** — manifest tables reflect the reclassification and the new api skills.
- **`.claude/skills/menu/SKILL.md`** — stale `/update-docs ... --refresh frontend[:area]` row removed; new api skills (`/analyze-frontend` refocused, `/create-frontend-docs`, `/update-frontend-docs`, `/create-sequences`) added to the commands table.
- **`.claude/docs/architecture-overview.mmd`** — nodes for the three new api skills + JSON state node (`frontend-analysis.json`) + wiring edges (analyze → JSON, create reads JSON → writes artefacts, update merges JSON area + regenerates affected artefact).
- **`.claude/docs/milestones.md`** — M8 closed with all three shipment checklists; Current Baseline refreshed (16 total skills: 10 public + 6 internal; 12 subagents: 9 public + 3 internal; rules to 13+).
- **`README.md`** — public skills table reflects 10 public skills (9 api + 1 shared); "What's Inside" block updated (9 subagents, 6 internal skills); maintainer-only list now names all 6 internal skills.

### Changed — doc placement cleanup

Three docs promoted from `.claude/docs/` (internal) to `docs/` (public) to enforce the rule "public artefacts reference only public artefacts":

- `.claude/docs/subagent-fanout-pattern.md` → `docs/reference-subagent-fanout-pattern.md` — previously internal but referenced from 5 public artefacts (`agents/module-documenter.md`, `agents/frontend-detector.md`, `rules/report-format.md`, `skills/analyze-frontend/SKILL.md`, `skills/init-project/SKILL.md`) — those refs were broken for end users whose plugin install has no `.claude/docs/`. Audience line broadened to cover plugin users, not just toolkit maintainers.
- `.claude/docs/reference-keybindings.md` → `docs/reference-keybindings.md` — user-facing `~/.claude/keybindings.json` recommendations belong with other end-user reference docs.
- `.claude/docs/project-docs-review.md` → `docs/checklist-project-docs-review.md` — end-user review checklist after `/init-project` belongs in public `docs/` with the `checklist-` prefix per `rules/docs-folder-structure.md`.

Cross-refs updated in `agents/module-documenter.md`, `agents/frontend-detector.md`, `rules/report-format.md`, `skills/analyze-frontend/SKILL.md`, `skills/init-project/SKILL.md`, `.claude/agents/skill-architect.md`, `.claude/skills/sleep/SKILL.md`, `.claude/skills/menu/SKILL.md`, `.claude/docs/two-claude-workflow.md`, `.claude/docs/milestones.md`, `.claude/rules/two-layer-architecture.md`. Historical M2-checklist bullets in `milestones.md` left as-is (they describe the path at that time).

### Added — broken-link checker (/check-links)

- **`hooks/check-links.sh`** — shared bash scanner. Finds dead relative links in `.md` / `.mmd` files and stale `@`-imports in `CLAUDE.md` / `CLAUDE.local.md`. Skips fenced code blocks, inline code, placeholders (paths containing `<` or `>`), and external URLs. Auto-detects toolkit-vs-target-project context via `.claude-plugin/plugin.json` presence — enables public→internal layer-check only inside the toolkit repo.
- **`skills/check-links/SKILL.md`** (api, new) — user-facing on-demand scanner: `/check-links [project-path]`. Single source of truth with the PostToolUse hook — same script, same rules, no drift.
- **`hooks/hooks.json`** — registers `hooks/check-links.sh` as PostToolUse(Write|Edit). Any `.md` / `.mmd` file Claude writes or edits gets auto-scanned; warnings surface as `systemMessage`, non-blocking.
- **`.claude/skills/check-links/SKILL.md`** (internal, new) — thin internal wrapper over the same script for toolkit-dev use, invoked by `/sleep` pipeline on future integration.

### Added — public /menu (/menu)

- **`skills/menu/SKILL.md`** (api, new) — end-user discovery screen listing all `/claude-docs-creator:*` commands + quick status dashboard. Shows only the public-surface commands (api + shared scopes). Toolkit maintainers' internal `/menu` stays in `.claude/skills/menu/` with the full listing including internal skills.

### Changed — doc placement cleanup

Three docs promoted from `.claude/docs/` (internal) to `docs/` (public) to enforce the rule "public artefacts reference only public artefacts":

- `.claude/docs/subagent-fanout-pattern.md` → `docs/reference-subagent-fanout-pattern.md` — previously internal but referenced from 5 public artefacts (`agents/module-documenter.md`, `agents/frontend-detector.md`, `rules/report-format.md`, `skills/analyze-frontend/SKILL.md`, `skills/init-project/SKILL.md`) — those refs were broken for end users whose plugin install has no `.claude/docs/`. Audience line broadened to cover plugin users, not just toolkit maintainers.
- `.claude/docs/reference-keybindings.md` → `docs/reference-keybindings.md` — user-facing `~/.claude/keybindings.json` recommendations belong with other end-user reference docs.
- `.claude/docs/project-docs-review.md` → `docs/checklist-project-docs-review.md` — end-user review checklist after `/init-project` belongs in public `docs/` with the `checklist-` prefix per `rules/docs-folder-structure.md`.

Cross-refs updated in `agents/module-documenter.md`, `agents/frontend-detector.md`, `rules/report-format.md`, `skills/analyze-frontend/SKILL.md`, `skills/init-project/SKILL.md`, `.claude/agents/skill-architect.md`, `.claude/skills/sleep/SKILL.md`, `.claude/skills/menu/SKILL.md`, `.claude/docs/two-claude-workflow.md`, `.claude/docs/milestones.md`, `.claude/rules/two-layer-architecture.md`. Historical M2-checklist bullets in `milestones.md` left as-is (they describe the path at that time).

### Fixed

- `skills/init-project/SKILL.md:51` — public skill referenced `.claude/rules/docs-english-only.md` (internal). Rewritten as plain prose — the referenced rule stays toolkit-internal.
- `.claude/docs/milestones.md:437` — ref to `how-to-create-docs.md` without path prefix now resolves to `../../docs/how-to-create-docs.md`.
- `docs/research-claude-md-rules.md:18` — "Known issue" note about subdirectory on-demand loading clarified: referenced GitHub issues (#2571, #24987) were auto-closed by github-actions-bot for inactivity, not confirmed fixed.

### Deprecated

- `/update-docs --refresh frontend[:area]` — now prints a deprecation notice and delegates to `/update-frontend-docs <area>` via skill chain. Will be removed in 1.0.

### Migration notes

- **Existing target projects with generated frontend artefacts**: no action required. Running `/update-frontend-docs <area>` after a field-observed drift will refresh only what changed. Full regeneration: `/analyze-frontend` + `/create-frontend-docs`.
- **Toolkit contributors**: `/create-mermaid`, `/research`, `/create-tutorial` still work but only inside the toolkit repo via `.claude/skills/`. They are NOT available on target projects where the plugin is installed — by design.

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
