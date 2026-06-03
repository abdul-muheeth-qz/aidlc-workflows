# Hook Authoring — Opt-In

**Extension**: Kiro Hook Authoring Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Hook Authoring Extension
Should Kiro hook authoring standards be enforced for this project?

A) Yes — enforce all HOOK rules as blocking constraints (recommended for projects that use Kiro hooks for automation, compliance gates, or developer workflows)
B) Partial — enforce HOOK rules only for preToolUse compliance gates (suitable for projects that only use hooks for access control)
C) No — skip all HOOK rules (suitable for projects that do not use Kiro hooks or use a different automation system)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
