# Hook Authoring Rules

## Overview

These rules enforce standards for writing Kiro hooks — automation triggered by IDE events. Hooks must follow the correct schema, avoid anti-patterns, and be properly structured for their event type.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message.

### Blocking Finding Behavior

A **blocking finding** means:
1. The finding MUST be listed under a "Hook Authoring Findings" section
2. The stage MUST NOT present "Continue to Next Stage" until resolved
3. Non-compliance with any applicable HOOK rule is a blocking finding

---

## Rule HOOK-01: Schema Compliance

**Rule**: Every hook file MUST follow the required JSON schema:

```json
{
  "name": "string (required)",
  "version": "string (required)",
  "description": "string (optional)",
  "when": {
    "type": "eventType (required)",
    "patterns": ["array (required for file events)"],
    "toolTypes": ["array (required for tool events)"]
  },
  "then": {
    "type": "askAgent or runCommand (required)",
    "prompt": "string (required for askAgent)",
    "command": "string (required for runCommand)"
  }
}
```

**Verification**:
- `name` and `version` fields are present
- `when.type` is a valid event type
- File events have `patterns` array
- Tool events have `toolTypes` array
- `then.type` matches either `askAgent` or `runCommand`
- Required fields for the action type are present

---

## Rule HOOK-02: Event Type Correctness

**Rule**: Hooks MUST use the correct event type for their purpose:

| Event | Requires | Use For |
|---|---|---|
| `fileEdited` | `patterns` | Lint on save, format on save |
| `fileCreated` | `patterns` | Template generation, scaffolding |
| `fileDeleted` | `patterns` | Cleanup tasks |
| `userTriggered` | Nothing extra | On-demand workflows |
| `promptSubmit` | Nothing extra | Per-message checks (lightweight only) |
| `preToolUse` | `toolTypes` | Compliance gates, access control |
| `postToolUse` | `toolTypes` | Post-action verification |
| `preTaskExecution` | Nothing extra | Pre-task preparation |
| `postTaskExecution` | Nothing extra | Post-task verification |

**Verification**:
- Event type matches the hook's intended purpose
- Required fields for the event type are present
- No mismatched event/action combinations

---

## Rule HOOK-03: No Circular Dependencies

**Rule**: Hooks MUST NOT create circular dependencies. A preToolUse hook must not require a tool that would trigger the same hook again.

**Verification**:
- PreToolUse hooks do not require the same tool category they gate
- Hook chains are acyclic
- Circular patterns are documented and handled with skip logic

---

## Rule HOOK-04: Lightweight promptSubmit Hooks

**Rule**: Hooks on `promptSubmit` MUST be lightweight because they run on every message. Heavy processing must use `userTriggered` instead.

**Verification**:
- promptSubmit hook prompts are concise (< 200 words)
- No file scanning or heavy computation in promptSubmit hooks
- Heavy workflows use userTriggered event type

---

## Rule HOOK-05: Self-Contained Prompts

**Rule**: Hook prompts MUST be self-contained with critical rules inlined. References to external files are allowed but critical rules must not depend solely on external file availability.

**Verification**:
- Key rules are stated directly in the prompt
- External file references are supplementary, not sole source of truth
- Prompt is actionable even if referenced files are unavailable

---

## Rule HOOK-06: Access Denial Respect

**Rule**: When a preToolUse hook denies access, the tool call MUST NOT be retried. Denial is final.

**Verification**:
- Hook prompts clearly state denial criteria
- No retry logic for denied operations
- Denied operations are logged appropriately

---

## Enforcement Integration

These rules apply primarily during:
- **Code Generation** — when hooks are created as part of project setup
- **Build and Test** — hook schema validation
