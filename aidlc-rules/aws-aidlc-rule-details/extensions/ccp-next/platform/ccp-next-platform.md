# CCP Next Platform Tooling Standards

## Overview

These platform tooling rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when generating, reviewing, or modifying projects that use the CCP Next deployment tooling package and environment/namespace structure. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking CCP Next Platform Finding Behavior

A **blocking CCP Next platform finding** means:
1. The finding MUST be listed in the stage completion message under a "CCP Next Platform Findings" section with the CCP-NEXT-PLATFORM rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the CCP-NEXT-PLATFORM rule ID, description, and stage context

If a CCP-NEXT-PLATFORM rule is not applicable to the current project, mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking CCP Next platform finding — follow the blocking finding behavior defined above.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule CCP-NEXT-PLATFORM-01: CCP Next General Resources Package

**Rule**: All CCP Next deployment projects MUST use the `ccp-next-general-resources` Python package for standardized Makefile targets, deployment scripts, and environment setup. The package version MUST be pinned. The `ccp-next-version-checker` target MUST be available.

Requirements:
- `ccp-next-general-resources` is listed as a dependency with a pinned version in `pyproject.toml`
- `Makefile` includes standard CCP Next targets: `setup`, `plan`, `deploy`, `destroy`, `checkov-dynamic-scan`, `ccp-iac-scan`, `ccp-next-version-checker`
- `_ccp-next-general-resources-version-checker` target is present to validate version currency
- `install-ccp-next-general-resources` script is available in the virtual environment
- Package version uses `>=x.y.z,<next-major` constraint format

**Verification**:
- `ccp-next-general-resources` is listed as a dependency with a pinned version in `pyproject.toml`
- `Makefile` includes standard CCP Next targets: `setup`, `plan`, `deploy`, `destroy`, `checkov-dynamic-scan`, `ccp-iac-scan`
- `_ccp-next-general-resources-version-checker` or `_ccp-next-pipeline-version-checker` target is present
- `install-ccp-next-general-resources` script is available after `uv sync` or `poetry install`

---

## Rule CCP-NEXT-PLATFORM-02: Environment and Namespace Structure

**Rule**: All CCP Next deployments MUST follow the standard environment structure with separate namespaces for `dev`, `qa`, and `prod`. The `NAMESPACE` and `ENV_PREFIX` variables MUST be set for all deployments. Local deployments MUST be prefixed with `local-<USER>-` to prevent conflicts with pipeline-deployed resources.

Requirements:
- `environments.yml` defines at minimum `dev`, `qa`, and `prod` environment sections
- `ENV_PREFIX` is restricted to allowed values: `lab`, `dev`, `qa`, `prod`
- `REGION` defaults to `us-east-1` and is restricted to: `us-east-1`, `us-west-2`, `eu-central-1`, `eu-west-1`
- Deployment namespace for local runs is automatically prefixed with `local-<USER>-`
- `setup-env` Makefile target generates `.gitlab-deployments-ci.yml` from `environments.yml`
- `environments.yml` validates against the CCP Next environments JSON schema
- Multi-region deployments use separate namespaces per region (e.g., `dev0-us-east-1`, `dev0-us-west-2`)

**Verification**:
- `environments.yml` exists at project root with `dev`, `qa`, and `prod` environment sections
- `ENV_PREFIX` values in `environments.yml` are restricted to `lab`, `dev`, `qa`, `prod`
- `REGION` values are restricted to allowed regions
- `setup-env` Makefile target exists and generates `.gitlab-deployments-ci.yml`
- No hardcoded namespace or environment values outside `environments.yml`
- Multi-region deployments use separate namespace entries per region

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Requirements Analysis | CCP-NEXT-PLATFORM-02 | Environment and namespace structure decisions must be captured |
| Infrastructure Design | ALL | Tooling and environment architecture |
| Code Generation (Planning) | ALL | Code generation plan must address platform tooling |
| Code Generation (Generation) | ALL | Generated code must comply with all rules |
| Build and Test | CCP-NEXT-PLATFORM-01 | Version checking and Makefile validation |

At each applicable stage:
- Evaluate all CCP-NEXT-PLATFORM rule verification criteria against the artifacts produced
- Include a "CCP Next Platform Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking CCP Next platform finding — follow the blocking finding behavior defined in the Overview
