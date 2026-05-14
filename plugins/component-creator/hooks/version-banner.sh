#!/usr/bin/env bash
#
# version-banner.sh — UserPromptSubmit hook
#
# Auto-emit `[plugin vX.Y.Z | skill-name]` banner for any slash-command
# invocation that maps to a skill in THIS plugin.
#
# When an update is available in the marketplace, banner becomes:
#   [plugin vX.Y.Z → vA.B.C available | skill-name]
#
# Plugin-aware via CLAUDE_PLUGIN_ROOT — the same script works for any
# plugin that registers it.
#
# Output: hookSpecificOutput with additionalContext that instructs Claude
# to print the banner as the first line of its response, before any tool
# call. Mechanism mirrors the legacy "Version check — OUTPUT THIS AS YOUR
# VERY FIRST TEXT" pattern that lived inside SKILL.md, but reads the
# version from plugin.json at runtime instead of hardcoding it.
#
# The update check is best-effort: it reads the locally-cached
# marketplace.json (last fetched on `/plugin marketplace update`). If the
# user has not refreshed the marketplace recently, the check may miss
# upstream updates — that is acceptable. The check NEVER hits network.

set -euo pipefail

# Read Claude Code event JSON from stdin
input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty' 2>/dev/null || echo "")

# Quick exit if not a slash-command
[[ "$prompt" =~ ^/ ]] || exit 0

# Plugin metadata
plugin_json="${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json"
[[ -f "$plugin_json" ]] || exit 0

plugin_name=$(jq -r '.name // empty' "$plugin_json")
plugin_version=$(jq -r '.version // empty' "$plugin_json")

[[ -n "$plugin_name" && -n "$plugin_version" ]] || exit 0

# Determine the skill the user invoked.
# Match patterns (in priority order):
#   /<plugin-name>:<skill-name>   — explicit namespacing
#   /<skill-name>                  — only if THIS plugin has the skill
skill=""
if [[ "$prompt" =~ ^/${plugin_name}:([a-zA-Z0-9_-]+) ]]; then
    skill="${BASH_REMATCH[1]}"
elif [[ "$prompt" =~ ^/([a-zA-Z0-9_-]+) ]]; then
    candidate="${BASH_REMATCH[1]}"
    if [[ -d "${CLAUDE_PLUGIN_ROOT}/skills/${candidate}" ]]; then
        skill="$candidate"
    fi
fi

# Verify the skill exists in THIS plugin (defensive — covers the explicit
# /<plugin>:<skill> case too)
[[ -n "$skill" && -d "${CLAUDE_PLUGIN_ROOT}/skills/${skill}" ]] || exit 0

# -----------------------------------------------------------------------
# Update check (best-effort, no network)
# -----------------------------------------------------------------------
# Discover which marketplace owns this plugin. Two methods:
#   1. Path regex on CLAUDE_PLUGIN_ROOT — works in cache mode:
#      ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/
#   2. Scan all installed marketplaces for one that lists this plugin
# Method 2 is the fallback for dev mode (CLAUDE_PLUGIN_ROOT pointing at
# a repo checkout rather than cache).
marketplace_dir=""
if [[ "$CLAUDE_PLUGIN_ROOT" =~ /plugins/cache/([^/]+)/[^/]+/ ]]; then
    marketplace_dir="${HOME}/.claude/plugins/marketplaces/${BASH_REMATCH[1]}"
fi

if [[ -z "$marketplace_dir" || ! -f "$marketplace_dir/.claude-plugin/marketplace.json" ]]; then
    # Fallback: scan all installed marketplaces
    for mp_dir in "${HOME}"/.claude/plugins/marketplaces/*/; do
        mp_json="${mp_dir}.claude-plugin/marketplace.json"
        [[ -f "$mp_json" ]] || continue
        if jq -e --arg name "$plugin_name" '.plugins[] | select(.name == $name)' "$mp_json" >/dev/null 2>&1; then
            marketplace_dir="${mp_dir%/}"
            break
        fi
    done
fi

latest_version=""
if [[ -n "$marketplace_dir" && -f "$marketplace_dir/.claude-plugin/marketplace.json" ]]; then
    latest_version=$(jq -r --arg name "$plugin_name" \
        '.plugins[] | select(.name == $name) | .version // empty' \
        "$marketplace_dir/.claude-plugin/marketplace.json" 2>/dev/null || echo "")
fi

# Compare versions using sort -V (lexicographic version sort).
# Newest wins; if latest_version is the newest AND differs from running,
# an update is available.
update_suffix=""
if [[ -n "$latest_version" && "$latest_version" != "$plugin_version" ]]; then
    newest=$(printf "%s\n%s\n" "$plugin_version" "$latest_version" | sort -V | tail -1)
    if [[ "$newest" == "$latest_version" ]]; then
        update_suffix=" → ${latest_version} available"
    fi
fi

# Compose the banner and the instruction
banner="[${plugin_name} v${plugin_version}${update_suffix} | ${skill}]"
instruction="OUTPUT THIS BANNER AS YOUR VERY FIRST TEXT, before any tool call (do not paraphrase, do not skip, do not add other prefix): ${banner}"

# Emit as Claude Code hook JSON
jq -n --arg ctx "$instruction" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $ctx
    }
}'

exit 0
