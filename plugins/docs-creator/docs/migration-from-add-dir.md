# Migration: from `--add-dir` to plugin install

If you used `claude-docs-creator` before the M5 monorepo restructure (before 2026-04-28), this guide covers the two breaking changes: the plugin rename and the new install path.

## What changed

| Before | After |
| ---- | ---- |
| Plugin name | `claude-docs-creator` | `docs-creator` |
| Skill namespace | `/claude-docs-creator:<skill>` | `/docs-creator:<skill>` |
| Install via `--plugin-dir` | `--plugin-dir ~/Projects/claude-docs-creator` | `--plugin-dir ~/Projects/claude-docs-creator/plugins/docs-creator` |
| Install from public repo clone | `--plugin-dir ~/clone/claude-docs-creator-plugin` | `--plugin-dir ~/clone/docs-creator-toolkit/docs-creator` |
| Public repo | `max200pl/claude-docs-creator-plugin` | `max200pl/docs-creator-toolkit` |

## Migration steps

### 1. Update your clone

If you cloned the public plugin repo directly:

```bash
# Remove old clone
rm -rf ~/clone/claude-docs-creator-plugin

# Clone the new toolkit repo
git clone https://github.com/max200pl/docs-creator-toolkit ~/clone/docs-creator-toolkit
```

### 2. Update your session start command

Replace every occurrence of the old `--plugin-dir` or `--add-dir` path:

```bash
# Before
claude --add-dir ~/Projects/claude-docs-creator
claude --plugin-dir ~/Projects/claude-docs-creator

# After
claude --plugin-dir ~/Projects/claude-docs-creator/plugins/docs-creator
# or from public clone:
claude --plugin-dir ~/clone/docs-creator-toolkit/docs-creator
```

### 3. Update shell aliases or scripts

If you have aliases in `~/.zshrc` / `~/.bashrc`:

```bash
# Before
alias claude-docs='claude --add-dir ~/Projects/claude-docs-creator'

# After
alias claude-docs='claude --plugin-dir ~/Projects/claude-docs-creator/plugins/docs-creator'
```

### 4. Update skill invocations in any scripts or documentation

```bash
# Before
/claude-docs-creator:init-project
/claude-docs-creator:analyze-frontend

# After
/docs-creator:init-project
/docs-creator:analyze-frontend
```

### 5. Target project `.claude/settings.json` (if you registered the plugin there)

If any target project's `.claude/settings.json` references the old plugin path or name, update accordingly.

## No action needed for

- Generated `.claude/` content in target projects (rules, docs, sequences) — these are project-owned files, the plugin rename doesn't affect them.
- Claude Code keybindings (`~/.claude/keybindings.json`) — keybindings call skill names without the namespace prefix, so they are unaffected.
