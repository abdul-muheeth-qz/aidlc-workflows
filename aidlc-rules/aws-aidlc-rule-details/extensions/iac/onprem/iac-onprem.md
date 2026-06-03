# CCP Next On-Premises Deployment Standards

## Overview

These IaC on-premises deployment rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when generating, reviewing, or modifying on-premises batch deployment projects on the CCP Next platform. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking IaC On-Prem Finding Behavior

A **blocking IaC on-prem finding** means:
1. The finding MUST be listed in the stage completion message under an "IaC On-Prem Findings" section with the IAC-ONPREM rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the IAC-ONPREM rule ID, description, and stage context

If an IAC-ONPREM rule is not applicable to the current project, mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking IaC on-prem finding — follow the blocking finding behavior defined above.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule IAC-ONPREM-01: Ansible Batch Deployment Structure

**Rule**: On-premises batch deployments MUST use the SWA Ansible deployment framework via the `ANSIBLE_BATCH_DEPLOY` image. Deployment configuration MUST be managed through the `deployment-configuration` project template. Each environment MUST have its own `config.yml` and `inventory.yml`. Ansible fact gathering MUST be set to `explicit`.

Requirements:
- `DEPLOYMENT_TYPE` is set to `ONPREM` in pipeline variables
- `DEPLOYMENT_SERVICE` is set to the appropriate service type (e.g., `batch`)
- Each environment directory (e.g., `environment/dev/dev2/`) contains both `config.yml` and `inventory.yml`
- `ANSIBLE_GATHERING` is set to `explicit`
- `ANSIBLE_FORCE_COLOR` is set to `'true'` for readable pipeline logs
- Deployment jobs use `$ANSIBLE_BATCH_DEPLOY` image and call `ansible_deploy.sh`
- `environments.yml` uses the `onprem_deployment.j2` template
- `output_file` in `environments.yml` is set to `.gitlab-deployments-ci.yml`
- `.gitlab-ci.yml` includes `local: .gitlab-deployments-ci.yml`

**Verification**:
- `DEPLOYMENT_TYPE` is set to `ONPREM` in `.gitlab-ci.yml` or `environments.yml`
- `DEPLOYMENT_SERVICE` is explicitly configured
- Each environment subdirectory under `environment/` contains `config.yml` and `inventory.yml`
- `ANSIBLE_GATHERING` is set to `explicit` in pipeline variables
- `ANSIBLE_FORCE_COLOR` is set to `'true'`
- Deploy jobs reference `$ANSIBLE_BATCH_DEPLOY` image
- Deploy jobs call `ansible_deploy.sh` as the primary script
- `environments.yml` specifies `template: onprem_deployment.j2`
- `.gitlab-ci.yml` includes the auto-generated `.gitlab-deployments-ci.yml`

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Infrastructure Design | IAC-ONPREM-01 | On-prem deployment architecture must use Ansible framework |
| Code Generation (Planning) | IAC-ONPREM-01 | Code generation plan must address Ansible deployment structure |
| Code Generation (Generation) | IAC-ONPREM-01 | Generated configuration must comply with all requirements |
| Build and Test | IAC-ONPREM-01 | Pipeline configuration must be validated |

At each applicable stage:
- Evaluate all IAC-ONPREM rule verification criteria against the artifacts produced
- Include an "IaC On-Prem Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking IaC on-prem finding — follow the blocking finding behavior defined in the Overview
