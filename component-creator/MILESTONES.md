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
- [x] Create `plugins/component-creator/.claude-plugin/marketplace.json`

---

### CHECKPOINT 1 — ✅ PASSED 2026-04-30

```
Test: run /analyze-frontend + /update-frontend-docs on pc_cleaner (2026-04-30)
Verify:
  [x] reference-design-system.md has token_file: frontmatter
  [x] reference-component-inventory.md has naming_conventions: block (pending final run)
  [x] frontend-analysis.json has styling_system: block
  [x] component-registry.json created with correct schema
  [x] plugin.json valid JSON with required fields
```

**Version bumped → `0.0.1`**

---

## Phase 2 — Generic Core `v0.0.2`

> Goal: framework-agnostic `create-component` orchestrator is buildable and runnable. All EC/edge-case handling and Tool Failure Pattern in rules.
>
> **Source of truth for all flows:** [component-flows-extracted.md](../../.claude/state/component-flows-extracted.md)
>
> **Layer boundary — what belongs HERE vs Phase 3:**
>
> | Belongs in generic `create-component` | Belongs in `sciter-create-component` (Phase 3) |
> | ---- | ---- |
> | TodoWrite initialization | `dip` units, `flow:` layout, `@mixin typography` |
> | Phase 1 parallel agents (Figma context + Reuse + Token sync) | `preview-component.sh` invocation |
> | `get_design_context` (both passes) + `get_variable_defs` | SSIM 0.95 gate + 3 retries + EC14 escalation |
> | Phase 1.5 Decompose bottom-up (conditional) | `ScreenshotHistory` (`_code_` + `_figma_` PNGs) |
> | Phase 2 parallel streams: icon download + code generation | Agent memory save (`.claude/agent-memory/`) |
> | Visual verify — **`opt A: adapter.visual_verify()`** (delegated, no details) | Typography mixin mapping |
> | Phase 4 Registry upsert | `__DIR__ + "img/..."` icon path pattern |
> | Phase 5 Code Connect: primitive scan → EC13 → pattern extract → generate → publish | `.figma.ts` / `.figma.js` format discovery |
>
> **When writing `create-component.mmd`: if a step involves Sciter-specific tooling → replace with a single `A->>S: adapter.<phase>()` call and note "adapter-specific".**

### Artefacts

- [x] `plugins/component-creator/sequences/create-component.mmd` — **must contain** (per source of truth):
  - Step 0: pre-flight (TodoWrite init, read template + registry + analysis, Figma `whoami` → EC5)
  - Phase 1: **3 parallel agents** — Figma context (`get_design_context` ×2 incl. `disableCodeConnect:true`) + Reuse check (EXACT/PARTIAL/NO match, EC2) + Token sync (`get_variable_defs`, EC3b, EC11)
  - Phase 1.5: Decompose bottom-up (conditional, only if composite)
  - Phase 2: **2 parallel streams** — Stream A: icon asset download + Stream B: code generation (tokens, files, preview, CSS import, checklist)
  - Phase 3: `opt A: adapter.visual_verify()` — single delegated call, no SSIM details
  - Phase 4: Registry upsert
  - Phase 5: Code Connect — primitive scan → EC13 → extract pattern → generate → publish
  - Tool Failure Pattern block (critical stop vs non-critical continue)
  - **NOT IN THIS DIAGRAM:** SSIM numbers, preview-component.sh, dip/flow/mixin, ScreenshotHistory
- [x] `plugins/component-creator/rules/component-creation-workflow.md` — preconditions, phases, postconditions, primitive-check pattern, Tool Failure Pattern (exit codes, structured report, critical vs non-critical tools), EC handling rules
- [x] `plugins/component-creator/rules/component-output-format.md` — naming conventions (read from gap G output), file layout, registry entry format, checklist shape
- [x] `plugins/component-creator/skills/create-component/SKILL.md` — generic orchestrator: Step 0 pre-flight, registry check (reuse decision), token sync, decompose, layer classification, Code Connect discovery, file generation, registry write, style wiring; delegates tech-specific steps to adapter

---

### CHECKPOINT 2 — confirm before advancing to Phase 3

