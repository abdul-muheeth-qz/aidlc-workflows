# CCP Next Secrets Management Standards

## Overview

These secrets management rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when generating, reviewing, or modifying projects that deploy to SWA environments and handle credentials. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking CCP Next Secrets Finding Behavior

A **blocking CCP Next secrets finding** means:
1. The finding MUST be listed in the stage completion message under a "CCP Next Secrets Findings" section with the CCP-NEXT-SECRETS rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the CCP-NEXT-SECRETS rule ID, description, and stage context

If a CCP-NEXT-SECRETS rule is not applicable to the current project, mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking CCP Next secrets finding — follow the blocking finding behavior defined above.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule CCP-NEXT-SECRETS-01: Vault/CyberArk Secrets Management

**Rule**: All secrets, credentials, and AWS access keys used in deployments MUST be retrieved from CyberArk Vault via the SWA secrets management integration. Secrets MUST NOT be hardcoded in pipeline variables, configuration files, or source code. Vault users MUST be onboarded through the standard CyberArk process with environment-specific accounts.

Requirements:
- `environments.yml` (or equivalent) references `VAULT_USER` and `VAULT_AWS_SECRET` per environment
- `VAULT_AWS_SECRET` follows the path format: `Root/<AppID>/<Safe>/Directory-AIM-EDir-SemiAuto-<VaultUser>`
- No AWS access keys, passwords, or tokens are hardcoded in `.gitlab-ci.yml`, `environments.yml`, or any configuration file
- Vault users are environment-specific (separate accounts for dev, qa, prod)
- No secrets appear in pipeline logs (masked variables used where applicable)
- Source code contains no hardcoded credentials, API keys, or connection strings
- Secret values are never committed to version control in any form

**Verification**:
- `environments.yml` references `VAULT_USER` and `VAULT_AWS_SECRET` per environment section
- `VAULT_AWS_SECRET` follows the required path format: `Root/<AppID>/<Safe>/Directory-AIM-EDir-SemiAuto-<VaultUser>`
- No AWS access keys (`AKIA*`, `aws_access_key_id`, `aws_secret_access_key`) are hardcoded anywhere
- No passwords or tokens are hardcoded in `.gitlab-ci.yml`, `environments.yml`, or configuration files
- Vault users are environment-specific (not shared across dev/qa/prod)
- No secrets appear in unmasked pipeline variable definitions
- Source code contains no hardcoded credentials, API keys, connection strings, or private keys
- `.gitignore` excludes common secret file patterns (`.env`, `*.pem`, `credentials.json`)

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Requirements Analysis | CCP-NEXT-SECRETS-01 | Secrets management approach must be captured |
| Infrastructure Design | CCP-NEXT-SECRETS-01 | Vault integration architecture |
| Code Generation (Planning) | CCP-NEXT-SECRETS-01 | Code generation plan must address secrets handling |
| Code Generation (Generation) | CCP-NEXT-SECRETS-01 | Generated code must not hardcode secrets |
| Build and Test | CCP-NEXT-SECRETS-01 | Pipeline configuration must use masked variables and Vault |

At each applicable stage:
- Evaluate all CCP-NEXT-SECRETS rule verification criteria against the artifacts produced
- Include a "CCP Next Secrets Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking CCP Next secrets finding — follow the blocking finding behavior defined in the Overview
