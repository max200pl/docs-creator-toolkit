---
description: "Token synchronization rules for Phase 1 — how to compare Figma variables against local token file and resolve conflicts."
---

# Token Sync — Reference

## Detection

Call `mcp__figma__get_variable_defs(nodeId, fileKey)` in Phase 1 parallel with registry check and Figma context. Compare against token file loaded from `token_file:` path in `frontend-design-system.md` frontmatter.

Normalize all color values to hex8 before comparison (`rgba(78,78,255,1)` → `#4e4effff`).

## Conflict Resolution

| Situation | Action |
| ---- | ---- |
| Same name + same value | Exact match — use existing token, no action |
| Same name + different value | Designer updated Figma → update value in token file, flag to user |
| Different name + same value | Coder renamed locally → flag rename conflict; use Figma name as canonical, suggest updating local name |
| New name + new value | Genuinely new token → add to token file with semantic naming `--{category}-{variant}` |

Show all conflicts in Phase 1 report **before writing any code**. User confirms or overrides.

## EC11 — No Figma Variables

`get_variable_defs` returns empty — component uses raw values only. Prompt user:

> "No Figma Variables found — this component uses raw values (`#3B82F6`, `14px`, etc.).
> Options:
> 1. Extract raw values as new tokens — starts building your token system
> 2. Write raw values directly with `/* unmapped-token */` comment — faster, no token reuse"

If option 1 → generate semantic names from Figma layer context, add to token file, use vars in component.
If option 2 → write raw values with `/* unmapped-token: #3B82F6 */` inline.

## Token Naming Convention

```
--{category}-{variant}

Examples:
  --color-btn-border        (category: color, variant: btn-border)
  --color-btn-fill-hover    (category: color, variant: btn-fill-hover)
  --radius-md               (category: radius, variant: md)
  --space-sm                (category: space, variant: sm)
```

Derive category from Figma variable group name. Derive variant from Figma variable name in kebab-case.
