# IaC Module Development Standards — Opt-In

**Extension**: IaC Module Development Standards (CCP Next Terraform)

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Infrastructure as Code — Module Development Standards Extension
Should CCP Next Terraform module development standards be enforced for this project?

These rules enforce: module project structure, labels module integration, input/output conventions, testing with mock providers, example configurations, local smoke testing patterns, Checkov static scanning, publishing pipeline conventions, and community module requirements for Terraform modules on the CCP Next platform.

A) Yes — enforce all IAC-MODULE rules as blocking constraints (recommended for CCP Next Terraform module projects intended for publishing and reuse)

B) Partial — enforce only structure and coding rules (IAC-MODULE-01 through IAC-MODULE-06) but treat testing, publishing, and pipeline rules as advisory (suitable for internal-only or early-stage module development)

C) No — skip all IAC-MODULE rules (suitable for non-module projects, deployment-only repos, or Terraform modules outside the CCP Next ecosystem)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
