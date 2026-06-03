# Steering File Design Rules

## Overview

These rules enforce standards for writing effective Kiro steering files using the lean pointer pattern. Steering files must be concise, properly configured, and separated from detailed reference content.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message.

### Blocking Finding Behavior

A **blocking finding** means:
1. The finding MUST be listed under a "Steering Design Findings" section
2. The stage MUST NOT present "Continue to Next Stage" until resolved
3. Non-compliance with any applicable STEERING rule is a blocking finding

---

## Rule STEERING-01: Behavioral Rules Only

**Rule**: Steering files MUST define behavioral rules for the AI — they are NOT documentation for humans. Content must be actionable instructions that change AI behavior.

**Verification**:
- File contains behavioral instructions ("always do X", "never do Y")
- No purely informational/documentary content
- Content is addressable to the AI, not a human reader

---

## Rule STEERING-02: Size Limit with Pointer Pattern

**Rule**: Steering files MUST stay under ~4KB. If content exceeds this, it MUST be split into:
- A lean steering file (~2-4KB, always loaded) with behavioral rules
- A knowledge guide (any size, loaded on-demand) with full reference material via `#[[file:path]]` pointer

**Verification**:
- No steering file exceeds 4KB
- Large content is split with pointer pattern
- Pointer references valid knowledge guide files
- Critical rules are in the steering file (not only in the guide)

---

## Rule STEERING-03: Front-Matter Configuration

**Rule**: Every steering file MUST have front-matter with correct inclusion type:

```yaml
---
inclusion: always    # Loaded on every interaction
---
```
or
```yaml
---
inclusion: manual    # Loaded only when user invokes via #filename
---
```
or
```yaml
---
inclusion: fileMatch
fileMatchPattern: '*.ts'    # Loaded when matching files in context
---
```

**Verification**:
- Front-matter present with `inclusion` field
- Inclusion type matches the file's purpose
- `fileMatchPattern` present when `inclusion: fileMatch`
- No missing front-matter (which defaults to always-loaded)

---

## Rule STEERING-04: Correct Inclusion Type Usage

**Rule**: Inclusion types MUST match their purpose:
- `always` — behavioral rules, project context, coding standards, conformance rules
- `manual` — heavy generation tasks, reference guides needed only on demand
- `fileMatch` — language-specific rules that apply only with certain file types

**Verification**:
- Heavy generation content uses `manual`, not `always`
- Language-specific rules use `fileMatch` with appropriate patterns
- General behavioral rules use `always`
- No context budget wasted on rarely-needed content

---

## Rule STEERING-05: No Content Duplication

**Rule**: Content MUST NOT be duplicated between steering files and knowledge guides. Steering files point to guides — they do not repeat guide content.

**Verification**:
- No repeated paragraphs between steering and guide files
- Steering contains rules; guide contains details/examples
- Pointer references the guide for detailed content
- Each piece of information exists in exactly one place

---

## Rule STEERING-06: Standard Anatomy

**Rule**: Steering files MUST follow this structure:
1. Front-matter (inclusion configuration)
2. Title (H1)
3. Purpose (1-2 sentences)
4. Behavior Rules (numbered list)
5. Quick Reference (tables or short lists)
6. Full Guide pointer (if applicable)

**Verification**:
- All sections present and in order
- Purpose is concise
- Rules are numbered and concrete
- Quick reference provides at-a-glance lookup

---

## Enforcement Integration

These rules apply primarily during:
- **Code Generation** — when creating steering files as project artifacts
- **Build and Test** — steering file schema and content validation
