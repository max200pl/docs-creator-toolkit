---
name: create-component
description: "Create a new frontend component following the project's detected conventions. Use when the user asks to 'create a component', 'add a new component', 'generate a component', or 'scaffold a component'. Requires claude-docs-creator /analyze-frontend to have been run first — reads reference-component-creation-template.md and frontend-analysis.json from the target project's .claude/ directory."
argument-hint: <component-name> [variant]
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
---

# Create Component

> **Prerequisite:** `.claude/docs/reference-component-creation-template.md` must exist in the target project.
> Run `/claude-docs-creator:analyze-frontend` first if it does not.

<!-- TODO: implement skill body -->
