---
name: distill
scope: shared
description: "Reflect on the recent session and propose prioritized improvements to the project's .claude/ docs — bugs, gaps, validated patterns, and user feedback mapped to concrete file changes with Impact/Cost estimates."
user-invocable: true
argument-hint: "[focus: skills | rules | docs | bugs]"
---

# Distill Session Into Doc Improvements

> **Flow:** read `.claude/sequences/distill.mmd` if present (toolkit repo only) — otherwise follow the phases below
> Output rules: read `rules/output-format.md`

Retrospective skill. Scans the current session, memory, and recent git history to extract lessons learned and propose concrete improvements to the project's `.claude/` documentation. Run at the end of a session after a significant doc-creation or doc-update run.

Use when: a session exposed bugs in generated docs, produced new patterns, or generated user feedback — and you want to capture those into permanent `.claude/` improvements.

## Usage

```text
/distill           # full retrospective — bugs + gaps + patterns + feedback
/distill skills    # focus on SKILL.md / skill behavior findings
/distill rules     # focus on rule updates
/distill docs      # focus on documentation gaps
/distill bugs      # only bugs
```

## What to extract

Four categories. Every finding must be one of these.

| Category | How to detect | Example |
| ---- | ---- | ---- |
| **Bug** | User said "wrong", "broken", "this is a bug"; output didn't match expectation; file produced was malformed | Wrong frontmatter generated; paths: glob too broad; SKIP not respected |
| **Gap** | User asked for a check / feature that doesn't exist; validation missed a real issue | No placeholder written for empty registry; missing field in generated rule |
| **Pattern** | Something worked well and is worth replicating | Scoped rule with tight `paths:` prevented false activations |
| **Feedback** | User preference stated (`stop doing X`, `I want Y`, `this is the right approach`) | Always write registry even when empty |

Anything that doesn't fit one of these four is noise — discard.

## Sources to scan

Do all of these before categorizing:

- **Memory** — Glob `~/.claude/projects/<slug>/memory/*.md`. Recent feedback is highest-signal.
- **Session context** — scan the current conversation for corrections, validation failures, requested features. Watch for *quiet* signals too: when the user accepted an unusual choice without pushback, that's a validated-pattern signal.
- **Recent git log** — `git log --since="2 days ago" --name-only .claude/` shows what `.claude/` files were touched.
- **Current file state** — read modified files to check if changes are internally consistent.

## Mapping findings to files

For each finding, identify 1-3 `.claude/` files as the target of the proposed change.

| Finding type | Typical target |
| ---- | ---- |
| Bug in generated rule or doc | the skill that generates it (`SKILL.md`) |
| Missing validation check | `skills/validate-claude-docs/SKILL.md` |
| Wrong artefact written on SKIP | `rules/artefact-skip-policy.md` + the generating skill |
| Missing skill feature | that skill's `SKILL.md` |
| Orchestration gap | the orchestrator skill |
| New pattern worth keeping | `docs/how-to-<topic>.md` (new or existing) |
| User preference | memory file (feedback type) + possibly a rule update |

Never propose changes to project source code — scope is `.claude/` only.

## Prioritization

Each proposal gets three numbers:

- **Impact** — `H` (benefits every future session), `M` (benefits common cases), `L` (edge case)
- **Cost** — minutes of work: 5 / 10 / 30 / 60+
- **Risk** — `low` (single file, style only), `medium` (cross-file, touches flow), `high` (touches core rules, many skills)

Rank by `Impact / Cost`. Ties broken by lower Risk. Show top 10 only.

## Output format

```text
╭─ /distill ──────────────────────────────────────────────────╮
│                                                             │
│  Scope          full / skills / rules / docs / bugs         │
│  Session span   <short description of what happened>        │
│  Memory         N entries read, M new candidates            │
│                                                             │
╰─────────────────────────────────────────────────────────────╯

  ┌─ Findings by category ────────────────────────────────────┐
  │                                                           │
  │  Bugs         N  (list titles, 1 line each)               │
  │  Gaps         N                                           │
  │  Patterns     N                                           │
  │  Feedback     N                                           │
  │                                                           │
  └───────────────────────────────────────────────────────────┘

  ┌─ Proposed improvements (ranked) ──────────────────────────┐
  │                                                           │
  │  # | I | Cost | Title                       | Target      │
  │  1 | H | 5m   | <title>                     | <file>      │
  │  2 | H | 10m  | <title>                     | <files>     │
  │  ...                                                      │
  │                                                           │
  └───────────────────────────────────────────────────────────┘

  ┌─ Recommended batches ─────────────────────────────────────┐
  │                                                           │
  │  Batch 1 (cheap wins):        items 1, 2, 3               │
  │  Batch 2 (automation):        items 4, 6                  │
  │  Batch 3 (documentation):     items 5, 7                  │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

After the table, offer to apply a batch. Do not apply anything silently — always ask.

## Completion marker

After rendering the final table, touch `.claude/state/last-distill`:

```bash
mkdir -p .claude/state && touch .claude/state/last-distill
```

The directory is gitignored. Touch unconditionally — even a "nothing new surfaced" result counts as a completed retrospective.

## What This Skill Does NOT Do

- Apply changes automatically — always propose first, user decides the batch
- Touch project source code — scope is `.claude/` only
- Replace `/validate-claude-docs` or `/sleep` — those enforce rules; `/distill` proposes new rules
- Invent problems — if nothing surfaced in the session, say so and exit cleanly
