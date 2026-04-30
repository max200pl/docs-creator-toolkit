---
description: "Defines which .claude/state/ files are committed vs gitignored. Analysis JSON and registries are committed; reports and local timestamps are gitignored."
paths:
  - ".claude/state/**"
  - ".gitignore"
---

# `.claude/state/` Gitignore Policy

## Rule

Not everything in `.claude/state/` is ephemeral. Commit analysis results and
user-enriched registries. Ignore only per-run reports and local timestamps.

## Gitignore Block

`/init-project` writes this block into the target project's `.gitignore`:

```gitignore
# claude-docs-creator — ephemeral state only
.claude/state/reports/
.claude/state/last-*
.claude/state/compression-snapshot.txt
```

Everything else in `.claude/state/` is committed by default.

## File-by-file Policy

| File | Git | Reason |
| ---- | ---- | ---- |
| `state/frontend-analysis.json` | **commit** | Expensive to regenerate (6+ subagents). Teammates can run `/create-frontend-docs` without re-running analysis. |
| `state/api-contracts-analysis.json` | **commit** | Same — expensive fan-out analysis. |
| `state/component-registry.json` | **commit** | User adds Figma node IDs and `figma_connected` flags manually. Losing these on re-analyze would destroy the Figma link graph. |
| `state/reports/*.md` | **ignore** | Per-run execution logs. Ephemeral. Human-readable but not source of truth. |
| `state/last-distill` | **ignore** | Local timestamp sentinel. Machine-specific. |
| `state/last-sleep` | **ignore** | Local timestamp sentinel. Machine-specific. |
| `state/last-*` | **ignore** | Any future `last-<skill>` sentinel. |
| `state/compression-snapshot.txt` | **ignore** | Per-session auto-load cost snapshot. Machine-local — changes every session as docs evolve. |

## Why component-registry.json Must Be Committed

The registry is the only persistent link between code components and Figma nodes.
`figma_node_id` and `figma_connected: true` are set by the user (or by
`/sync-registry`) — not by static analysis. Re-running `/analyze-frontend`
regenerates the list from scratch and would reset all Figma connections to
`figma_connected: false`. The merge logic in `/create-frontend-docs` and
`/update-frontend-docs components` preserves `figma_connected: true` records
precisely because the file is assumed to be version-controlled.

## What Skills Must Do

- `/init-project` — write the gitignore block above into target `.gitignore`
- `/create-frontend-docs` — create `component-registry.json` (committed)
- `/update-frontend-docs components` — merge-update `component-registry.json` (preserve `figma_connected: true`)
- Any skill writing `state/reports/*.md` — mark as ephemeral in the report header; no special action needed (gitignore covers it)
- Skills must NOT write `state/last-*` files that contain user-enriched data — those names are reserved for sentinels only
