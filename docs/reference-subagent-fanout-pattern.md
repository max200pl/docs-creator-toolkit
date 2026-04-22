# Subagent Fan-out Pattern

> Audience: toolkit maintainers AND plugin users writing or reviewing orchestrator skills that process N independent units in parallel.
> Worked example: [agents/module-documenter.md](../agents/module-documenter.md) — the canonical subagent used by `/init-project` for per-module fan-out.
> See also: Two-Claude Workflow (toolkit-internal pattern about Designer/Tester split on TWO terminals — different topic; lives in `.claude/docs/two-claude-workflow.md` in the toolkit dev repo).

## The Pattern

An **orchestrator skill** that must process `N` independent units (modules, frontends, tickets, files, …) does **not** loop over them inline. Instead, it fans out to `N` parallel subagents — one per unit — each returning a structured result. The orchestrator collects results and proceeds.

```text
Without fan-out (inline loop):

Main Claude session
├─ Unit 1: Read files → analyze → generate → write   ← all in main context
├─ Unit 2: Read files → analyze → generate → write
├─ …
└─ Unit N: Read files → analyze → generate → write

Total time:     Σ per-unit time (sequential)
Main context:   fills with N × per-unit reads (bloats fast)

With fan-out:

Main Claude session (orchestrator)
│
├─ Subagent 1 ─┐ (parallel) reads Unit 1 in its own context
├─ Subagent 2 ─┤           reads Unit 2 in its own context
├─ …           │
└─ Subagent N ─┘           reads Unit N in its own context
       │
       ▼
Main Claude session collects N compact structured results
→ performs final batch of writes / aggregations

Total time:     max(per-unit time) / concurrency_factor (roughly)
Main context:   N × compact-result size (stays small)
```

Two wins, both large on real projects: **wall-clock** (parallelism) and **main-context** (unit-level deep reads stay out of the main session).

## When to Fan Out

| Heuristic | Threshold | Example |
| ---- | ---- | ---- |
| Unit count | `≥ 10` | 21 modules, 15 tickets, 30 source files |
| OR per-unit context cost | `≥ 5k tokens` | deep file reads per unit, even with `N=3` |
| AND units are independent | every unit | no unit needs output of another unit |
| AND unit-level work is a bottleneck | `> 30%` of total time | confirmed by a baseline measurement if possible |

If all of (count OR cost) AND (independent) AND (bottleneck) hold — fan out. If any is missing — keep inline.

**Independence is the hard constraint.** If Unit B needs Unit A's computed output, you cannot naïvely fan out — the dependency forces sequence. In that case, the fan-out point moves up one level (fan out over independent groups, serialize within each group), or the two steps fuse into one subagent per unit (see "Combine scan + generate" below).

## When NOT to Fan Out

- `N < 10` AND per-unit context is small — loop overhead and subagent-invocation overhead dominate. Just do it inline.
- Units need shared stateful computation (e.g., running aggregates, graph traversal across units) — subagents can't share state, and rebuilding it per-call wastes tokens.
- The user's next step after this phase depends on reading the full per-unit output live — fan-out means all outputs land at once, not progressively. UX trade-off.

## Deciding Subagent Scope

Given independent units and a bottleneck, you still choose *how much* work one subagent does. Three common shapes:

### Combine (do more per subagent) — usually right

**One subagent does the full per-unit workflow end-to-end**, returns both its summary for the aggregate table and the final artefact.

- ✅ Subagent-invocation overhead paid once per unit
- ✅ Subagent's loaded-file context is reused within the subagent for both analysis and generation
- ✅ One fan-out round
- ✅ Clean fan-in — one result per unit
- Used by: `module-documenter` (scan + generate CLAUDE.md body)

### Split (two subagent types, two fan-out rounds) — rare

Stage 1: N scan-subagents analyze the unit.
Stage 2: N generate-subagents consume stage-1 output.

- ✅ Each subagent is simpler, single-responsibility
- ✅ Stage-1 output can be reused elsewhere
- ❌ Subagent context is **isolated** — stage-2 cannot inherit stage-1's loaded files. Re-reads.
- ❌ 2N invocations, 2x overhead
- ❌ Two rounds serialize at the fan-in points
- Use when: stage-1 output has multiple consumers, or stage-2 is optional

### Explode (atomic-op subagents) — almost never

One subagent per primitive operation (read, parse, write, …).

- ❌ Overhead >> work
- ❌ Useless for practical tasks
- Treat as a smell — if you're tempted, rethink the unit decomposition

