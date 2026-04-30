# Component Creator Plugin — Milestones

> Parent milestone: [M10 in main milestones.md](../../.claude/docs/milestones.md#m10--component-creator-plugin)
> Build plan source: [component-flows-extracted.md](../../.claude/state/component-flows-extracted.md)
> Plugin target: `plugins/component-creator/`
> Current version: `0.0.0` (pre-release)

---

## Rules

- **Checkpoints are NOT auto-closed.** Claude proposes "Ready for checkpoint N — confirm to advance?" and waits. User must explicitly confirm.
- **Version bumps happen at each checkpoint** — update `plugin.json` version field as part of closing the phase.
- **Each phase ends with a test run** on a real project before advancing.
- **If a test reveals issues** — fix within the current phase, do not advance version until tests pass.

---

## Phase 1 — Foundations `v0.0.1`

> Goal: docs-creator produces machine-readable outputs that component-creator can consume. Registry schema finalized.

### docs-creator gaps (blockers)

- [x] **Gap A** — `token_file:` + `typography_file:` добавлены в JSON (`design_system.token_file/typography_file`) и в frontmatter-шаблон `frontend-design-system.md` в `create-frontend-docs` + `update-frontend-docs design-system` (shipped docs-creator v0.15.x). Требует запуска `/update-frontend-docs design-system` в целевом проекте.
- [x] **Gap G** — `naming_conventions:` добавлен в JSON-схему `analyze-frontend` и в frontmatter-шаблон `reference-component-inventory.md` в `create-frontend-docs` + `update-frontend-docs components` (shipped docs-creator v0.15.x). Требует запуска `/update-frontend-docs components` в целевом проекте.
- [x] **Gap H** — `styling_system:` блок добавлен в JSON-схему `analyze-frontend`; поля `type`, `entry_file`, `import_syntax` присутствуют в `frontend-analysis.json` (верифицировано на pc_cleaner 2026-04-30)
- [x] **Gap C** — `component-registry.json` создаётся в `.claude/state/`; `reference-component-registry.md` генерируется; schema включает `name`, `type`, `layer`, `path`, `figma_node_id`, `figma_file_key`, `figma_connected`, `uses`, `parent`, `created_at`, `last_verified_at`, `last_figma_sync_at`, `figma_last_modified`, `ssim_score`, `status` (верифицировано на pc_cleaner 2026-04-30)

### Registry schema

- [x] Finalize schema fields: `name`, `type` (`primitive` | `feature` | `local`), `layer`, `path`, `figma_node_id`, `figma_file_key`, `figma_connected`, `uses`, `parent` (for `type: local`), `created_at`, `last_verified_at`, `last_figma_sync_at`, `figma_last_modified`, `ssim_score`, `status`

### Plugin scaffold

- [x] Create `plugins/component-creator/.claude-plugin/plugin.json` — name: `component-creator`, version: `0.0.1`, repository field
- [ ] Create `plugins/component-creator/.claude-plugin/marketplace.json`

---

### CHECKPOINT 1 — confirm before advancing to Phase 2

```
Test: run /analyze-frontend + /create-frontend-docs on sciterjsMacOS
Verify:
  [ ] reference-design-system.md has token_file: frontmatter
  [ ] reference-component-inventory.md has naming_conventions: block
  [ ] frontend-analysis.json has styling_system: block
  [ ] component-registry.json created with correct schema
  [ ] plugin.json valid JSON with required fields
```

> Claude will NOT close this checkpoint. After running tests, Claude reports results and asks: "Checkpoint 1 passed — advance to Phase 2?"

**Version bump → `0.0.1` on user confirmation.**

---

## Phase 2 — Generic Core `v0.0.2`

> Goal: framework-agnostic `create-component` orchestrator is buildable and runnable. All EC/edge-case handling and Tool Failure Pattern in rules.

### Artefacts

- [ ] `plugins/component-creator/sequences/create-component.mmd` — full generic flow: Step 0 pre-flight, Phase 1–5, primitive check, Code Connect discovery, Tool Failure Pattern; framework-agnostic participants
- [ ] `plugins/component-creator/rules/component-creation-workflow.md` — preconditions, phases, postconditions, primitive-check pattern, Tool Failure Pattern (exit codes, structured report, critical vs non-critical tools), EC handling rules
- [ ] `plugins/component-creator/rules/component-output-format.md` — naming conventions (read from gap G output), file layout, registry entry format, checklist shape
- [ ] `plugins/component-creator/skills/create-component/SKILL.md` — generic orchestrator: Step 0 pre-flight, registry check (reuse decision), token sync, decompose, layer classification, Code Connect discovery, file generation, registry write, style wiring; delegates tech-specific steps to adapter

---

### CHECKPOINT 2 — confirm before advancing to Phase 3

```
Test: dry-run /component-creator:create-component <simple-component> on sciterjsMacOS
Verify:
  [ ] Pre-flight check fires and catches missing Figma token (test with bad token)
  [ ] Registry check correctly finds EXACT MATCH → stops with "Reusing existing"
  [ ] EC2 (files on disk, not in registry) shows correct user-choice prompt
  [ ] EC3b (token naming inconsistency) shows unmapped-token option
  [ ] EC4 (no icons) shows friendly note, continues
  [ ] EC5 (Figma 401) pre-flight catches it before any work starts
  [ ] EC6 (special chars in name) reads naming_conventions, asks confirmation
  [ ] EC7 (style wiring) reads styling_system from frontend-analysis.json
  [ ] EC9 (unverified registry entry) asks for Figma URL
  [ ] EC10 (malformed registry) shows correct diagnostic with jq tip
  [ ] EC11 (no Figma tokens) shows user-choice prompt
  [ ] EC12 (missing child in registry) creates local component, not blocking
  [ ] sequence diagram matches actual skill execution order
```

> Claude will NOT close this checkpoint. Reports results and asks: "Checkpoint 2 passed — advance to Phase 3?"

**Version bump → `0.0.2` on user confirmation.**

---

## Phase 3 — Sciter Adapter `v0.0.3`

> Goal: Sciter.js-specific adapter runnable end-to-end. `create-primitive` establishes Code Connect pattern for the project.

### Artefacts

- [ ] `plugins/component-creator/skills/create-primitive/SKILL.md` — standalone onboarding skill: creates minimal component + establishes project's Code Connect format (`.figma.ts` or equivalent); result read by `create-component` for Code Connect discovery; runs inline if no primitive found (EC13)
- [ ] `plugins/component-creator/skills/sciter-create-component/SKILL.md` — Sciter adapter: dip units, `flow:` layout, `@mixin typography`, `preview-component.sh`, SSIM 0.95 gate (3 retries → EC14 three-level escalation), ScreenshotHistory (`_code_<name>.png` + `_figma_<name>.png`), agent memory path `.claude/agent-memory/sciter-create-component/`
- [ ] `plugins/component-creator/sequences/sciter-create-component.mmd` — Sciter-specific sequence extending generic; shows preview + SSIM loop + agent memory save

### Agent memory

- [ ] Document agent memory path convention: `.claude/agent-memory/<adapter-name>/feedback_<topic>.md`
- [ ] Seed initial memory file for known SSIM issue: typography @mixin (already documented in sciterjsMacOS)

---

### CHECKPOINT 3 — confirm before advancing to Phase 4

```
Test: run /component-creator:create-primitive on sciterjsMacOS with a simple Button
Verify:
  [ ] create-primitive creates files in correct layer
  [ ] Code Connect pattern file created (.figma.ts or equivalent)
  [ ] Registry entry created with figma_node_id + figma_connected: true
  [ ] SSIM check fires and produces score
  [ ] ScreenshotHistory stores _code_ and _figma_ PNGs
  [ ] EC13 (no primitive) triggers create-primitive inline correctly
  [ ] EC14 three-level escalation fires after 3 SSIM failures (test with deliberately wrong component)
```

> Claude will NOT close this checkpoint. Reports results and asks: "Checkpoint 3 passed — advance to Phase 4?"

**Version bump → `0.0.3` on user confirmation.**

---

## Phase 4 — Registry Management `v0.0.4`

> Goal: registry lifecycle skills operational. `validate-registry` detects local component promotion candidates.

### Artefacts

- [ ] `plugins/component-creator/skills/sync-registry/SKILL.md` — call `get_code_connect_map` for all `type: primitive` entries; update `figma_connected` status; flag stale `figma_node_id`s; update `last_figma_sync_at`
- [ ] `plugins/component-creator/skills/validate-registry/SKILL.md` — check all `path` entries exist on disk; report missing/moved; check `uses` deps resolvable; detect `type: local` entries in `uses` of 2+ components (→ promotion candidate); detect name collisions across layers (EC15)
- [ ] `plugins/component-creator/skills/update-registry/SKILL.md` — update one entry after manual rename/move without re-running full analysis; updates `path`, `name`, all `uses` references across registry

---

### CHECKPOINT 4 — confirm before advancing to Phase 5

```
Test: run registry management skills on sciterjsMacOS
Verify:
  [ ] sync-registry updates figma_connected for all primitives
  [ ] validate-registry finds at least one issue (introduce a deliberate one)
  [ ] validate-registry flags local components used in 2+ places
  [ ] update-registry correctly renames an entry + updates all uses references
  [ ] EC15 (name collision) detected by validate-registry
```

> Claude will NOT close this checkpoint. Reports results and asks: "Checkpoint 4 passed — advance to Phase 5?"

**Version bump → `0.0.4` on user confirmation.**

---

## Phase 5 — Field Test `v0.1.0`

> Goal: create 2–3 real components on sciterjsMacOS end-to-end. Plugin is usable.

### Test runs

- [ ] **Component 1** — simple primitive (e.g. `Badge`): full flow, SSIM passes, registry entry correct
- [ ] **Component 2** — feature component with primitives (e.g. `UserCard` using `Avatar` + `Badge`): composition detection, `uses` field populated, Code Connect suggestions used
- [ ] **Component 3** — component with variants (hover/active/disabled): EC16 pattern applied, one file with CSS states

### Validation

- [ ] All 3 components pass code review without style corrections
- [ ] Registry entries complete: `figma_node_id`, `figma_connected: true`, `ssim_score >= 0.95`
- [ ] `validate-registry` runs clean on all 3 new components
- [ ] No edge cases encountered that are not already handled in EC1–EC16

---

### CHECKPOINT 5 — confirm before advancing to Phase 6

```
User confirms:
  [ ] Components match project conventions (naming, file structure, token usage)
  [ ] SSIM scores acceptable
  [ ] No unhandled edge cases found
  [ ] Registry is clean after validate-registry
```

> Claude will NOT close this checkpoint. After field test, Claude reports findings and asks: "Checkpoint 5 passed — advance to Phase 6?"

**Version bump → `0.1.0` on user confirmation.**

---

## Phase 6 — Remaining Gaps + Extra Skills `v0.1.1`

> Goal: remaining docs-creator gaps filled, extra skills built, extraction toolkit deleted.

### docs-creator remaining gaps

- [ ] **Gap B** — add `## Component Placement Rules` to `reference-component-creation-template.md` from `architecture.organizing_principle`
- [ ] **Gap D** — add `uses:` dependency graph field to `component-registry.json` schema; `component-inventory` detects composition from imports
- [ ] **Gap F** — i18n detection in `framework-idiom-extractor`; `create-frontend-docs` writes `reference-i18n.md` if detected; new docs-creator skill `/create-i18n-docs`

### Extra skills

- [ ] `plugins/component-creator/skills/update-component/SKILL.md` — 5-phase: diff analysis → change report → user confirmation → apply patches → update registry; never overwrites hand-tweaked code without confirmation
- [ ] `plugins/component-creator/skills/create-page/SKILL.md` — full-page scaffold: analyze Figma page → map to existing components → build missing local components → place all in page directory; separate sequence diagram

### Cleanup

- [ ] Delete `.claude/skills/extract-component-flows/`
- [ ] Delete `.claude/agents/component-flow-extractor.md`
- [ ] Remove `extract-component-flows` from `/menu` SKILL.md commands table
- [ ] Remove `extract-component-flows` + `component-flow-extractor` from `skill-scopes.md`

---

### CHECKPOINT 6 — final release

```
Verify:
  [ ] /validate-claude-docs on component-creator plugin passes
  [ ] /check-links on plugins/component-creator/ passes
  [ ] Extraction toolkit deleted — no broken references
  [ ] All M10 checklist items in milestones.md ticked
  [ ] CHANGELOG entry written for v0.1.1
```

> Claude will NOT close this checkpoint. Reports results and asks: "Checkpoint 6 passed — mark M10 complete?"

**Version bump → `0.1.1` on user confirmation. M10 closed in milestones.md.**

---

## Progress Tracker

| Phase | Status | Version | Started | Completed |
| ---- | ---- | ---- | ---- | ---- |
| Phase 1 — Foundations | not started | — | — | — |
| Phase 2 — Generic Core | not started | — | — | — |
| Phase 3 — Sciter Adapter | not started | — | — | — |
| Phase 4 — Registry Management | not started | — | — | — |
| Phase 5 — Field Test | not started | — | — | — |
| Phase 6 — Remaining Gaps + Extra Skills | not started | — | — | — |

## Total Estimated Effort

| Phase | Estimated |
| ---- | ---- |
| Phase 1 — Foundations (docs-creator gaps) | ~4–6h |
| Phase 2 — Generic Core | ~3–4h |
| Phase 3 — Sciter Adapter | ~3–5h |
| Phase 4 — Registry Management | ~2–3h |
| Phase 5 — Field Test | ~2–3h |
| Phase 6 — Remaining Gaps + Extra Skills | ~4–6h |
| **Total** | **~18–27h** |
