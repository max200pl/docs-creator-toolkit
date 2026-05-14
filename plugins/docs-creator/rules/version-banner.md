# Version Banner Pattern

## Rule

Every skill invocation (`/<plugin>:<skill>` or `/<skill>` for installed plugins) MUST be preceded by a banner line. Two forms:

```text
# Current — running version matches latest in marketplace
[<plugin-name> v<version> | <skill-name>]

# Outdated — a newer version is available in the marketplace
[<plugin-name> v<current-version> → <latest-version> available | <skill-name>]
```

Output components:

- `<plugin-name>` — the plugin's `name` field from its `plugin.json`
- `<current-version>` — the plugin's `version` field from its `plugin.json` (the version actually running in this session)
- `<latest-version>` — the version listed for this plugin in the locally-cached marketplace.json (last fetched on `/plugin marketplace update`)
- `<skill-name>` — the directory name under `skills/` corresponding to the invoked slash command

The banner is **auto-emitted by a `UserPromptSubmit` hook** named `version-banner.sh`, identical in every plugin that ships it. Each plugin's hook reads its own `plugin.json` at runtime — no version is hardcoded anywhere. The update check is best-effort, local-file only (no network).

## Why

Users running plugins via the marketplace cache often have multiple versions installed in parallel (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`). Without a banner, a stale active version can silently run instead of the latest — producing outputs from the wrong codebase and confusing diagnosis.

The banner makes the running version visible at every invocation. If the displayed version doesn't match what the user expects, they know to `/plugin upgrade` or restart the session.

A previous iteration of this pattern hardcoded the version in each `SKILL.md` (e.g. `[component-creator v0.0.23 | sciter-create-component]`). That worked but introduced drift: every version bump required search/replace across every `SKILL.md`, and forgetting one left the banner lying. The hook-based version reads from `plugin.json` at runtime — zero drift possible.

## How to enable in a new plugin

1. **Copy the hook script** to the new plugin's `hooks/` directory:

   ```bash
   mkdir -p plugins/<new-plugin>/hooks
   cp plugins/docs-creator/hooks/version-banner.sh plugins/<new-plugin>/hooks/
   chmod +x plugins/<new-plugin>/hooks/version-banner.sh
   ```

2. **Register the hook** in the plugin's `hooks/hooks.json`:

   ```json
   {
     "hooks": {
       "UserPromptSubmit": [
         {
           "hooks": [
             { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/version-banner.sh" }
           ]
         }
       ]
     }
   }
   ```

3. **Verify** by smoke-testing the script directly:

   ```bash
   echo '{"prompt": "/<plugin-name>:<some-skill>"}' \
     | CLAUDE_PLUGIN_ROOT=plugins/<new-plugin> \
       bash plugins/<new-plugin>/hooks/version-banner.sh
   ```

   Expected output:

   ```json
   {
     "hookSpecificOutput": {
       "hookEventName": "UserPromptSubmit",
       "additionalContext": "OUTPUT THIS BANNER AS YOUR VERY FIRST TEXT... [<plugin-name> v<version> | <skill-name>]"
     }
   }
   ```

## Hook script behaviour

`version-banner.sh` matches the user's prompt against two patterns (in priority order):

| Pattern | Match | Example | Banner |
| ---- | ---- | ---- | ---- |
| `/<plugin-name>:<skill>` | Explicit namespace | `/docs-creator:menu` | `[docs-creator v0.18.1 \| menu]` |
| `/<skill>` | Implicit — only if `skills/<skill>/` exists in THIS plugin | `/check-links` (docs-creator) | `[docs-creator v0.18.1 \| check-links]` |

If the prompt is not a slash command, or the skill does not exist in THIS plugin, the hook exits silently with code 0 (no output).

Each plugin's hook only emits a banner for its OWN skills. When both plugins are installed, `/docs-creator:menu` triggers docs-creator's hook (emits banner) and component-creator's hook (silent — `menu` is not in component-creator).

### Update detection

After resolving the banner, the hook performs a best-effort check against the locally-cached marketplace catalog:

1. **Marketplace discovery** — two methods, tried in order:
   - **Path regex** on `CLAUDE_PLUGIN_ROOT`: if it matches `…/plugins/cache/<marketplace>/<plugin>/<version>/`, the marketplace name is extracted directly.
   - **Fallback scan**: walk `~/.claude/plugins/marketplaces/*/` and find the marketplace whose `marketplace.json` lists THIS plugin's name. This covers dev-mode launches (`--plugin-dir` against a repo checkout).
2. **Version comparison** — `sort -V` (lexicographic version sort) is used to find the newest of `(running, latest)`.
3. **Emit** — if `latest > running`, the banner becomes `[plugin v<current> → <latest> available | skill]`.

Edge cases handled:

- **No marketplace registered for this plugin** → no update suffix (clean banner)
- **Running version newer than marketplace** (dev build or pre-release) → no downgrade suggestion
- **Marketplace.json malformed or unreachable** → no update suffix; hook never errors out

The check is **best-effort and offline**. It compares against the marketplace's last-cached state, NOT against the upstream git repo. To refresh the marketplace cache, the user must run `/plugin marketplace update <marketplace-name>` followed by `/plugin upgrade <plugin>` or a session restart.

## What NOT to do

- **Do not hardcode the version in any `SKILL.md`** — the hook handles it. Hardcoding reintroduces the drift problem the hook was designed to eliminate. `/sleep` lints for this.
- **Do not call any other hook event** for version banner — `UserPromptSubmit` is the right fit; `PreToolUse` fires after Claude has already started responding (banner would land too late).
- **Do not modify `version-banner.sh`** to add per-plugin logic — keep it identical across plugins so behaviour is predictable. If a plugin needs a different banner format, that is a sign the convention should change everywhere.

## How to apply

| When | Action |
| ---- | ---- |
| Adding a new plugin to the marketplace | Copy + register `version-banner.sh` as part of plugin scaffolding |
| Bumping a plugin's version | Nothing to do — hook reads new version from `plugin.json` automatically |
| Renaming a skill | Hook auto-handles — banner picks up new directory name |
| Adding a new skill | Hook auto-handles — banner emits when user invokes the new slash command |
| Migrating from hardcoded SKILL.md banner | Delete the hardcoded `### Version check` block; ensure plugin has `version-banner.sh` registered |

## Enforcement

- `/sleep` checks each plugin has `hooks/version-banner.sh` and that `hooks/hooks.json` registers `UserPromptSubmit`.
- `/sleep` flags any `SKILL.md` that contains a hardcoded version pattern (`v\d+\.\d+\.\d+` outside frontmatter) as a stale-banner candidate.
- The hook's smoke-test command (above) is the canonical way to verify a fresh plugin scaffolding picked up the pattern.
