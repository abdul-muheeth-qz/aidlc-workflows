# Backend Coding Standards — Opt-In

**Extension**: Backend Coding Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Backend Coding Standards Extension
Should backend coding standards be enforced for this project?

A) Yes — enforce all BACKEND rules as blocking constraints (recommended for production-grade server-side applications and APIs)
B) Partial — enforce BACKEND rules only for new code; existing code follows its own patterns (suitable for brownfield projects with established conventions)
C) No — skip all BACKEND rules (suitable for frontend-only projects, prototypes, or projects with separate backend standards)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
