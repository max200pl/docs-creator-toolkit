---
description: "Strict field allowlist for component-registry.json. Any field not in this list is forbidden. Skills must never write custom or per-variant fields to the registry."
---

# Registry Schema — Allowed Fields Only

## Rule

`component-registry.json` entries may contain **only** the fields listed below. Writing any other field is forbidden — no exceptions, no per-variant extras, no debug metadata.

## Allowed Fields

| Field | Type | Set at | Description |
| ---- | ---- | ---- | ---- |
| `name` | string | Phase 4 | PascalCase component name |
| `type` | `"primitive" \| "feature" \| "local"` | Phase 4 | Component classification |
| `layer` | string | Phase 4 | FSD layer path (e.g. `widgets`, `shared/ui`) |
| `path` | string | Phase 4 | Relative path from project root to main `.js` file |
| `figma_node_id` | string | Phase 4 | Figma component set node ID (not variant) |
| `figma_file_key` | string | Phase 4 | Figma file key from URL |
| `figma_connected` | boolean | Phase 5 | `true` after Code Connect published |
| `uses` | string[] | Phase 4 | Names of primitive components this component uses |
| `parent` | string \| null | Phase 4 | Parent component name for `type: local` entries |
| `variants` | string[] | Phase 4 | Built variant identifiers (e.g. `["prim", "sec"]`). `[]` for single-variant |
| `created_at` | ISO-UTC string | Phase 4 | Creation timestamp |
| `last_verified_at` | ISO-UTC string \| null | Phase 3 | Last SSIM verification timestamp |
| `last_figma_sync_at` | ISO-UTC string \| null | Phase 5 | Last Code Connect sync timestamp |
| `figma_last_modified` | ISO-UTC string \| null | sync-registry | Figma's own last-modified timestamp for the node |
| `ssim_score` | number \| null | Phase 3 | Best SSIM score for the primary variant |
| `status` | `"in-progress" \| "done" \| "stale" \| "needs-review" \| "unverified"` | Phase 4/5 | Lifecycle state |

## Forbidden

Any field not in the table above. Common violations to reject:

| Forbidden field | Where it belongs instead |
| ---- | ---- |
| `sec_icon_ssim`, `icon_ssim`, per-variant SSIM | Agent memory (`feedback_ssim_<topic>.md`) |
| `notes`, `comment`, `description` | Commit message or agent memory |
| `ssim_prim`, `ssim_sec` | Not stored — run verify again if needed |
| `preview_path`, `screenshot` | ScreenshotHistory filenames are not stored |
| `figma_url` | Derivable from `figma_file_key` + `figma_node_id` |
| `component_set_id` | Same as `figma_node_id` (always store the set, not the variant) |

## Why

The registry is the source of truth for component existence and Figma linkage. It is read by `validate-registry`, `sync-registry`, and `update-registry`. Unknown fields silently break those skills' assumptions and accumulate technical debt.

Per-variant SSIM scores, notes, and other metadata belong in agent memory — they are session-specific learning, not permanent component state.

## Enforcement

Before writing any registry entry (Phase 4), validate that all keys in the new/updated object are in the allowed list above. If a key is not in the list → stop and report:

```
REGISTRY SCHEMA VIOLATION: field "<key>" is not in the allowed schema.
Store this in agent memory instead, or discard.
```
