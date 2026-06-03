# IaC Deployment Standards — Opt-In

**Extension**: IaC Deployment Standards (CCP Next Terraform)

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Infrastructure as Code — Deployment Standards Extension
Should CCP Next Terraform deployment standards be enforced for this project?

These rules enforce: labels module usage, project structure conventions, module sourcing restrictions, environment configuration, pipeline integration, Checkov security scanning compliance, provider constraints, naming conventions, required default_tags keys, conftest OPA scanning, SWA module enforcement, UV package manager requirement, commit/branch conventions, and state backend configuration for Terraform deployment projects on the CCP Next platform.

A) Yes — enforce all IAC-DEPLOY rules as blocking constraints (recommended for production CCP Next Terraform deployment projects)

B) Partial — enforce only structural and naming rules (IAC-DEPLOY-01 through IAC-DEPLOY-05) but treat security scanning, pipeline, OPA, UV, and convention rules as advisory (suitable for early-stage development or local-only prototyping)

C) No — skip all IAC-DEPLOY rules (suitable for non-CCP-Next projects, non-Terraform infrastructure, or exploratory work outside the CCP Next platform)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
