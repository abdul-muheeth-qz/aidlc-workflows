# CCP Next Secrets Management Standards — Opt-In

**Extension**: CCP Next Secrets Management Standards

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: CCP Next Secrets Management Standards Extension
Should CCP Next secrets management standards be enforced for this project?

These rules enforce: CyberArk Vault integration for all credentials and AWS access keys, prohibition of hardcoded secrets in pipeline variables or source code, environment-specific Vault accounts, and proper secrets retrieval patterns for projects deploying to SWA environments.

A) Yes — enforce all CCP-NEXT-SECRETS rules as blocking constraints (recommended for any project deploying to SWA environments that requires credentials or secrets)

B) No — skip all CCP-NEXT-SECRETS rules (suitable for projects with no deployment credentials, local-only development, or projects using alternative approved secrets management)

X) Other (please describe after [Answer]: tag below)

[Answer]: 
```
