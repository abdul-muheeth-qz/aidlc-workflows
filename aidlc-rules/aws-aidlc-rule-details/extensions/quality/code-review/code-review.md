# Code Review Conformance Rules

## Overview

These rules enforce code quality standards that must pass before any feature is marked complete. They define critical violations (blocking) and warnings (must be addressed or acknowledged).

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message.

### Blocking Finding Behavior

A **blocking finding** means:
1. The finding MUST be listed under a "Code Review Findings" section
2. The stage MUST NOT present "Continue to Next Stage" until all critical violations are resolved
3. Warnings must be addressed or explicitly acknowledged with justification

---

## Rule REVIEW-01: No Mock Data in Production

**Rule**: Production code MUST NOT contain mock, dummy, fake, or sample data used as actual data sources.

Detected patterns:
- `TODO.*mock`, `FIXME.*mock`, `HACK.*mock` comments
- Variables named `mockData`, `dummyData`, `fakeData`, `sampleData` serving as data sources
- Hardcoded JSON responses substituting for real API calls
- Static arrays pretending to be API responses

**Verification**:
- No mock/fake/dummy data variables used as production data sources
- No hardcoded responses substituting for API calls
- TODO/FIXME comments referencing mocks are resolved

---

## Rule REVIEW-02: No Stub Implementations

**Rule**: Production code MUST NOT contain stub or placeholder implementations.

Detected patterns:
- `// TODO: implement`, `// FIXME: implement` placeholders
- Functions returning hardcoded values instead of computed results
- Empty function bodies or `pass` statements as placeholders

**Verification**:
- No placeholder comments indicating unfinished implementation
- No functions returning hardcoded values where computation is expected
- No empty function bodies in production code

---

## Rule REVIEW-03: Complete Error Handling

**Rule**: All error paths MUST be properly handled.

Detected patterns:
- Empty catch blocks: `catch (e) {}`
- `console.log(error)` as the only error handling
- API routes without try/catch or proper HTTP status codes
- Unhandled promise rejections

**Verification**:
- No empty catch blocks
- Error handling produces meaningful responses or recovery actions
- All API routes return appropriate HTTP status codes on error
- No unhandled promise rejections

---

## Rule REVIEW-04: No Security Red Flags

**Rule**: Code MUST NOT contain common security vulnerabilities.

Detected patterns:
- Hardcoded secrets, API keys, or passwords in source code
- `eval()` or `exec()` with user input
- SQL string concatenation (must use parameterized queries)
- `dangerouslySetInnerHTML` without sanitization
- Disabled or overly permissive CORS (`Access-Control-Allow-Origin: *` on auth endpoints)

**Verification**:
- No secrets or credentials in source files
- No dynamic code execution with user input
- All database queries use parameterized statements
- CORS is restrictive on authenticated endpoints

---

## Rule REVIEW-05: Destructive Operation Safety

**Rule**: Code MUST NOT execute destructive operations (database drops, bulk deletes, infrastructure destruction) without explicit confirmation mechanisms.

**Verification**:
- Destructive operations have confirmation gates
- No automated bulk delete/drop without safeguards
- Infrastructure-destroying commands require human confirmation

---

## Rule REVIEW-06: Code Complexity Thresholds (Warning Level)

**Rule**: Code SHOULD stay within these thresholds. Exceeding them is a warning (not blocking) that must be addressed or justified:

| Pattern | Threshold | Action |
|---|---|---|
| Function length | > 50 lines | Split into smaller functions |
| File length | > 300 lines | Decompose into modules |
| Nesting depth | > 3 levels | Use early returns or extract |
| TypeScript `any` | Any usage | Use `unknown` + type guards |
| Non-null assertions `!` | Any usage | Handle nulls properly |
| Business logic in route handlers | Any | Move to service layer |
| Direct DB calls in UI components | Any | Use hooks + services |
| Prop drilling 3+ levels | Any | Use Context or state management |

**Verification**:
- Functions stay under 50 lines (or have documented justification)
- Files stay under 300 lines (or have documented justification)
- No TypeScript `any` without documented reason
- Business logic separated from request handling

---

## Enforcement Integration

These rules apply primarily during:
- **Code Generation** — all rules enforced during implementation
- **Build and Test** — final conformance check before completion
