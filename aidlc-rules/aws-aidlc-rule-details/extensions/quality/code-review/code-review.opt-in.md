# Code Review — Opt-In

**Extension**: Code Review Conformance

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Code Review Extension
Should code review conformance rules be enforced for this project?

A) Yes — enforce all REVIEW rules as blocking constraints (recommended for production applications where code quality gates are required)
B) Partial — enforce only critical violations (mock data, stubs, security flags) but treat warnings as advisory (suitable for early-stage projects)
C) No — skip all REVIEW rules (suitable for prototypes, spikes, or throwaway code)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
