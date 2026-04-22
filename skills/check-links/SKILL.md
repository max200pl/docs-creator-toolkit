---
name: check-links
scope: api
description: "Scan a target project's .md and .mmd files for broken cross-refs — dead relative links in Markdown and stale @-imports in CLAUDE.md. Runs as an on-demand audit; the companion PostToolUse hook catches single-file drift as Claude edits. Skips matches inside fenced code blocks, inline code, and placeholder paths (<path>). Useful after renaming/moving docs or when /validate-claude-docs surfaces broken-ref warnings you want to isolate."
user-invocable: true
argument-hint: "[project-path | --all | --dir <path>]"
---

# Check Links

> **Runner:** `hooks/check-links.sh` — same shared bash scanner used by the plugin's PostToolUse hook.
> Style rules: read `rules/markdown-style.md`, `rules/output-format.md`
> Related: `/validate-claude-docs` covers structural validation — this skill focuses specifically on cross-ref integrity.

Scans `.md` and `.mmd` files in a target project for broken cross-refs. Two classes of refs are covered:

- **Markdown links** — `[text](./path.md)` or `[text](../dir/path.mmd#anchor)`. Resolved relative to the source file; if the resolved absolute path does not exist, warn.
- **`@`-imports** — only in root `CLAUDE.md` / `CLAUDE.local.md`. Resolved from the project root.

Built-in false-positive suppression (no flag needed):

- Fenced code blocks (```` ``` ````) — refs inside are treated as examples, not live cross-refs.
- Inline code (`` ` ... ` `` runs) — same.
- Placeholder paths containing `<` or `>` (e.g. `<path>.md`, `./<name>.md`) — skipped.
- External URLs (`http://`, `https://`, `mailto:`) — skipped.

## Usage

```text
/check-links                      # scan current project (cwd)
/check-links ~/Projects/my-app    # scan a target project path
/check-links --dir docs           # scan a subtree of current project
/check-links <single-file>        # scan one file
```

The companion PostToolUse hook (auto-registered by the plugin) runs the scanner on any `.md` / `.mmd` file Claude writes or edits, so freshly-broken refs surface as `systemMessage` without you having to run this skill manually.

## What To Do With Findings

| Finding | Fix |
| ---- | ---- |
| `[WARN] <file>:<line> → <path> (not found)` | Target was renamed/moved/deleted. Update the ref, or remove it if stale. |
| `@<path>` in `CLAUDE.md` not found | File was renamed or deleted — update the import path. |

Exit codes (when invoking the script directly from bash or CI):

| Code | Meaning |
| ---- | ---- |
| 0 | Clean |
| 2 | At least one broken ref |

## What This Skill Does NOT Do

- Anchor resolution — `#heading` fragments are stripped before the exists check. A valid file with a missing heading won't trigger a warning. Anchor-aware validation is a v2 candidate.
- Paths in prose inside backticks (`` `docs/foo.md` ``) — NOT checked by default. Too noisy; may be added as an opt-in `--scan-backticks` flag later.
- Auto-fix — never rewrites files. All changes are human decisions.
- External URL validation — no HTTP HEAD checks on `https://...` links.
- Mermaid internal node references — flowchart/sequence node labels that mention filenames are not parsed.
