# Steering File Design — Opt-In

**Extension**: Kiro Steering File Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Steering File Design Extension
Should Kiro steering file design standards be enforced for this project?

A) Yes — enforce all STEERING rules as blocking constraints (recommended for projects that use Kiro steering files for AI behavioral configuration)
B) Partial — enforce STEERING rules only for inclusion type correctness and size limits (suitable for projects with a few steering files that need consistency)
C) No — skip all STEERING rules (suitable for projects that do not use Kiro or steering file patterns)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
