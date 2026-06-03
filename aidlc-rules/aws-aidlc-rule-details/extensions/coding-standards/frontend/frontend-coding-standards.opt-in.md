# Frontend Coding Standards — Opt-In

**Extension**: Frontend Coding Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Frontend Coding Standards Extension
Should frontend coding standards be enforced for this project?

A) Yes — enforce all FRONTEND rules as blocking constraints (recommended for production-grade web applications with React, TypeScript, or similar frameworks)
B) Partial — enforce FRONTEND rules only for new components and pages; existing code follows its own patterns (suitable for brownfield frontend projects)
C) No — skip all FRONTEND rules (suitable for backend-only projects, CLIs, or projects with separate frontend standards)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