```
Test: dry-run /component-creator:create-component on sciterjsMacOS (2026-05-04)
Verify:
  [x] Registry check correctly finds EXACT MATCH → stops with "Reusing existing"
  [x] EC2 (files on disk, not in registry) shows correct user-choice prompt
  [x] EC6 (special chars in name) reads naming_conventions, asks confirmation
  [x] EC7 (style wiring) reads styling_system from frontend-analysis.json
  [x] EC10 (malformed registry) shows correct diagnostic with jq tip
  [x] sequence diagram matches actual skill execution order
  [x] PARTIAL MATCH (same Figma node, diff name) → extend/refactor/new/cancel
  [x] Happy path end-to-end: ButtonFeedback created, tokens added, Code Connect published
  [~] EC5 (Figma 401) — verified by code review (whoami in pre-flight, simple 401→stop)
  [~] EC9 (unverified registry entry) — verified by code review (null check before Phase 5)
  [~] EC3b, EC4, EC11, EC12 — verified by code review (in component-creation-workflow.md)
```

> ✅ PASSED 2026-05-04

**Version bump → `0.0.2`**

---

## Phase 3 — Sciter Adapter `v0.0.3`

> Goal: Sciter.js-specific adapter runnable end-to-end. `create-primitive` establishes Code Connect pattern for the project.
>
> **This phase extends Phase 2 — do NOT duplicate generic phases.** `sciter-create-component.mmd` shows only the delta: what replaces or expands `adapter.visual_verify()` and any Sciter-specific pre/post steps.
>
> **Scripts strategy (Phase 3):** visual verification scripts live in the target project's `tools/` directory (already battle-tested in sciterjsMacOS). The adapter calls them via relative paths. Cross-platform extraction into a standalone `sciter-devtools` tool is tracked in Phase 7.
>
> **What the Sciter adapter adds on top of generic:**
> - CSS generation rules: `dip` units, `flow:` layout, `@mixin typography` (no `font` shorthand with `var()`)
> - Preview: `tools/preview-component.sh` invocation + leave window open (macOS, sciterjsMacOS scripts)
> - Visual verify: SSIM 0.95 gate, max 3 retries → EC14 three-level escalation
> - ScreenshotHistory: save `_code_<name>.png` + `_figma_<name>.png` at creation
> - Agent memory: read feedback files from `.claude/agent-memory/sciter-create-component/` before generating, write after user confirms fix
> - Icon paths: `__DIR__ + "img/..."` (not `"./img/"`)
> - Code Connect format: discovered from primitive (`.figma.ts` or `.figma.js`)

### Artefacts

- [x] `plugins/component-creator/skills/sciter-create-component/SKILL.md` — Sciter adapter: `adapter.visual_verify()` → preview-component.sh + SSIM 0.95 (3 retries → EC14 escalation) + ScreenshotHistory; CSS rules (dip, flow, mixin); agent memory seed/read; variant node check in Step 0; EC13 inline onboarding with Sciter rules
- [x] EC13 redesigned — no separate `/create-primitive` skill; both `create-component` and `sciter-create-component` handle first-time onboarding inline: prompt user to pick a simple primitive (no children), create it with CC format setup, then continue with the original component
- [x] `plugins/component-creator/sequences/sciter-create-component.mmd` — **extends generic diagram**: shows only Sciter delta — expansion of `adapter.visual_verify()` into preview + SSIM loop + EC14 + agent memory save; reference generic diagram with `note over` link

### Agent memory

- [x] Document agent memory path convention: `.claude/agent-memory/<adapter-name>/feedback_<topic>.md`
- [x] Seed initial memory file for known SSIM issue: typography @mixin — seeded inline in `sciter-create-component/SKILL.md` Step 0 + template in `docs/agent-memory-seed-sciter.md`

---

### CHECKPOINT 3 — confirm before advancing to Phase 4

#### Test 1 — create-primitive (happy path)
```
Setup:    fresh sciterjsMacOS session, no existing primitive for target component
Command:  /component-creator:create-primitive <figma-url-of-simple-widget>
Verify:
  [ ] create-primitive creates files in correct FSD layer (widgets/ or shared/ui/)
  [ ] .figma.ts file created with // url= and // component= headers
  [ ] Registry entry created: figma_node_id set + figma_connected: true
```

#### Test 2 — sciter-create-component visual verify
```
Setup:    primitive exists, Figma URL for a new widget
Command:  /component-creator:sciter-create-component <figma-url>
Verify:
  [ ] preview-component.sh invoked after file generation
  [ ] SSIM score computed and shown (any score, not required ≥0.95 for first run)
  [ ] ScreenshotHistory: _code_<name>.png + _figma_<name>.png saved
```

