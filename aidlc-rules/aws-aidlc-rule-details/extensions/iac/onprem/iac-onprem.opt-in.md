# IaC On-Premises Deployment Standards — Opt-In

**Extension**: IaC On-Premises Deployment Standards (CCP Next Ansible)

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Infrastructure as Code — On-Premises Deployment Standards Extension
Should CCP Next on-premises deployment standards be enforced for this project?

These rules enforce: Ansible batch deployment structure using the SWA deployment framework, environment-specific config.yml/inventory.yml files, ANSIBLE_BATCH_DEPLOY image usage, and deployment-configuration template patterns for projects deploying to on-premises servers.

A) Yes — enforce all IAC-ONPREM rules as blocking constraints (recommended for projects with DEPLOYMENT_TYPE: ONPREM deploying to on-premises servers via Ansible)

B) No — skip all IAC-ONPREM rules (suitable for cloud-only deployments, projects not using Ansible, or projects without on-premises infrastructure)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
