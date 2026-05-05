---
description: "Preconditions, phases, postconditions, primitive-check pattern, Tool Failure Pattern, and EC handling rules for the create-component skill."
---

# Component Creation Workflow

> Sequence diagram (source of truth for execution order): `sequences/create-component.mmd`
> Build plan reference: `.claude/state/component-flows-extracted.md`

## Preconditions

All must be true before `/create-component` starts. Pre-flight (Step 0) verifies each.

| # | Precondition | Where it comes from | Failure |
| ---- | ---- | ---- | ---- |
| P1 | `reference-component-creation-template.md` exists | `/create-frontend-docs` output | stop — run `/create-frontend-docs` first |
| P2 | `component-registry.json` exists | `/create-frontend-docs` output | stop — run `/create-frontend-docs` first |
| P3 | `frontend-analysis.json` has `naming_conventions` + `styling_system` | `/analyze-frontend` output | stop — run `/update-frontend-docs components` + `design-system` |
| P4 | `token_file:` present in `frontend-design-system.md` frontmatter | `/update-frontend-docs design-system` | stop — run `/update-frontend-docs design-system` |
| P5 | Figma access token valid (`whoami` succeeds) | env `FIGMA_ACCESS_TOKEN` / `.env` | stop → EC5 |
| P6 | Figma URL or node ID provided | user argument or interactive prompt | prompt user |

**Code generation reference:** always `reference-component-creation-template.md`. Never read an existing component as a pattern for new code — existing components may carry workarounds or outdated conventions. Existing components are accessed only in Phase 5 (Code Connect format discovery from primitive).

## Phases

Execution follows `sequences/create-component.mmd`. Each phase summary below — see diagram for parallel structure.

### Step 0 — Pre-flight

1. `TodoWrite` — initialize all ~15 task items as `pending`. Mark each `in_progress` BEFORE starting, `completed` IMMEDIATELY after finishing. Only one task `in_progress` at a time.
2. Read: `component-creation-template.md`, `component-registry.json`, `frontend-analysis.json`.
3. Extract `naming_conventions` + `styling_system` from analysis JSON.
4. Call Figma `whoami` — abort on 401 (EC5).

### Phase 1 — Context gathering (3 parallel agents)

Run all three in parallel. Wait for all before proceeding.

- **Agent 1 — Figma design:** `get_design_context(nodeId, fileKey)` → layout/colors/typography reference. Then `get_design_context(nodeId, fileKey, disableCodeConnect: true)` → full child structure + variant states + icon node list.
- **Agent 2 — Reuse check:** load registry, apply Reuse Decision Tree (see below). Result: EXACT / PARTIAL / NO match.
- **Agent 3 — Token + typography sync:**
  1. **Color/spacing tokens** — read `token_file` + `get_variable_defs(nodeId, fileKey)`. Compare by hex-normalized value. Result: matched tokens list + missing tokens list.
  2. **Typography mixins** — read `typography_file` (from `frontend-design-system.md` frontmatter). For each text element in the design context (from Agent 1), extract: `font-size`, `font-weight`, `line-height`. Match against existing `@mixin` definitions by those three values. Result:
     - Match found → record mixin name to use in CSS generation
     - No match → surface as typography gap: prompt user "No matching mixin for `{size}/{weight}/{lh}` — create new `@mixin <name>` or use closest `@mixin <closest>`?"

After agents complete — surface conflicts: EC3b (token name mismatch), EC11 (no Figma tokens), typography gaps. User confirms before Phase 2.

### Phase 1.5 — Decompose (conditional)

Only when Agent 1 reveals child component instances.

1. Build dependency tree — deepest children first.
2. Classify each child by FSD layer.
3. Build each child component via Phase 2 before building the parent.
4. Never auto-create primitives silently — if a needed primitive is missing from registry, flag it and stop (run `/create-primitive` first).

### Phase 2 — Implement (2 parallel streams)

**Stream A — Download assets:**
- For each icon node from Phase 1 Agent 1: download SVG via adapter `fetch_svg(nodeId)` → write to `img/<kebab-name>.svg`.
- Never use screenshot for icons — SVG only.

**Stream B — Code generation:**
1. Add missing tokens to `token_file` (from Phase 1 Agent 3 result).
2. Call `adapter.generate(template, tokens, variants, layer, styling_system)` → CSS + JS + preview file contents.
3. Write component files to `<layer>/<slice-name>/`.
4. Register `@import` in main CSS entry file.
5. Run component-done checklist — fix violations before continuing.

### Phase 3 — Visual verify (adapter-specific)

