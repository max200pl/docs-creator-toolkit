# component-creator

Claude Code plugin for generating frontend components that match your project's conventions.

## Prerequisites

Run `claude-docs-creator` first to analyze the frontend:

```
/claude-docs-creator:analyze-frontend
/claude-docs-creator:create-frontend-docs
```

This produces `.claude/docs/reference-component-creation-template.md` — the contract this plugin reads.

## Commands

| Command | Description |
| ---- | ---- |
| `/component-creator:create-component <name>` | Scaffold a new component following detected conventions |

## How It Works

1. Reads `.claude/docs/reference-component-creation-template.md` (design system, naming, patterns)
2. Reads `.claude/state/frontend-analysis.json` (framework, component inventory)
3. Generates a component matching the project's conventions exactly

## Status

Work in progress — skill body not yet implemented.
