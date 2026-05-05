---
description: "Two registry files exist — one is the source of truth (JSON), one is a read-only view (markdown). Never confuse them."
---

# Registry Files

## Rule

Two files exist for the component registry. They serve different purposes and must never be confused.

| File | Role | Written by | Read by |
| ---- | ---- | ---- | ---- |
| `.claude/state/component-registry.json` | **Source of truth** — machine-readable, all queries and writes go here | Skills (Phase 4) | Skills, validate-registry, sync-registry |
| `.claude/docs/reference-component-registry.md` | **Read-only view** — human-readable markdown table generated from the JSON | `create-frontend-docs`, `update-frontend-docs` only | Humans |

## What Skills Must Do

- **Read:** always load `component-registry.json` for reuse checks, registry lookups, and writes
- **Write:** always write to `component-registry.json` — never to `reference-component-registry.md`
- **Never** use `reference-component-registry.md` as a template for new entries — use `rules/registry-schema.md`

## Why

`reference-component-registry.md` is generated from `component-registry.json` and may be stale. Skills that write to the markdown instead of the JSON will:
1. Create entries that are invisible to `validate-registry` and `sync-registry`
2. Produce data that will be overwritten on the next `update-frontend-docs` run
3. Cause silent data loss

## Enforcement

`/sleep` checks that no skill writes to `reference-component-registry.md` directly. Any `Write` or `Edit` on that path outside of `create-frontend-docs` / `update-frontend-docs` is flagged as a violation.