Call `adapter.visual_verify(component, figma_ref)`. Implementation is fully adapter-specific.
- Adapter returns: `pass` or `fail + report`.
- On fail: adapter handles retries and escalation (see adapter's own SKILL.md).
- Generic skill does not implement SSIM, screenshots, or preview tooling.

### Phase 4 — Registry

Upsert registry entry:

```json
{
  "name": "<PascalCase>",
  "type": "primitive | feature | local",
  "layer": "<fsd-layer>",
  "path": "<relative-path-from-project-root>",
  "figma_node_id": "<nodeId>",
  "figma_file_key": "<fileKey>",
  "figma_connected": false,
  "uses": [],
  "created_at": "<ISO-UTC>",
  "status": "in-progress"
}
```

`figma_connected` is set to `true` only after Code Connect is published (Phase 5).

### Phase 5 — Code Connect

1. Scan project for primitive (`*.figma.ts`, `*.figma.js`, or equivalent) → EC13 if not found.
2. Read primitive → extract Code Connect pattern (file format, template, publish command).
3. Call `get_code_connect_map(nodeId, fileKey)` — check if mapping exists; prompt user to confirm replacement if yes.
4. Write `<name>.figma.{ext}` following primitive pattern.
5. Run `cc_publish(--dry-run)` → validate → run `cc_publish`.
6. Update registry: set `figma_connected: true`, `last_figma_sync_at: <now>`.

## Postconditions

After successful completion:

- Component files exist at `<layer>/<slice-name>/`
- `@import` registered in main CSS
- Registry entry present with `figma_node_id` + `figma_connected: true`
- Code Connect file published
- All TodoWrite tasks marked `completed`
- `status: "done"` in registry entry

## Reuse Decision Tree

Applied in Phase 1 Agent 2.

```text
load registry
  ↓
match by figma_node_id (mainComponentNodeId) OR name?
  EXACT  → scan codebase for usages (grep component name in source)
              0 usages → "Exists but unused — add variant or update?"
              N usages → stop "Already exists — reusing"
  PARTIAL → show match, ask: extend / refactor / create new
  NONE   → check filesystem for name collision (EC2)
              files exist on disk → EC2 prompt
              no files           → proceed to Phase 1.5 / Phase 2
```

## Primitive-Check Pattern

A **primitive** is the project's live example of how components connect to Figma — it defines file format, template structure, and publish command. Without it, Code Connect (Phase 5) cannot run.

```text
scan project for *.figma.ts / *.figma.js / equivalent
  found     → read file → extract: format, template, publish_cmd
  not found → EC13: stop, prompt user to run /create-primitive
              user confirms primitive created → continue
```

The primitive is discovered at runtime — never hardcode `.figma.ts` or a specific publish command in the generic skill.

## Tool Failure Pattern

Every tool call is either **critical** or **non-critical**.

| Classification | On failure | Output |
| ---- | ---- | ---- |
| Critical | Stop immediately | Structured report: phase, tool, error, suggested fix |
| Non-critical | Log and continue | Note appended to final report |

### Critical tools

| Tool | Why critical |
| ---- | ---- |
| Figma `whoami` | No token → no design data → nothing to build |
| `get_design_context` (first pass) | No layout → cannot generate component |
| `get_variable_defs` + token file read | Missing token sync → wrong colors/spacing |
| `adapter.generate()` | No files written |
| Registry `upsert` | Component exists but is untracked |

### Non-critical tools

| Tool | On failure |
| ---- | ---- |
| Icon SVG download | Log missing icons (EC4), continue without them |
| `get_code_connect_map` | Assume no existing mapping, proceed |
| `cc_publish(--dry-run)` failure | Note it, ask user to publish manually |
| Component-done checklist violations | Log, show to user, do not hard-stop |

### Structured failure report format

```text
FAILED: <phase> — <tool>
  Error:    <message>
  Expected: <what should have happened>
  Fix:      <suggested action>
  Impact:   <what is missing from output>
```

## EC Handling Rules

| Code | Trigger | Action |
| ---- | ---- | ---- |
| EC2 | Files on disk, name not in registry | Prompt: overwrite existing / register as-is / cancel |
| EC3b | Figma variable name ≠ local token name (same value) | Show conflict table; user picks canonical name; update token file if Figma wins |
| EC4 | No icon nodes detected in Figma | Log note "no icons — img/ not created", continue |
| EC5 | Figma `whoami` returns 401 | Stop — display: "Fix FIGMA_ACCESS_TOKEN in .env or shell environment" |
| EC6 | Component name contains special chars | Show normalized name from `naming_conventions`; user confirms or edits |
| EC7 | Style wiring unclear | Read `styling_system.type` + `styling_system.import_syntax` from `frontend-analysis.json`; apply to generated CSS |
| EC9 | Registry entry exists but `figma_node_id` is null | Ask user for Figma URL before Phase 5 |
| EC10 | `component-registry.json` is malformed JSON | Stop — display: "Run: `jq . .claude/state/component-registry.json` to diagnose" |
| EC11 | `get_variable_defs` returns no variables | Prompt: proceed with empty token list / cancel |
| EC12 | Child component referenced in decompose not in registry | Create child as `type: local` in `ui/` subdirectory — non-blocking |
| EC13 | No primitive found in project | Onboarding prompt — ask user to pick a simple primitive (no children); create it inline with CC pattern setup; then continue with the original component |
