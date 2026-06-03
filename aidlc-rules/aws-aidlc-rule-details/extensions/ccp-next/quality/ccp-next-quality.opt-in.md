# CCP Next Code Quality Standards — Opt-In

**Extension**: CCP Next Code Quality Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: CCP Next Code Quality Standards Extension
Should CCP Next code quality standards be enforced for this project?

These rules enforce: Checkstyle, PMD/SpotBugs code analysis with SWA-standard rule sets, JaCoCo test coverage thresholds, and SonarQube integration for Java/Gradle application projects.

A) Yes — enforce all CCP-NEXT-QUALITY rules as blocking constraints (recommended for Java/Gradle application projects subject to SWA code quality gates)

B) No — skip all CCP-NEXT-QUALITY rules (suitable for non-Java projects, Python/Node.js projects, Terraform-only projects, or prototypes)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
