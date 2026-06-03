# Skill Creator Rules

## Overview

These rules enforce standards for building reusable agent skills that follow the Agent Skills standard. Skills must follow a phased authoring workflow, include proper schema, and contain worked examples.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message.

### Blocking Finding Behavior

A **blocking finding** means:
1. The finding MUST be listed under a "Skill Authoring Findings" section
2. The stage MUST NOT present "Continue to Next Stage" until resolved
3. Non-compliance with any applicable SKILL rule is a blocking finding

---

## Rule SKILL-01: Phased Authoring Workflow

**Rule**: Skill creation MUST follow six sequential phases:
1. **Capture Intent** — what, who, which tools, which category
2. **Interview for Details** — core rules, domain terms, inputs/outputs, edge cases
3. **Draft SKILL.md** — generate using standard structure
4. **Create Test Cases** — happy path, edge case, refusal scenario
5. **Iterate** — present draft, collect feedback, revise
6. **Finalize** — write file, create subdirectories, update index

**Verification**:
- Intent is captured before drafting begins
- Details are gathered through interview
- Test cases exist before finalization
- User feedback incorporated before final version

---

## Rule SKILL-02: SKILL.md Schema

**Rule**: Every SKILL.md MUST have:
- YAML frontmatter with `name` (string, required) and `description` (string, required)
- Markdown body with at minimum: Rules section and Examples section

```yaml
---
name: skill-name
description: One-line description of what the skill does
---
```

**Verification**:
- Frontmatter is valid YAML with both required fields
- `name` uses kebab-case
- `description` is concise (one line)
- Body contains Rules and Examples sections

---

## Rule SKILL-03: Concrete Numbered Rules

**Rule**: The Rules section MUST contain 3–8 concrete, actionable behavioral rules. Rules must be specific enough to test — not vague guidance.

**Verification**:
- Between 3 and 8 rules defined
- Each rule describes a specific behavior (not vague advice)
- Rules are numbered for easy reference
- Each rule is testable (clear pass/fail criteria)

---

## Rule SKILL-04: Worked Examples Required

**Rule**: Every skill MUST include at least one fully worked example with:
- Realistic, domain-relevant input
- Expected output matching the skill's rules
- Clear demonstration of the skill's value

**Verification**:
- At least one complete example present
- Input is realistic (not trivial placeholder)
- Output demonstrates rule application
- Example is self-contained and understandable

---

## Rule SKILL-05: Output Location and Naming

**Rule**: Skills MUST be placed in `skills-library/{skill-name}/SKILL.md` with:
- Kebab-case directory name
- Optional subdirectories: `references/`, `scripts/`, `assets/`
- Index update reminder after creation

**Verification**:
- Directory uses kebab-case naming
- SKILL.md is the primary file
- Supporting files in appropriate subdirectories
- No skills placed in `.kiro/skills/` (that's for consumption, not authoring)

---

## Rule SKILL-06: Single Concern

**Rule**: Each skill MUST address one concern. Do not combine multiple unrelated capabilities into a single skill. If scope expands, split into multiple skills.

**Verification**:
- Skill has a clear, single purpose
- Rules all relate to the same domain
- No unrelated behaviors bundled together
- Skill name accurately describes its sole concern

---

## Enforcement Integration

These rules apply primarily during:
- **Code Generation** — when creating skill files as project artifacts
- **Build and Test** — skill schema and content validation
