# Prompt Engineering Rules

## Overview

These rules enforce standards for writing prompt templates that fit structured prompt library conventions. Prompts must follow canonical structure, use appropriate frameworks, and include worked examples.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message.

### Blocking Finding Behavior

A **blocking finding** means:
1. The finding MUST be listed under a "Prompt Engineering Findings" section
2. The stage MUST NOT present "Continue to Next Stage" until resolved
3. Non-compliance with any applicable PROMPT rule is a blocking finding

---

## Rule PROMPT-01: Framework Selection

**Rule**: Every prompt MUST designate exactly one framework based on its purpose:

| Framework | Best For | Selection Trigger |
|---|---|---|
| CO-STAR | General frontline/back-office tasks | Default if none others fit |
| Chain-of-Thought | Analytical reasoning, step-by-step | Needs thinking → answer flow |
| BAB | Customer service recovery | Before → After → Bridge pattern |
| PCTF | Leadership briefings, persona-driven | Persona → Context → Task → Format |
| Agentic | Complex multi-step workflows | Planner → Retriever → Solver → Critic |
| Few-Shot | Pattern-matching, classification | Examples teach the pattern |

Selection order: Agentic? → BAB? → Chain-of-Thought? → PCTF? → Few-Shot? → CO-STAR.

**Verification**:
- Every prompt specifies exactly one framework
- Framework choice matches the prompt's purpose
- Selection rationale is implicit from the use case

---

## Rule PROMPT-02: Canonical Structure

**Rule**: Every prompt template MUST include these 11 parts in order:
1. Title (H1 with department emoji)
2. Intro paragraph
3. Quick-Start Callout (time estimate)
4. Metadata table (Prompt ID, Framework, Tier, Target Roles)
5. System Message
6. User Message Template (with `{{placeholder}}` variables)
7. Context, Constraints, Tone & Style
8. Output Format
9. Ready-to-Copy Prompt
10. Example (fully worked)
11. Compliance Notes

**Verification**:
- All 11 sections present in correct order
- No sections skipped without documented reason
- Metadata table fully populated

---

## Rule PROMPT-03: Prompt ID Convention

**Rule**: Prompt IDs MUST follow the format `[DEPT]-[TIER]-[SEQ]`:
- DEPT: 2-4 uppercase letters from department registry
- TIER: `FL` (Tier 1 Ready-to-Use), `GU` (Tier 2 Guided), `PU` (Tier 3 Power User)
- SEQ: 3-digit zero-padded sequence

File naming: `[PROMPT_ID]-[kebab-case-title].md`

**Verification**:
- ID follows the format pattern exactly
- Department code exists in the registry
- Tier code matches the audience level
- File name matches the ID

---

## Rule PROMPT-04: Placeholder Syntax

**Rule**: All variable placeholders MUST use `{{descriptive_name}}` with snake_case. Every placeholder MUST have a reference table entry with description and example value.

**Verification**:
- All placeholders use `{{snake_case}}` syntax
- Reference table lists every placeholder
- Each entry has description and example value
- No undefined placeholders in the template

---

## Rule PROMPT-05: Worked Example Required

**Rule**: Every prompt template MUST include at least one fully worked example showing:
- Realistic filled-in input (all placeholders replaced)
- Expected output matching the output format specification

**Verification**:
- At least one complete example present
- All placeholders filled with realistic values
- Output matches the specified format
- Example is domain-relevant

---

## Rule PROMPT-06: Tool Agnosticism

**Rule**: All prompts MUST be tool-agnostic — they should work with Claude, ChatGPT, Kiro, Amazon Q, or any compatible AI tool. No tool-specific syntax unless clearly marked as optional.

**Verification**:
- No tool-specific features required for the prompt to function
- XML tags noted as working natively in Claude/Kiro but serving as separators elsewhere
- No vendor-locked functionality

---

## Enforcement Integration

These rules apply primarily during:
- **Code Generation** — when generating prompt templates as project artifacts
- **Build and Test** — prompt template validation
