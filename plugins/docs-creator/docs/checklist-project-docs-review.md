# Project Documentation Review

Checklist for reviewing documentation generated in a target project. Fill this in after each `/init-project` run. Goal — verify that the docs are accurate, useful, and actually save context.

**Project:** `<name>`
**Date:** `<YYYY-MM-DD>`
**Stack:** `<stack>`
**Type:** single-stack / clean monorepo / feature monorepo

---

## CLAUDE.md — Accuracy

- [ ] Project name and description match reality
- [ ] **Architecture** — description of inter-module communication is correct (verify manually)
- [ ] **Architecture** — hub module named correctly
- [ ] **Architecture** — no invented components or relationships
- [ ] **Build & Run** — `build` command works (copy and execute)
- [ ] **Build & Run** — `test` command works
- [ ] **Build & Run** — `lint` command works
- [ ] **Build & Run** — `run` command works
- [ ] **Project Structure** — all modules listed
- [ ] **Project Structure** — module descriptions accurate
- [ ] **Code Conventions** — naming conventions match the code
- [ ] **Git Conventions** — branch / commit format matches git log
- [ ] No `{{placeholders}}` remaining — all filled in
- [ ] Under 200 lines
- [ ] **Inaccuracies:** `<fill in>`

## CLAUDE.md — Usefulness

- [ ] A new developer can read and understand the project in 2 minutes
- [ ] No redundant information (does not duplicate README or code comments)
- [ ] No implementation details of individual modules (those went into rules)
- [ ] Build commands are sufficient for a first-time run with no extra knowledge
- [ ] **What is missing:** `<fill in>`

---

## Module Rules — Accuracy

For each generated rule file:

### Rule: `<name>.md`

- [ ] `paths:` globs match real files (run Glob to verify)
- [ ] Module description is correct
- [ ] Key Components — real classes / functions listed (verify via grep)
- [ ] Dependencies — dependencies are correct
- [ ] "Used by" — correctly lists consumers of this module
- [ ] Under 50 lines
- [ ] **Errors:** `<fill in>`

### Rule: `<name>.md`

*(copy this block for each rule)*

## Module Rules — Coverage

- [ ] Every significant module (20+ files) has its own rule
- [ ] Hub module has a rule
- [ ] Trivial modules (utils, constants) correctly skipped
- [ ] No unnecessary rules for trivial modules
- [ ] **Modules that need a rule but do not have one:** `<fill in>`
- [ ] **Unnecessary rules:** `<fill in>`

## Module Rules — Cross-references

- [ ] Dependencies between modules are consistent (if A depends on B, then B is "used by" A)
- [ ] No circular-dependency descriptions that do not exist in the code
- [ ] Hub module references every module it integrates
- [ ] **Mismatches:** `<fill in>`

---

## Cross-Cutting Layer Rules (Type 3)

*(only if the project is a feature monorepo)*

### Layer: `<name>.md`

- [ ] Pattern described accurately (spot-check 2-3 files manually)
- [ ] `paths:` globs catch every file of this pattern
- [ ] `paths:` globs do not catch unrelated files
- [ ] File Convention described correctly
- [ ] Common Mistakes are real (ask the developers)
- [ ] Under 40 lines
- [ ] **Errors:** `<fill in>`

---

## Subdirectory CLAUDE.md (monorepo)

### Area: `<area>/CLAUDE.md`

- [ ] The area's role described correctly
- [ ] Build commands are area-specific (do not duplicate root)
- [ ] Conventions are area-specific (do not duplicate root)
- [ ] Under 100 lines
- [ ] **Errors:** `<fill in>`

---

## Settings — `.claude/settings.json`

- [ ] `permissions.allow` contains real build / test / lint commands
- [ ] `permissions.deny` blocks dangerous operations
- [ ] No unnecessary permissions
- [ ] No secrets or tokens
- [ ] **Missing permissions:** `<fill in>`

---

## Context Efficiency

Verify that the documentation actually saves context window:

- [ ] Root CLAUDE.md under 200 lines
- [ ] Each module rule under 50 lines
- [ ] Each layer rule under 40 lines
- [ ] Each subdirectory CLAUDE.md under 100 lines
- [ ] When working on a single module, Claude loads only: root CLAUDE.md + 1 module rule = `<N>` lines (expected: ~100-150)
- [ ] Without rules, everything would be in one CLAUDE.md = `<N>` lines
- [ ] **Measured savings:** `<N>%`

### Context load by scenario

| Scenario | What loads | Lines |
| ---- | ---- | ---- |
| Bug fix in module-a | root + module-a rule | `<N>` |
| Refactor hub module | root + hub rule + deps rules | `<N>` |
| Add a UI component | root + ui layer rule + module rule | `<N>` |
| Whole-project code review | root + all rules | `<N>` |

---

## Freshness Test

Open 3 random module rules and verify they are current:

### Rule 1: `<name>.md`

- [ ] Key Components still exist in the code (grep)
- [ ] Dependencies have not changed
- [ ] No new public API that is not documented
- [ ] **Stale parts:** `<fill in>`

### Rule 2: `<name>.md`

- [ ] Key Components still exist in the code
- [ ] Dependencies have not changed
- [ ] No new public API that is not documented
- [ ] **Stale parts:** `<fill in>`

### Rule 3: `<name>.md`

- [ ] Key Components still exist in the code
- [ ] Dependencies have not changed
- [ ] No new public API that is not documented
- [ ] **Stale parts:** `<fill in>`

---

## Two-Layer Compliance

- [ ] The project does NOT contain meta-rules from the template repo (no-step-numbers, output-format, etc.)
- [ ] The project does NOT contain toolkit skills (init-project, create-docs, etc.)
- [ ] The project does NOT contain reference guides (how-to-create-docs, etc.)
- [ ] The project does NOT contain sequence diagrams for toolkit skills
- [ ] Everything in the project's `.claude/` is project-specific content
- [ ] **Violations:** `<fill in>`

---

## Summary

**Overall accuracy:** `<N>/10` (how well docs reflect the real code)
**Usefulness:** `<N>/10` (does it help a developer onboard faster)
**Context efficiency:** `<N>/10` (context savings)
**Freshness:** `<N>/10` (how current after generation)

**Top 3 inaccuracies to fix:**

1. `<issue>`
2. `<issue>`
3. `<issue>`

**Rules to add:**

1. `<proposal>`
2. `<proposal>`

**Rules to remove:**

1. `<proposal>`
2. `<proposal>`

**Recommendations for toolkit improvement:**

1. `<proposal>`
2. `<proposal>`
