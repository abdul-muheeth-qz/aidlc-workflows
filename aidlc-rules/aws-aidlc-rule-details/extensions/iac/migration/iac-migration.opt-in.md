# IaC Migration Patterns — Opt-In

**Extension**: IaC Migration Patterns (CCP Next Terraform)

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Infrastructure as Code — Migration Patterns Extension
Should CCP Next Terraform migration pattern rules be enforced for this project?

These rules enforce: prohibition of terraform import (with documented exceptions), blue-green migration strategy requirements, VPC migration via ccp-next-vpc-module, dual-control prevention, CloudFormation decommissioning patterns, and incremental migration validation for teams moving existing AWS infrastructure into CCP Next Terraform management.

A) Yes — enforce all IAC-MIGRATE rules as blocking constraints (recommended for projects actively migrating from CloudFormation or manually-created AWS infrastructure to CCP Next)

B) Partial — enforce terraform import prohibition (IAC-MIGRATE-01) and dual-control prevention (IAC-MIGRATE-03) as blocking, but treat blue-green and VPC migration rules as advisory (suitable for teams with established migration patterns that differ from the standard approach)

C) No — skip all IAC-MIGRATE rules (suitable for greenfield CCP Next projects, projects already fully on CCP Next, or non-AWS infrastructure)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
