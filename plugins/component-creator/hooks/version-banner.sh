#!/usr/bin/env bash
#
# version-banner.sh — UserPromptSubmit hook
#
# Auto-emit `[plugin vX.Y.Z | skill-name]` banner for any slash-command
# invocation that maps to a skill in THIS plugin.
#
# Plugin-aware via CLAUDE_PLUGIN_ROOT — the same script works for any
# plugin that registers it.
#
# Output: hookSpecificOutput with additionalContext that instructs Claude
# to print the banner as the first line of its response, before any tool
# call. Mechanism mirrors the legacy "Version check — OUTPUT THIS AS YOUR
# VERY FIRST TEXT" pattern that lived inside SKILL.md, but reads the
# version from plugin.json at runtime instead of hardcoding it.

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

# Compose the banner and the instruction
banner="[${plugin_name} v${plugin_version} | ${skill}]"
instruction="OUTPUT THIS BANNER AS YOUR VERY FIRST TEXT, before any tool call (do not paraphrase, do not skip, do not add other prefix): ${banner}"

# Emit as Claude Code hook JSON
jq -n --arg ctx "$instruction" '{
    hookSpecificOutput: {
        hookEventName: "UserPromptSubmit",
        additionalContext: $ctx
    }
}'

exit 0
