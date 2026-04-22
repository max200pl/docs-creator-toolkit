---
name: analyze-frontend
scope: api
description: "Analyze a project's frontend — detect frameworks, design system, components, data flow, architecture; generate scoped rules and docs into .claude/. Run after /init-project or standalone on any project with an existing .claude/."
user-invocable: true
argument-hint: "[frontend-path] [--only <area>]"
---

# Analyze Frontend

> **Flow:** read all files in `sequences/analyze-frontend/` — the sequence diagram is the source of truth for execution order
> Primary-output format: `rules/component-creation-template-format.md` — spec for `component-creation-template.md`
> Subagent specs: `agents/frontend-detector.md`, `agents/tech-stack-profiler.md`, `agents/design-system-scanner.md`, `agents/component-inventory.md`, `agents/data-flow-mapper.md`, `agents/architecture-analyzer.md`, `agents/framework-idiom-extractor.md`
> Fan-out pattern: `.claude/docs/subagent-fanout-pattern.md` — decision heuristic, return-shape contract
> Reference: read `docs/how-to-create-docs.md`
> Style rules: read `rules/markdown-style.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

Orchestrator. Detects frontend root(s) in the project and produces a **compact context envelope for a downstream component-creation agent**. The primary output is `component-creation-template.md` — a prescriptive, framework-idiomatic recipe for creating new components in THIS specific project. Everything else (design-system rule, component inventory, data-flow diagram, architecture doc) is **supporting reference data** cross-linked from the primary template.

Execution pattern: **two-wave fan-out** with stack-informed Wave 2.

- **Wave 1 — Stack profile**: `tech-stack-profiler` runs alone (serial gate), establishing `framework`, `rendering_mode`, `styling_model`, `class_naming`, `state_libs[]`, etc.
- **Wave 2 — Deep per-axis analysis (parallel)**: 5 specialists + `framework-idiom-extractor` run concurrently, each consuming Wave 1's `stack_profile` so their scans are narrower and more accurate (e.g., `design-system-scanner` skips `styled-components` lookups when stack says Tailwind).
- **Assembly**: orchestrator assembles `component-creation-template.md` from Wave 1 + Wave 2 outputs per `rules/component-creation-template-format.md`, then writes the supporting reference files.

Runs in two modes:

- **Auto-suggested** after `/init-project` when a frontend is detected (user accepts "run now?" checkpoint).
- **Standalone** on any project that already has a `.claude/` directory — retrofit or refresh.

If `.claude/` is missing, the skill stops and directs the user to `/init-project`.

## What this skill creates

All artefacts land in the target project's `.claude/` — never in the plugin. Filenames use a root-specific suffix when multiple frontends are detected, plain names otherwise.

**Primary — for the downstream component-creation agent:**

- `.claude/docs/component-creation-template.md` — prescriptive recipe: WHERE new component files go, HOW to import, WHAT styling model to use, WHETHER custom class names even exist in this project, HOW state/data wiring works, a framework-idiomatic skeleton. Per `rules/component-creation-template-format.md`. **This is the file a component-creation agent reads first.**

**Supporting references — cross-linked FROM the template:**

- `.claude/rules/frontend-design-system.md` — design tokens, CSS variables, theme configuration, with `paths:` scoped to theme/token files
- `.claude/rules/frontend-components.md` — component conventions (naming, prop shapes, class structure), with `paths:` scoped to components folders
- `.claude/docs/architecture-frontend.md` — architecture overview + rendering mode + folder-boundary map
- `.claude/docs/component-inventory.md` — table of notable components with purpose and location
- `.claude/sequences/frontend-data-flow.mmd` — state + API data-flow diagram

**Operational:**

- `.claude/state/reports/analyze-frontend-<ts>.md` — run report per [rules/report-format.md](../../rules/report-format.md) (gitignored)
- `CLAUDE.md` — Architecture section updated with `@` imports to all of the above (surgical edit; other sections untouched)

## What this skill does NOT create

- New modules under `projects/` or `src/` — it only describes what exists
- Tests or CI configuration
- Project-specific skills or custom rules beyond the ones listed above
- Any artefact outside the target project's `.claude/` or root `CLAUDE.md`

## Usage

```text
/analyze-frontend                            # auto-detect frontend roots in cwd
/analyze-frontend apps/web                   # analyze a specific sub-directory
/analyze-frontend --only design-system       # skip components/data-flow/architecture
/analyze-frontend apps/web --only components # combined
```

Filters accepted after `--only`:

| Filter | Runs | Writes |
| ---- | ---- | ---- |
| `design-system` | design-system-scanner | `frontend-design-system.md` |
| `components` | component-inventory | `frontend-components.md` + `component-inventory.md` |
| `data-flow` | data-flow-mapper | `frontend-data-flow.mmd` |
| `architecture` | tech-stack-profiler + architecture-analyzer | `architecture-frontend.md` |
| `all` (default) | all 5 specialists | everything |

## Interactive Wizard

The skill runs as a guided wizard with user checkpoints — not a silent batch.

| After phase | What to show | What to ask |
| ---- | ---- | ---- |
| Detect frontends | List of detected roots with framework + entry point | Correct? Add/remove any? Specific area to focus on? |
| Deep analysis complete | Per-frontend summary table (stack, token count, component count, data-flow style) | Write all artefacts? Any to skip? |
| Report | Dashboard + `@` imports added to CLAUDE.md | Anything to regenerate? |

## Composition

This skill is a **two-wave fan-out pipeline** — one detection subagent (gating) + one stack-profile subagent (Wave 1) + six specialist subagents (Wave 2) + orchestrator-side assembly of the primary template.

| Phase | Owner | Responsibility |
| ---- | ---- | ---- |
| Preflight | **this skill** | Confirm `.claude/` exists; capture `START_TS` |
| Detect frontends | `frontend-detector` subagent | Enumerate frontend roots; return list with framework + entry points |
| Confirm scope | **this skill** | User checkpoint — accept/modify root list |
| **Wave 1 — Stack profile** | `tech-stack-profiler` subagent (per frontend) | Return full `stack_profile`: framework, rendering mode, `styling_model`, `class_naming`, state libs, bundler, etc. Wave 2 depends on this. |
| **Wave 2 — Deep analysis (parallel)** | 6 specialists (per frontend, concurrent): `framework-idiom-extractor`, `design-system-scanner`, `component-inventory`, `data-flow-mapper`, `architecture-analyzer` | Each consumes Wave 1's `stack_profile` for narrower scans. Returns `{summary_row, artefact_body}` or `SKIP` |
| **Assemble primary template** | **this skill** | Build `.claude/docs/component-creation-template.md` per `rules/component-creation-template-format.md` from Wave 1 + Wave 2 outputs |
| Write supporting references | **this skill** | Write the 4 reference files, update root `CLAUDE.md` Architecture section surgically |
| Report | **this skill** | Persist run report per `rules/report-format.md` |

**Naming rule:** when N frontends > 1, artefact filenames gain a root-derived suffix (`component-creation-template-web-app.md`, `frontend-design-system-web-app.md`). When N == 1, filenames stay plain.

**Why two waves, not one parallel fan-out:** Wave 2 specialists benefit significantly from knowing the stack. `design-system-scanner` skips `styled-components` lookup when Wave 1 says Tailwind. `component-inventory` globs `.vue` files vs `.tsx` based on framework. `framework-idiom-extractor` selects framework-specific deep-dive branch from `framework_classification`. Running everything in one parallel wave wastes Wave-2 scans on wrong file patterns.

## Reference

The sequence diagram defines order. Sections below describe only the phases with non-trivial logic.

### Phase: Preflight

Capture the start timestamp at the very first step:

```bash
Bash: START_TS=$(date +%s); RUN_TS=$(date -u +%Y%m%dT%H%M%SZ); DISPLAY_TS=$(date +%Y%m%d-%H%M%S); echo "START_TS=$START_TS RUN_TS=$RUN_TS DISPLAY_TS=$DISPLAY_TS"
```

Preserve these values through the run. Per-phase timestamps are optional but preferred (feed the Phase Timings table in the report).

Check `.claude/` directory exists in cwd. If absent, stop and point to `/init-project`. Do NOT scaffold it here — that is `/init-project`'s job.

### Phase: Detect frontends (delegated)

Invoke the `frontend-detector` subagent (see [agents/frontend-detector.md](../../agents/frontend-detector.md) for the full contract) with:

| Field | Value |
| ---- | ---- |
| `project_root` | Absolute cwd |
| `user_hint_path` | The `[frontend-path]` argument if given, else empty |

It returns a flat list: `[{path, framework, entry_points, confidence}]`. Zero results → stop with a "No frontend roots found" message.

### Phase: Confirm scope (interactive)

Show the list to the user. Accept: confirm as-is / remove specific entries / add a missed path. Also capture any `--only <area>` filter.

### Phase: Wave 1 — Stack profile (per frontend)

For each confirmed frontend root, invoke `tech-stack-profiler` SERIALLY before Wave 2 starts. If there are multiple frontends, they can run in parallel with each other (but each independently before its own Wave 2).

Invocation prompt includes:

| Field | Value |
| ---- | ---- |
| `frontend_root` | Absolute path to the frontend directory |
| `project_root` | Absolute cwd |
| `framework_hint` | Framework name from `frontend-detector` output |
| `entry_points` | List of entry-point file paths from `frontend-detector` |
| `style_rules_path` | Relative path to `rules/markdown-style.md` in the loaded plugin |

Wait for the return before starting Wave 2. Preserve the full `stack_profile` return:

- `framework`, `framework_version`, `rendering_mode`
- `language`, `ts_strictness`
- `bundler`, `package_manager`
- **`styling_model`** and **`class_naming`** — these are critical for the primary template's Styling/Classes sections (see `agents/tech-stack-profiler.md` for the enum values)
- `state_management[]`, `routing`, `data_fetching[]`, `ui_library[]`, `testing[]`, `linting[]`

### Phase: Wave 2 — Deep analysis (parallel, stack-informed)

Once Wave 1 has returned for ALL confirmed frontend roots, fire Wave 2: **6 specialists × N frontends invocations in a single message** (concurrent).

Specialists in Wave 2:

1. `framework-idiom-extractor` — pattern-first framework classification (industry / custom / vanilla); idiomatic rules for new components
2. `design-system-scanner` — tokens, theme config, dark-mode strategy
3. `component-inventory` — existing components tree + conventions + canonical skeleton pick
4. `data-flow-mapper` — state + API + auth + forms; emits Mermaid data-flow diagram
5. `architecture-analyzer` — folder layout, routing, SSR boundaries

If `--only <area>` was specified, invoke only the matching specialists.

Each Wave 2 invocation prompt MUST include:

| Field | Value |
| ---- | ---- |
| `frontend_root` | Absolute path to the frontend directory |
| `project_root` | Absolute cwd |
| `stack_profile` | **The full Wave 1 return** — specialists consume this to narrow scans |
| `entry_points` | Entry-point file paths |
| `style_rules_path` | Relative path to `rules/markdown-style.md` in the loaded plugin |
| `target_file_shape` | Brief reminder of the expected return format |

**Fan-in contract** — every specialist returns two sections:

1. `## Summary Row` — a YAML block specific to that specialist (see each subagent spec for fields).
2. `## <Artefact>` — the full markdown content for the artefact this specialist writes or contributes (or the sentinel literal `SKIP` if nothing applies — e.g., a static Astro site has no data-flow; `framework-idiom-extractor` returns SKIP for `vanilla`).

