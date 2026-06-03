# CCP Next CI Pipeline Standards

## Overview

These CI pipeline rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when generating, reviewing, or modifying GitLab CI/CD pipeline configurations for projects using SWAuto DevOps. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking CCP Next Pipeline Finding Behavior

A **blocking CCP Next pipeline finding** means:
1. The finding MUST be listed in the stage completion message under a "CCP Next Pipeline Findings" section with the CCP-NEXT-PIPELINE rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the CCP-NEXT-PIPELINE rule ID, description, and stage context

If a CCP-NEXT-PIPELINE rule is not applicable to the current project, mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking CCP Next pipeline finding — follow the blocking finding behavior defined above.

### Partial Enforcement Mode

If the user selected **Partial** enforcement during opt-in, only rules CCP-NEXT-PIPELINE-01 and CCP-NEXT-PIPELINE-04 are enforced as blocking. All other rules are treated as advisory (non-blocking). Log the enforcement mode in `aidlc-docs/aidlc-state.md` under `## Extension Configuration`.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule CCP-NEXT-PIPELINE-01: SWAuto DevOps Pipeline Integration

**Rule**: All projects MUST use the SWAuto DevOps pipeline via the approved `file-templates` include. The pipeline version (`VERSION_DEVOPS_PIPELINE`) MUST be pinned to a specific version. Projects MUST NOT use `latest` or unpinned pipeline references.

Requirements:
- `.gitlab-ci.yml` includes `SWAuto-DevOps-include.gitlab-ci.yml` from `swa-common/templates/file-templates` with a pinned `ref` version
- `VERSION_DEVOPS_PIPELINE` variable is set to a specific version (e.g., `4.64.2`)
- No `latest` or branch-based refs are used for the pipeline include
- Pipeline stages follow the SWAuto DevOps stage sequence: build → test → security_scans → push artifacts → promote

**Verification**:
- `.gitlab-ci.yml` includes `SWAuto-DevOps-include.gitlab-ci.yml` from `swa-common/templates/file-templates` with a pinned `ref` version
- `VERSION_DEVOPS_PIPELINE` variable is set to a specific version (not `latest` or a branch name)
- No `latest` or branch-based refs are used for the pipeline include
- Pipeline stages follow the SWAuto DevOps stage sequence

---

## Rule CCP-NEXT-PIPELINE-02: Artifact Promotion via Nexus

**Rule**: All build artifacts MUST be published to and promoted through the SWA Nexus repository following the standard promotion path: `ci → dev → itest/qa → prod`. An `artifacts.yml` file MUST be present and correctly configured.

Requirements:
- `artifacts.yml` exists at the project root with correct `groupId`, `artifactId`, `repoType`, and promotion stage keys (`ci`, `dev`, `itest`, `qa`, `prod`)
- `PUBLISH_TO_NEXUS_CI` is set to `'true'` in pipeline variables
- Artifact version is injected dynamically from `version.txt` (not hardcoded)
- `artifacts.yml` uses `@version@` placeholder replaced via `sed` in `before_script`

**Verification**:
- `artifacts.yml` exists at the project root with correct `groupId`, `artifactId`, `repoType`, and promotion stage keys
- `PUBLISH_TO_NEXUS_CI` is set to `'true'` in pipeline variables
- Artifact version is injected dynamically from `version.txt` (not hardcoded)
- `artifacts.yml` uses `@version@` placeholder replaced via `sed` in `before_script`

---

## Rule CCP-NEXT-PIPELINE-03: Veracode Security Scanning

**Rule**: All application code projects MUST have Veracode security scanning configured in the CI/CD pipeline. Both policy scan and sandbox scan jobs MUST be present. The `VERACODE_APP_NAME` MUST match the project's canonical application name. Scans MUST be triggered on protected branches and merge request events.

Requirements:
- `PERFORM_VERACODE_SCAN` is set to `'true'` in pipeline variables
- `VERACODE_APP_NAME` is set to the project's canonical application name
- `veracode-policy-scan` job is configured with `rules` for protected branches and MR events
- `veracode-sandbox-scan` job is configured for development scanning
- `VERACODE_BUILD_IMAGE` is pinned to a specific image digest (not `latest`)
- Build artifacts are correctly staged for Veracode scanning in `before_script`

**Verification**:
- `PERFORM_VERACODE_SCAN` is set to `'true'` in pipeline variables
- `VERACODE_APP_NAME` is set to the project's canonical application name
- `veracode-policy-scan` job is configured with `rules` for protected branches and MR events
- `veracode-sandbox-scan` job is configured for development scanning
- `VERACODE_BUILD_IMAGE` is pinned to a specific image digest (not `latest`)
- Build artifacts are correctly staged for Veracode scanning in `before_script`

---

## Rule CCP-NEXT-PIPELINE-04: CCP Next Pipeline Fragments Version

**Rule**: Projects using CCP Next pipeline fragments MUST reference a pinned, non-prerelease version of `swa-common/devplat/ccp-next/ccp-next-pipeline-fragments`. Pre-release versions (`-a.`, `-b.`, `-rc.`) MUST NOT be used in production pipelines.

Requirements:
- `.gitlab-ci.yml` references `ccp-next-pipeline-fragments` with a specific version tag (not a branch name or `latest`)
- The referenced version is not a pre-release (no `-a.`, `-b.`, or `-rc.` suffix)
- `_ccp-next-pipeline-version-checker` Makefile target is present when using CCP Next tooling
- `CCP_NEXT_PIPELINE_FRAGMENTS_PROJECT_ID` is set to `26103` in the Makefile

**Verification**:
- `.gitlab-ci.yml` references `ccp-next-pipeline-fragments` with a specific version tag
- The referenced version is not a pre-release (no `-a.`, `-b.`, or `-rc.` suffix)
- `_ccp-next-pipeline-version-checker` Makefile target is present
- `CCP_NEXT_PIPELINE_FRAGMENTS_PROJECT_ID` is set to `26103` in the Makefile

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Requirements Analysis | CCP-NEXT-PIPELINE-01 | Pipeline framework selection must be captured |
| Code Generation (Planning) | ALL | Code generation plan must address pipeline configuration |
| Code Generation (Generation) | ALL | Generated pipeline config must comply with all rules |
| Build and Test | ALL | Pipeline validation and scanning configuration |

At each applicable stage:
- Evaluate all CCP-NEXT-PIPELINE rule verification criteria against the artifacts produced
- Include a "CCP Next Pipeline Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking CCP Next pipeline finding — follow the blocking finding behavior defined in the Overview
