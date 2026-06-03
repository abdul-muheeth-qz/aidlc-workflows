# Skill Creator — Opt-In

**Extension**: Agent Skill Authoring Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Skill Creator Extension
Should agent skill authoring standards be enforced for this project?

A) Yes — enforce all SKILL rules as blocking constraints (recommended for projects building reusable agent skills, skill libraries, or AI workflow tooling)
B) Partial — enforce SKILL rules only for SKILL.md schema validation (suitable for projects with occasional skill authoring needs)
C) No — skip all SKILL rules (suitable for projects that do not involve creating agent skills)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