#### Test 3 — EC13 (no primitive exists)
```
Setup:    temporarily rename/remove *.figma.ts files
          ! mv res/widgets/aside-panel/aside-panel.figma.ts /tmp/aside-panel.figma.ts.bak
Command:  /component-creator:sciter-create-component <figma-url>
Verify:
  [ ] EC13 fires: "No primitive found — run /create-primitive first"
          OR auto-invokes create-primitive inline and continues
Cleanup:  ! mv /tmp/aside-panel.figma.ts.bak res/widgets/aside-panel/aside-panel.figma.ts
```

#### Test 4 — EC14 (SSIM failure escalation)
```
Setup:    use a Figma URL that intentionally produces wrong CSS
          (e.g. wrong colors / completely different layout)
Command:  /component-creator:sciter-create-component <mismatched-figma-url>
Verify:
  [ ] After 3 SSIM retries — EC14 three-level escalation fires:
      Level 1: show diff + ask user to fix CSS
      Level 2: show agent-memory suggestions
      Level 3: stop + structured report
Note:     EC14 is hard to trigger deterministically — acceptable to verify
          by code review if SSIM consistently passes on real components
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

## Phase 7 — sciter-devtools (standalone cross-platform tool)

> Goal: extract the visual verification scripts from target-project `tools/` into a standalone cross-platform CLI tool — the Sciter equivalent of Storybook's visual testing layer. Replaces the macOS-only bash scripts with a portable solution any Sciter project can install.

**Why after Phase 6:** the flow is proven end-to-end (Phases 3–5) before we invest in cross-platform infrastructure. Build the right abstraction once we know the exact interface `sciter-create-component` needs.

### Step 1 — Research current flow (before building)

- [ ] Document exact interface: inputs/outputs of each script (`preview-component.sh`, `find-component.py`, `fetch-figma-screenshot.sh`, `capture-sciter.sh`)
- [ ] Identify macOS-specific dependencies (AppleScript window capture, macOS screenshot API, Sciter runtime path)
- [ ] Survey cross-platform options for each dependency (Linux/Windows alternatives)
- [ ] Decision: Node.js CLI, Python package, or Go binary — based on Sciter runtime availability per platform

### Step 2 — Design `sciter-devtools` CLI

```text
sciter-devtools preview <preview.js> --width <N>
sciter-devtools compare <preview.js> --figma-node <nodeId> --figma-file <fileKey> --width <N>
sciter-devtools capture              # capture running Sciter window
sciter-devtools history list         # list ScreenshotHistory entries
```

- [ ] CLI spec written as `docs/sciter-devtools-spec.md`
- [ ] `sciter-create-component` SKILL.md updated to call `sciter-devtools compare` instead of `tools/preview-component.sh` (adapter contract stays the same, implementation changes)

### Step 3 — Implementation

- [ ] Cross-platform window capture (replaces `capture-sciter.sh` + AppleScript)
- [ ] SSIM comparator port (replaces `find-component.py` — keep Python or rewrite)
- [ ] Figma screenshot fetch (replaces `fetch-figma-screenshot.sh`)
- [ ] Preview launcher (replaces `preview-component.sh` — integrates all above)
- [ ] `npm install -g sciter-devtools` or equivalent
- [ ] Windows + Linux smoke test

### Step 4 — Plugin integration

- [ ] `sciter-create-component` SKILL.md: pre-flight checks for `sciter-devtools` binary instead of local scripts
- [ ] `create-primitive` SKILL.md: same
- [ ] Docs: `docs/sciter-devtools-setup.md` — install + configure per OS

---

## Progress Tracker

| Phase | Status | Version | Started | Completed |
| ---- | ---- | ---- | ---- | ---- |
| Phase 1 — Foundations | done | 0.0.1 | 2026-04-28 | 2026-04-30 |
| Phase 2 — Generic Core | done | 0.0.2 | 2026-04-30 | 2026-05-04 |
| Phase 3 — Sciter Adapter | in progress | — | 2026-05-05 | — |
| Phase 4 — Registry Management | not started | — | — | — |
| Phase 5 — Field Test | not started | — | — | — |
| Phase 6 — Remaining Gaps + Extra Skills | not started | — | — | — |
| Phase 7 — sciter-devtools | not started | — | — | — |

## Total Estimated Effort

| Phase | Estimated |
| ---- | ---- |
| Phase 1 — Foundations (docs-creator gaps) | ~4–6h |
| Phase 2 — Generic Core | ~3–4h |
| Phase 3 — Sciter Adapter | ~3–5h |
| Phase 4 — Registry Management | ~2–3h |
| Phase 5 — Field Test | ~2–3h |
| Phase 6 — Remaining Gaps + Extra Skills | ~4–6h |
| Phase 7 — sciter-devtools | ~8–12h |
| **Total** | **~26–39h** |
