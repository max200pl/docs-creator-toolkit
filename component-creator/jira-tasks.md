# Jira Tasks — Component Creator Plugin

Parent ticket: DU-2226

---

## Task 1

**Summary**
Prepare infrastructure for automated component creation

**Context**
The component creator plugin needs machine-readable outputs from the existing docs-creator analysis tools (analyze-frontend, create-frontend-docs) to work automatically. Currently these tools write only human-readable markdown. This task adds structured data fields so the component creator can read token file paths, naming conventions, styling system type, and the initial component registry without manual configuration.

**Acceptance Criteria**
- `reference-design-system.md` contains `token_file:` and `typography_file:` as frontmatter fields after running `/create-frontend-docs`
- `reference-component-inventory.md` contains a `naming_conventions:` block with `component_file`, `css_file`, `class_name`, `directory` fields
- `frontend-analysis.json` contains a `styling_system:` block with `type`, `entry_file`, `import_syntax` fields
- `component-registry.json` is produced at `.claude/state/component-registry.json` seeded from existing components
- `plugins/component-creator/.claude-plugin/plugin.json` exists with valid `name`, `version`, `repository` fields

---

## Task 2

**Summary**
Build the core component creation workflow

**Context**
The generic `create-component` skill is the foundation of the plugin — it orchestrates the full component creation flow from Figma URL to files on disk, independent of any specific framework. It reads from the outputs produced in Task 1, handles all common failure scenarios (invalid URLs, expired tokens, missing registry, token conflicts, style wiring), and delegates technology-specific steps to framework adapters built in Task 3.

**Acceptance Criteria**
- Pre-flight check catches expired Figma token (401) before any work starts
- Registry reuse check correctly detects EXACT MATCH and stops with "Reusing existing"
- Files-on-disk-but-not-in-registry case shows user a choice prompt (overwrite / register as-is / cancel)
- Token naming mismatches show unmapped-token option to user
- Style wiring reads import system from `frontend-analysis.json` (no hardcoded `@import`)
- Sequence diagram in `sequences/create-component.mmd` matches the actual skill execution order
- All common failure scenarios produce user-friendly messages, not raw errors

---

## Task 3

**Summary**
Build Sciter.js adapter and onboarding skill

**Context**
Sciter.js uses a non-standard CSS dialect (dip units, `flow:` layout, `@mixin` typography) and has no browser-based visual testing — screenshots are taken from the running desktop app and compared against Figma using SSIM. This task delivers the Sciter-specific adapter that handles these constraints, plus a one-time onboarding skill (`create-primitive`) that bootstraps the project's Figma Code Connect pattern so subsequent component creations can auto-discover the correct file format and publish command.

**Acceptance Criteria**
- `create-primitive` creates a minimal component and establishes `.figma.ts` Code Connect pattern in the registry
- `sciter-create-component` applies dip units, `flow:` layout, and `@mixin typography` automatically
- SSIM check fires after component creation; retries up to 3 times before escalating
- After 3 failed SSIM attempts: shows user side-by-side comparison, asks for explanation, saves fix to agent memory
- Screenshot history stores `_code_<name>.png` and `_figma_<name>.png` (no overlays)
- If no primitive exists in registry, `create-primitive` launches inline without stopping the flow

---

## Task 4

**Summary**
Build component registry management

**Context**
The component registry (`component-registry.json`) is the source of truth for all components in the project. As the project grows, components get renamed, moved, or go out of sync with Figma. This task delivers three maintenance skills: `sync-registry` keeps Figma connection status up to date, `validate-registry` catches integrity issues and flags components ready for promotion from local to shared, and `update-registry` handles individual entry updates after manual renames.

**Acceptance Criteria**
- `sync-registry` updates `figma_connected` status for all primitive entries and flags stale `figma_node_id`s
- `validate-registry` reports all components whose files are missing from disk
- `validate-registry` detects local components used in 2+ other components and suggests promotion to `shared/ui`
- `validate-registry` detects name collisions across layers (e.g. `shared/ui/Button` + `features/Button`) and flags as error
- `update-registry` renames one entry and updates all `uses` references across the registry in one command

---

## Task 5

**Summary**
Field test on production project

**Context**
Before declaring the plugin usable, it must be validated end-to-end on a real Sciter.js project (sciterjsMacOS). Three components of increasing complexity are created to cover the main flow variations: a simple primitive, a feature component built from existing primitives, and a component with multiple visual states. This is the primary quality gate before the v0.1.0 release.

**Acceptance Criteria**
- Primitive component (e.g. `Badge`) created end-to-end: SSIM ≥ 0.95, registry entry complete with `figma_node_id` and `figma_connected: true`
- Feature component (e.g. `UserCard`) created with composition detection: `uses` field populated, Code Connect suggestions used
- Component with variants (hover/active/disabled) created: single JS+CSS file, all states in CSS
- All 3 components pass code review without style corrections
- `validate-registry` runs clean after all 3 components added
- No edge cases encountered outside of EC1–EC16 already handled by the plugin

---

## Task 6

**Summary**
Extended skills and final release

**Context**
The final phase completes the remaining planned capabilities: component update flow (for when a design changes after initial creation), full-page scaffolding, and i18n support detection. It also includes cleanup of the temporary extraction tools used during the build-plan phase. On completion, M10 in the main project roadmap is marked done and the plugin is published at v0.1.1.

**Acceptance Criteria**
- `update-component` correctly diffs Figma changes against existing code, presents a change report, and applies patches only after user confirmation — never overwrites hand-tweaked code silently
- `create-page` analyzes a Figma page URL, maps it to existing components, and scaffolds the page with all components placed in the correct directory
- i18n detection added to `analyze-frontend` — if localization patterns found, `reference-i18n.md` is generated
- Temporary extraction toolkit deleted: no broken cross-refs in `/menu` or `skill-scopes.md`
- `/validate-claude-docs` and `/check-links` pass clean on `plugins/component-creator/`
- M10 checklist in `milestones.md` fully ticked and status set to `done`
