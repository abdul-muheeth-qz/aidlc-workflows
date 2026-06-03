# CCP Next CI Pipeline Standards — Opt-In

**Extension**: CCP Next CI Pipeline Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: CCP Next CI Pipeline Standards Extension
Should CCP Next CI/CD pipeline standards be enforced for this project?

These rules enforce: SWAuto DevOps pipeline integration with pinned versions, artifact promotion through Nexus (ci → dev → itest/qa → prod), Veracode security scanning configuration, and CCP Next pipeline fragments version pinning for projects deploying through the SWA GitLab CI/CD framework.

A) Yes — enforce all CCP-NEXT-PIPELINE rules as blocking constraints (recommended for projects with a .gitlab-ci.yml deploying through SWAuto DevOps)

B) Partial — enforce only pipeline version pinning (CCP-NEXT-PIPELINE-01 and CCP-NEXT-PIPELINE-04) but treat artifact promotion and Veracode rules as advisory (suitable for projects still onboarding to full SWAuto DevOps)

C) No — skip all CCP-NEXT-PIPELINE rules (suitable for projects without GitLab CI pipelines or not using SWAuto DevOps)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
