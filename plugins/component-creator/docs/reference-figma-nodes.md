---
description: "Figma node types reference — all types, component-related detection logic, and Step 0.7 node classification for create-component flow."
---

# Figma Node Types — Reference

Source: https://developers.figma.com/docs/rest-api/file-node-types/

## Component-Related Types

| Type | Icon | Description | Key Fields |
| ---- | ---- | ---- | ---- |
| `COMPONENT_SET` | ◆◆ | Container for all variants of a component | `componentPropertyDefinitions`, `children` (variants) |
| `COMPONENT` | ◆ | Main component — standalone OR variant inside a set | `componentPropertyDefinitions`, `key`, parent type |
| `INSTANCE` | ◆ | Placed instance with overrides | `componentId` → source COMPONENT, `componentProperties` |

## Step 0.7 — Node Classification

Detect node type to decide how to proceed:

```
1. Call get_code_connect_suggestions(nodeId, fileKey) → get mainComponentNodeId

2. If mainComponentNodeId == nodeId:
     → node is COMPONENT_SET or standalone COMPONENT
     → PROCEED

3. If mainComponentNodeId != nodeId:
     a. Check if nodeId parent is COMPONENT_SET:
        → node is a VARIANT (◆ inside ◆◆)
        → REDIRECT: use mainComponentNodeId (the component set)

     b. Check if node type is INSTANCE:
        → node is an instance placed on canvas
        → DRILL: use componentId to find source COMPONENT
        → then check if source's parent is COMPONENT_SET
        → use COMPONENT_SET if exists, else use COMPONENT

4. If node type is FRAME / GROUP / VECTOR / TEXT / other:
     → STOP: "This is not a component node."
```

## All Node Types (25 total)

| Type | Category | Use in create-component |
| ---- | ---- | ---- |
| `COMPONENT_SET` | Component | ✅ Target — proceed |
| `COMPONENT` | Component | ✅ Proceed if standalone; redirect if variant |
| `INSTANCE` | Component | ⬆ Drill to source component set |
| `FRAME` | Container | ❌ Stop — not a component |
| `GROUP` | Container | ❌ Stop |
| `SECTION` | Container | ❌ Stop |
| `VECTOR` | Shape | ❌ Stop |
| `RECTANGLE` | Shape | ❌ Stop |
| `ELLIPSE` | Shape | ❌ Stop |
| `STAR` | Shape | ❌ Stop |
| `LINE` | Shape | ❌ Stop |
| `REGULAR_POLYGON` | Shape | ❌ Stop |
| `BOOLEAN_OPERATION` | Shape | ❌ Stop |
| `TEXT` | Typography | ❌ Stop |
| `TEXT_PATH` | Typography | ❌ Stop |
| `TABLE` | Collaboration | ❌ Stop |
| `TABLE_CELL` | Collaboration | ❌ Stop |
| `STICKY` | Collaboration | ❌ Stop |
| `SHAPE_WITH_TEXT` | Collaboration | ❌ Stop |
| `CONNECTOR` | Collaboration | ❌ Stop |
| `WASHI_TAPE` | Collaboration | ❌ Stop |
| `DOCUMENT` | Structure | ❌ Stop |
| `CANVAS` | Structure | ❌ Stop |
| `TRANSFORM_GROUP` | Container | ❌ Stop |
| `SLICE` | Utility | ❌ Stop |

## Key Fields by Type

### COMPONENT_SET
```json
{
  "type": "COMPONENT_SET",
  "componentPropertyDefinitions": { "type": {...}, "state": {...} },
  "children": [ /* COMPONENT variants */ ]
}
```

### COMPONENT (variant)
```json
{
  "type": "COMPONENT",
  "parent": { "type": "COMPONENT_SET", "id": "1:155" }
}
```

### COMPONENT (standalone — no COMPONENT_SET parent)
```json
{
  "type": "COMPONENT",
  "parent": { "type": "FRAME" }
}
```

### INSTANCE
```json
{
  "type": "INSTANCE",
  "componentId": "1:155",
  "componentProperties": { "type": "prim", "state": "Default" }
}
```
→ Use `componentId` to find source, then check source's parent for COMPONENT_SET.

## Stop Messages by Type

```
FRAME/GROUP/SECTION   → "This is a frame or group, not a component.
                         Select a component (◆) or component set (◆◆) in Figma."
INSTANCE              → Auto-drill to source — do not stop.
VECTOR/TEXT/shape     → "This is a shape/text layer. Select a component node."
```
