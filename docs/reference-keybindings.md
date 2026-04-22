# Keybindings Reference

> Recommended per-user keyboard shortcuts for `claude-docs-creator` workflows. Apply these to `~/.claude/keybindings.json` — keybindings are user-level, not project-level, so the toolkit cannot ship them automatically.

## Why Set These

The toolkit's most-used commands — `/menu`, `/sleep`, `/distill` — are invoked frequently enough that typing the full slash command every time creates friction. One-keystroke access turns "let me run a retrospective" from a 15-second task into a reflex.

## Recommended Bindings

| Shortcut | Command | When to use |
| ---- | ---- | ---- |
| `cmd+m` | `/menu` | Navigation hub — overview of available skills, current status, suggested next action |
| `cmd+shift+s` | `/sleep` | Lint + auto-fix toolkit before commit |
| `cmd+shift+d` | `/distill` | Retrospective — extract lessons into prioritized improvement list |
| `cmd+shift+v` | `/validate-claude-docs .` | Audit the current project's `.claude/` |
| `cmd+shift+u` | `/update-docs .` | Refresh drifted docs in the current project |
| `cmd+shift+n` | `/init-project .` | Initialize `.claude/` for a fresh project |
| `cmd+alt+i` | `/status .` | Quick health dashboard |

Adjust per OS: use `ctrl` instead of `cmd` on Linux / Windows terminals.

## Applying Them

Open `~/.claude/keybindings.json` (create if absent) and add bindings in the format Claude Code expects. If unsure of the current format, invoke the `keybindings-help` skill — it walks through the schema interactively and writes the file correctly for the current Claude Code version.

## What NOT to Bind

- Destructive actions (`git push --force`, `rm -rf`) — one-key access to irreversible commands is a foot-gun waiting to happen.
- Skills that take required arguments (e.g., `/create-docs <type>`) — binding them would fire without arguments and drop into the interactive prompt, negating the speed benefit.
- Any keybinding that conflicts with your terminal's existing shortcuts (check your `iTerm2` / `Alacritty` / `kitty` config first).

## Verification

After editing `~/.claude/keybindings.json`, restart Claude Code. The status line does not show bound keys — test each binding by pressing it and watching for the slash command to appear in the input area.

If a binding doesn't fire: the most common cause is terminal emulator intercepting the key before Claude Code sees it. Try a different chord (e.g., `cmd+shift+m` instead of `cmd+m`).