**Default choice: Combine.** Pick Split only when you have a concrete reason the benefits outweigh the 2x overhead.

## Fan-in Contract (Return-Shape)

A subagent's reply is parsed by the orchestrator. Design the reply format so parsing is trivial and unambiguous.

**Recommended structure:**

```markdown
## Summary Row

```yaml
<structured key-value data, parseable as YAML>
```

## <Artefact Name>

<free-form content — the actual deliverable, no wrapping code fence>
```

**Why this shape:**

- **YAML first block** — orchestrator extracts aggregated data (counts, category, summary string) for a collated table, without reading the artefact body.
- **Free-form second block** — subagent writes rich content (markdown, code, prose) that the orchestrator consumes verbatim (usually a file body).
- **Parse by heading** — `##` section headings are the contract. No JSON, no delimiters to escape.

**Avoid:**

- Raw JSON output — LLMs drop trailing commas, escape strings inconsistently. Painful to parse reliably.
- Free-form output with no structure — the orchestrator cannot aggregate without an LLM parse step of its own.
- Multiple artefacts mixed into one section — split them: `## Artefact A`, `## Artefact B`.

## Short-Circuit for Trivial Units

The orchestrator has already filtered trivial units before fan-out, but the subagent may still discover the unit is trivial on closer read (e.g., a module that seemed large but is auto-generated). Return a sentinel value so the orchestrator knows to skip final writes.

`module-documenter` uses the literal string `SKIP` as the `## CLAUDE.md Content` body. Orchestrator sees `SKIP`, drops that module's write step, but still records it in the summary table with `trivial: true`.

Define a sentinel in the subagent spec. Don't leave trivial handling to ambiguous empty output.

## Passing Context Into Subagents

Subagents start with **zero prior context** — they don't see the main session's transcript. They only know what the invocation prompt tells them. This is the discipline that makes fan-out work (main context stays small) — but it means the orchestrator must explicitly hand over everything the subagent needs.

**Minimum invocation-prompt fields for any unit-processor subagent:**

| Field | Purpose |
| ---- | ---- |
| `<unit>_path` | What to work on |
| `project_root` | Anchor for relative paths in output |
| Project-level context already detected | Stack, conventions, hub identity, layer hints — so the subagent doesn't re-derive them |
| Style rules reference | Path to `rules/markdown-style.md` et al. — subagent reads them in its own context to enforce size caps, formatting |
| Return-shape reminder | A brief reminder the subagent must produce `## Summary Row` + `## <Artefact>` sections |

Resist the temptation to let the subagent re-do detection already completed by earlier phases. Detection work belongs in the orchestrator.

## Error Handling

Subagents can fail. Unit U's failure must not abort the whole fan-out.

**Required orchestrator behavior:**

- If a subagent returns unparsable output or an error — log the failure (unit name + short error) in the run report's `Notes` section and continue with the remaining units.
- If a subagent returns successfully but the body is malformed (e.g., unclosed fence, missing required section) — same: log, skip that unit's write, continue.
- Never silently drop a unit. If U's output isn't used, U must appear in the report with a reason.

**Do NOT retry automatically** in MVP. Retry logic is a separate hardening step — the first implementation should surface failures, not paper over them.

## Concurrency Budget

Claude Code has a practical concurrency limit for parallel subagent invocations. The exact number is environment-dependent; treat **5–8 concurrent** as a safe working assumption. With `N = 21` units and budget 5, you get ~4 fan-out rounds internally — the invocation appears as one `par` block in sequence diagrams, but real execution queues through the budget.

This matters for wall-clock projections:

- Effective speedup = `N / rounds` = approx `concurrency_budget` for `N ≥ budget`
- For small N (say N=3 with budget 5), speedup = N — parallel wins nothing over sequential since overhead dominates, reinforcing the "don't fan out when N is small" rule above.

If you need higher concurrency (say 20 units, want 10x speedup), the pattern still works but the underlying runtime caps your speedup. Budgeting 3-5x in projections is realistic.

## Sequence-Diagram Conventions

When documenting fan-out in a `.mmd` sequence diagram:

- **Add a participant** for the subagent pool with a name like `<SubagentName> as <name><br/>subagent (fan-out)`.
- **Use the `par` block** (parallel) — not `loop` — to show concurrency. The block body contains the single-unit interaction; the block itself says "for each unit, in parallel".
- **Show return-shape** briefly inside the arrow label — e.g., `{summary_row, claude_md_content}`.
- **Add a Note right of** the subagent participant describing what happens inside the subagent's context — so readers see the main session's context stays small.

