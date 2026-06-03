# CCP Next Code Quality Standards

## Overview

These code quality rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when generating, reviewing, or modifying Java/Gradle application projects at SWA. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking CCP Next Quality Finding Behavior

A **blocking CCP Next quality finding** means:
1. The finding MUST be listed in the stage completion message under a "CCP Next Quality Findings" section with the CCP-NEXT-QUALITY rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the CCP-NEXT-QUALITY rule ID, description, and stage context

If a CCP-NEXT-QUALITY rule is not applicable to the current project, mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking CCP Next quality finding — follow the blocking finding behavior defined above.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule CCP-NEXT-QUALITY-01: Java Code Quality Gates

**Rule**: All Java/Gradle projects MUST enforce code quality gates using the SWA-approved tools: Checkstyle, PMD (SpotBugs/FindBugs), and SonarQube. Configuration files MUST be sourced from `config/code-quality/` using SWA-standard rule sets. JaCoCo test coverage reporting MUST be configured and coverage thresholds enforced.

Requirements:
- `config/code-quality/` contains `swa-checkstyle.xml`, `swa-pmd.xml`, and `swa-findbugs.xml` (or equivalent)
- `checkstyleMain`, `pmdTest`, and `spotbugsTest` Gradle tasks are configured
- JaCoCo coverage report is generated and published as a GitLab coverage artifact
- `jacocoTestCoverageVerification` task enforces minimum coverage thresholds
- `sonar-project.properties` is present for SonarQube integration
- Coverage report path is configured in `.gitlab-ci.yml` under `coverage_report`
- `sonar_scan` job is present in `.gitlab-ci.yml` (may be `when: manual`)

**Verification**:
- `config/code-quality/` directory exists with Checkstyle, PMD, and SpotBugs configuration files
- `build.gradle` or `build.gradle.kts` configures `checkstyleMain`, `pmdTest`, and `spotbugsTest` tasks
- JaCoCo plugin is applied with coverage report generation
- `jacocoTestCoverageVerification` task is configured with minimum coverage thresholds
- `sonar-project.properties` exists at project root for SonarQube integration
- `.gitlab-ci.yml` includes `coverage_report` artifact path for JaCoCo XML output
- `sonar_scan` job is defined in `.gitlab-ci.yml`

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Code Generation (Planning) | CCP-NEXT-QUALITY-01 | Code generation plan must address quality tooling setup |
| Code Generation (Generation) | CCP-NEXT-QUALITY-01 | Generated build configuration must include quality gates |
| Build and Test | CCP-NEXT-QUALITY-01 | Quality gates must pass before stage completion |

At each applicable stage:
- Evaluate all CCP-NEXT-QUALITY rule verification criteria against the artifacts produced
- Include a "CCP Next Quality Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking CCP Next quality finding — follow the blocking finding behavior defined in the Overview
