# CCP Next Platform Tooling Standards — Opt-In

**Extension**: CCP Next Platform Tooling Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: CCP Next Platform Tooling Standards Extension
Should CCP Next platform tooling standards be enforced for this project?

These rules enforce: ccp-next-general-resources package usage with pinned versions, standard Makefile targets (setup, plan, deploy, destroy, checkov-dynamic-scan, ccp-iac-scan), environment/namespace structure with environments.yml, and the standard dev/qa/prod tier deployment pattern for projects using CCP Next deployment tooling.

A) Yes — enforce all CCP-NEXT-PLATFORM rules as blocking constraints (recommended for projects using ccp-next-general-resources and the standard Makefile-based deployment workflow)

B) No — skip all CCP-NEXT-PLATFORM rules (suitable for projects not using CCP Next deployment tooling or custom deployment frameworks)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
