# docs-creator-toolkit

Claude Code plugin collection — `.claude/` documentation authoring + Figma-to-code component creation.

## Plugins

| Plugin | What it does | Status |
| ---- | ---- | ---- |
| `docs-creator` | Generates and maintains `.claude/` documentation for any project — architecture, design system, component conventions, data flow, API contracts | stable `v0.15.0` |
| `component-creator` | Creates UI components from Figma designs with visual verification, Code Connect integration, and component registry management | beta `v0.0.6` |

## Installation

### Step 1 — Add marketplace to your `~/.claude/settings.json`

```json
{
  "extraKnownMarketplaces": {
    "docs-creator-toolkit": {
      "source": {
        "source": "github",
        "repo": "max200pl/docs-creator-toolkit"
      }
    }
  }
}
```

### Step 2 — Enable plugins

```json
{
  "enabledPlugins": {
    "docs-creator@docs-creator-toolkit": true,
    "component-creator@docs-creator-toolkit": true
  }
}
```

### Step 3 — Restart Claude Code

Plugins load automatically on next session start. Skills are namespaced:

```
/docs-creator:init-project
/docs-creator:analyze-frontend
/docs-creator:create-frontend-docs
/docs-creator:menu          ← shows all available commands

/component-creator:create-component <figma-url>
```

---

## Quick start — docs-creator

```
# 1. Initialize .claude/ in your project
/docs-creator:init-project

# 2. Analyze frontend (if applicable)
/docs-creator:analyze-frontend

# 3. Generate human-readable docs
/docs-creator:create-frontend-docs

# 4. See all available commands
/docs-creator:menu
```

## Quick start — component-creator

Requires `docs-creator` analysis to have run first (`reference-component-creation-template.md` must exist).

```
# Create a component from Figma design
/component-creator:create-component https://www.figma.com/design/<fileKey>?node-id=<nodeId>
```

---

## Per-project setup (alternative to global settings)

Add to your project's `.claude/settings.json` instead of `~/.claude/settings.json` to limit the plugins to a specific project:

```json
{
  "extraKnownMarketplaces": {
    "docs-creator-toolkit": {
      "source": {
        "source": "github",
        "repo": "max200pl/docs-creator-toolkit"
      }
    }
  },
  "enabledPlugins": {
    "docs-creator@docs-creator-toolkit": true,
    "component-creator@docs-creator-toolkit": true
  }
}
```

---

## Repository layout

```text
.claude-plugin/
  marketplace.json    ← plugin registry
plugins/
  docs-creator/       ← .claude/ documentation toolkit
  component-creator/  ← Figma-to-code component scaffolding
```

## Source

Development repo: [max200pl/claude-docs-creator](https://github.com/max200pl/claude-docs-creator)
This repo is auto-synced from the monorepo via GitHub Actions.