Orchestrator parses by heading. Failures are logged to the run report's `Notes`, not escalated to abort.

### Phase: Assemble primary template

After Wave 2 returns for all frontends, the orchestrator assembles `.claude/docs/component-creation-template.md` per [rules/component-creation-template-format.md](../../rules/component-creation-template-format.md). Required sections of the template are populated from Wave 1 + Wave 2 outputs as follows:

| Template section | Fed by |
| ---- | ---- |
| File layout | `architecture-analyzer` (folder structure) + `component-inventory` (co-located files) |
| Imports block | `component-inventory` (from the canonical skeleton's imports) + `architecture-analyzer` (path aliases) |
| Props declaration | `component-inventory` (conventions observed in existing components) |
| Styling model | Wave 1 `stack_profile.styling_model` — map to the prescriptive paragraph |
| Class naming | Wave 1 `stack_profile.class_naming` — including the "are classes even used?" answer |
| State and data wiring | `data-flow-mapper` (state + API + forms + auth) |
| Event handling | `component-inventory` (observed patterns) |
| Accessibility patterns | `component-inventory` Notes section if any a11y observations |
| Test and story conventions | `component-inventory` (`test_colocation`, `storybook_present`) |
| Design-token usage | `design-system-scanner` (primary mechanism + 1-2 concrete examples) |
| Framework-specific idioms | `framework-idiom-extractor` verbatim (handles both industry and custom) |
| Canonical skeleton | `component-inventory.component_skeleton_excerpt` (if provided) OR synthesized from its other fields |
| Anti-patterns | Union of all specialists' Notes that flagged anti-patterns |
| Cross-references | Auto-generated: `@`-links to the other 4 reference files written by this skill |

If a subagent returned SKIP for its area, the corresponding section in the template is reduced to a single-line explanation (not omitted entirely — the agent reading the template needs to know "no design-system observed" as explicit info).

### Phase: Write supporting references + update CLAUDE.md

Write the 5 supporting files (one primary + 4 references) to the target project. File naming:

- If `frontend_roots.length == 1` → plain filenames
- If `frontend_roots.length > 1` → suffix with a slug derived from the root's basename

Skip writing any reference whose specialist returned `SKIP`. Every skipped artefact is still noted in the run report.

**Paths-scoping for generated rules** — two rule files get `paths:` frontmatter so they auto-load only when Claude edits matching files:

- `frontend-design-system.md` → `paths: ["<frontend_root>/**/*.{css,scss,sass}", "<frontend_root>/*tailwind*.{js,ts,cjs}", "<frontend_root>/**/*token*", "<frontend_root>/**/theme*.*"]`
- `frontend-components.md` → `paths: ["<frontend_root>/src/components/**", "<frontend_root>/components/**", "<frontend_root>/src/ui/**"]`

The subagents produce the markdown body; the orchestrator prepends the frontmatter block based on detected paths.

### Phase: Update root CLAUDE.md Architecture section

Surgical edit — read CLAUDE.md, locate the `## Architecture` heading, append `@`-style import references for each newly-created file at the end of that section. Do NOT touch other sections (Build & Run, Project Structure, Code Conventions, Git Conventions, etc.).

Example addendum (inserted before next `##` heading):

```markdown
### Frontend

- See [.claude/docs/architecture-frontend.md](.claude/docs/architecture-frontend.md) for the frontend architecture overview.
- Design system tokens: `@.claude/rules/frontend-design-system.md`
- Component conventions: `@.claude/rules/frontend-components.md`
- Data flow diagram: `.claude/sequences/frontend-data-flow.mmd`
```

If the Architecture section already contains a `### Frontend` subsection (from a previous run), replace it in place — do not duplicate.

### Phase: Report

Write the run report to `.claude/state/reports/analyze-frontend-<DISPLAY_TS>.md`.

**REQUIRED — exact first-line format** (not negotiable, do NOT use JSON, do NOT rename keys):

```text
<!-- report: skill=analyze-frontend ts=<ISO-UTC> wall_clock_sec=<int> frontends=<N> artefacts=<int> stack=<aggregated-per-root> -->
```

Hard rules:

- **Prefix is literal `<!-- report: `** — NOT `<!-- meta: `, not `<!-- run: `.
- **Format is `key=value` pairs separated by spaces** — NOT a JSON object.
- **Key names exactly** — `ts` (NOT `run_ts`), `wall_clock_sec`, `frontends` (M8-specific alias of `modules`; use `frontends` here because units being counted are frontend roots, not modules), `artefacts` (NOT `artefact_count`), `stack` (e.g. `next.js+tailwind,vite+react`).
- Single line; no quoted values unless the value contains spaces.

**Per-phase timings are REQUIRED**, captured at each phase boundary:

```bash
Bash: PHASE_<NAME>_START=$(date +%s)
Bash: PHASE_<NAME>_END=$(date +%s); PHASE_<NAME>_SEC=$((PHASE_<NAME>_END - PHASE_<NAME>_START))
```

Phases to time: `PREFLIGHT`, `DETECT`, `CONFIRM`, `DEEP_ANALYSIS` (the parallel fan-out), `WRITE`, `UPDATE_CLAUDE_MD`, `REPORT`. Missing timings go to `## Notes` as `timing_missing=<phase>`, never estimated.

See [rules/report-format.md](../../rules/report-format.md) as source of truth.

Body sections:

- `## Summary` — frontends analyzed, stacks found, duration, artefacts written
- `## Phase Timings` — Preflight, Detect, Confirm, Deep analysis, Write, Report
- `## Per-frontend findings` — per-root table: stack profile, design-system characterization, component count, data-flow style, architecture mode
- `## Artefacts` — path / lines / category
- `## Next-step Recommendations` — optional follow-up skills (`/create-docs rule` for project-specific patterns, `/create-mermaid` for additional flows, `/update-docs --refresh frontend:<area>` once code drifts)
- `## Notes` (optional) — subagent failures, surprises, cleanup candidates

End-of-run dashboard on screen: frontends, stacks, duration, `Report ✓ .claude/state/reports/analyze-frontend-<ts>.md`.

## Retrofit Behavior

When run on a project whose `/init-project` did NOT detect frontends (pre-M8 run, or frontend added later):

- Adds all new artefacts without touching existing module `CLAUDE.md` files
- Updates root `CLAUDE.md` only in the Architecture section
- Does not re-run stack detection at project level — uses `frontend-detector` which is narrower

When run on a project that already has previous-run artefacts (re-run scenario):

- Overwrites `.claude/rules/frontend-*.md` and `.claude/docs/*frontend*.md` with fresh content
- Preserves any hand-edits? No — rewrites from scratch. Users who want to preserve overrides should instead use `/update-docs --refresh frontend:<area>` once it lands.

## What This Skill Does NOT Do

- Scaffold `.claude/` — use `/init-project` first
- Analyze backend code — this is frontend-specific
- Create per-component `CLAUDE.md` files — only the aggregate inventory in `.claude/docs/component-inventory.md`
- Configure linters, formatters, or CI — pure read + describe
- Invent patterns not observed in the code — subagents must surface only what they find, same discipline as `module-documenter`