Example (excerpt):

```text
par For each non-trivial module (parallel fan-out)
    Claude->>MD: Invoke with<br/>{module_path, project_root,<br/>stack_summary, conventions_summary}
    Note right of MD: Subagent reads public interface,<br/>deps, reverse-deps, patterns —<br/>in its OWN context
    MD-->>Claude: {summary_row, claude_md_content}
end
```

## Writing the Orchestrator Instructions in SKILL.md

The SKILL.md phase that fans out must:

1. **Reference the subagent spec** — pointer to `agents/<subagent>.md` as the source of truth for the contract. Do NOT duplicate the subagent's input/output spec in SKILL.md; that doubles the maintenance burden and guarantees drift.
2. **State the filter that produces the unit list** — e.g., `non_trivial_modules`, `frontend_roots`, `open_tickets`.
3. **Specify the fields the invocation prompt MUST include** — the orchestrator is responsible for gathering and passing these.
4. **Describe fan-in parsing and the sentinel values** — how results are aggregated, how `SKIP` (or equivalent) is handled.
5. **Describe error handling** — log-and-continue, not abort.
6. **Reference the baseline/projected metrics** briefly — gives future readers the "why" for choosing fan-out here and not inline.

Keep it ~40-60 lines. The heavy lifting is in the subagent spec.

## Pitfalls

| Pitfall | Symptom | Fix |
| ---- | ---- | ---- |
| Subagent re-derives detection done in an earlier phase | Wall-clock per subagent grows, total speedup vanishes | Pass detected values in the invocation prompt; subagent trusts them |
| Return shape drifts from what the orchestrator parses | Orchestrator crashes or silently skips units on some runs | Add a "return shape contract" checkbox to the subagent spec; rules review checks it |
| Orchestrator collects raw file content for every unit in main context | Main context bloats — the exact thing fan-out was supposed to prevent | Return summary + artefact content only; subagent keeps raw reads in its own context |
| Inline `Read` / `Grep` calls still present in the orchestrator phase | Fan-out is cosmetic; real work still sequential | Audit the SKILL.md phase for `Read`/`Grep` calls — they should be zero in the fan-out phase, all moved into the subagent |
| Retrying on failure without a cap | Runaway subagent invocations | MVP = no retry. Harden later if data shows intermittent failures |
| Treating fan-out as mandatory everywhere | Tiny-project overhead balloons | Gate fan-out with the "when to fan out" heuristics; small projects loop inline |

## Applicability Beyond `/init-project`

The same pattern applies to any orchestrator whose dominant cost is per-unit work on N independent units. Planned or likely fan-out points:

| Skill | Unit | Subagent (proposed) | Return shape |
| ---- | ---- | ---- | ---- |
| `/init-project` [done in M2] | module | `module-documenter` | `{summary_row, claude_md_content}` |
| `/update-docs` Detect-drift [candidate, post-M2] | module | `module-drift-scanner` | `{drift_items, severity_bucket}` |
| `/analyze-frontend` [M8] | frontend root / layer | `frontend-layer-analyzer` | `{layer_summary, findings_body}` |
| `/analyze-frontend` sub-analyses [M8] | per-layer deep-dive | `design-system-scanner`, `component-inventory`, `data-flow-mapper` | `{layer_summary, findings_body}` — same shape, specialized content |

Keep the structural conventions uniform across subagents: clear input contract, `## Summary Row` + `## <Artefact>` split, size budgets, trivial-case sentinel. Familiarity across subagents reduces cognitive load for maintainers.

## Checklist Before Shipping a Fan-out Phase

- [ ] A subagent spec exists at `agents/<name>.md` with input contract, step-order, return shape
- [ ] Return shape uses `## Summary Row` YAML + `## <Artefact>` markdown
- [ ] Sentinel value defined for trivial / skip cases
- [ ] Orchestrator SKILL.md references the subagent spec — does NOT duplicate it
- [ ] Orchestrator invocation prompt lists all required input fields
- [ ] Fan-in parsing described (how to aggregate, how to handle sentinel)
- [ ] Error handling = log-and-continue, not abort
- [ ] Sequence diagram uses `par` block and adds the subagent participant
- [ ] `skill-architect` agent reviewed (or will review) the new phase against `rules/skill-architect` fan-out rule
- [ ] A baseline (or at least a projection) motivates why fan-out here
- [ ] First spot-check run validates the contract on a real target project
