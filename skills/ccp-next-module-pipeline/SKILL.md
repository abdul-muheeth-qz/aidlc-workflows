---
name: ccp-next-module-pipeline
description: >
  Debugs and answers questions about CCP Next module pipelines (build-module.gitlab-ci.yml).
  Handles pipeline failures, job behavior questions, and module publishing issues.
  Does NOT cover deployment pipelines.
---

# CCP Next Module Pipeline Debugger

## When to use this skill

- User reports a module pipeline failure or error
- User pastes job logs or a GitLab job URL from a module pipeline
- User asks how module pipeline jobs work (publish, lint, test, scan, etc.)
- User asks about module pipeline variables or configuration

Do NOT use for deployment pipelines (plan/deploy/destroy, environments.yml, PIPELINE_ACTION).

## Workflow

### If the user provides a GitLab job URL

1. Run the fetch script:

   ```bash
   bash scripts/fetch-job-logs.sh "<job_url>"
   ```

2. If the script fails because `GITLAB_TOKEN` is not set, tell the user:

   - Set it with `export GITLAB_TOKEN=<your-token>` (needs `read_api` scope)
   - Or paste the job logs directly into chat

3. Use the `=== JOB INFO ===` line to identify the job name, stage, status, and failure reason.
4. Use the last 200 lines of the trace to find the error.
5. Check [troubleshooting](references/troubleshooting.md) for a known fix.
6. If no match, check [module pipeline jobs](references/module-pipeline-jobs.md) to understand the job's expected behavior and diagnose from there.

### If the user pastes job logs directly

1. Check [troubleshooting](references/troubleshooting.md) for a known fix.
2. If no match, identify the job name from the logs and check [module pipeline jobs](references/module-pipeline-jobs.md) for context.
3. If the issue is about a job not running or running unexpectedly, check [module pipeline setup](references/module-pipeline-setup.md) for workflow rules and variables.

### If the user asks a general question

1. Check [module pipeline setup](references/module-pipeline-setup.md) for variables, inputs, workflow rules, and stage order.
2. Check [module pipeline jobs](references/module-pipeline-jobs.md) for how specific jobs work.
3. Check [troubleshooting](references/troubleshooting.md) if the question is about a known issue.

## Reference Files

| File | What's in it |
| --- | --- |
| [module-pipeline-setup.md](references/module-pipeline-setup.md) | How to include the pipeline, inputs, variables, job toggles, workflow rules, stages, language detection, semantic versioning |
| [module-pipeline-jobs.md](references/module-pipeline-jobs.md) | Every job in the module pipeline — what it does, when it runs, and how module publishing works |
| [troubleshooting.md](references/troubleshooting.md) | Known errors with fixes, diagnostic checklist, FAQ |

## Guidelines

- This skill is module pipelines only. No deployment pipeline content.
- Always ask what triggered the pipeline (MR, push to default branch, semver tag) — different triggers produce different jobs.
- When a job is "missing" from the pipeline, check file detection first. Many jobs only run when specific file types exist (`.tf`, `.py`, `.js`). Missing files is the most common reason a job doesn't appear.
- Many variables use `''` (empty) as enabled and `'true'` as disabled — this confuses people. Call it out when relevant.
- Ensure users are on the latest versions of all CCP Next components. The `ccp-next-version-checker` job flags outdated versions automatically.
- Point users to Build → Pipeline editor → Full Configuration in GitLab to see the fully resolved pipeline YAML. This is the fastest way for them to self-debug job rules and variable resolution.
- When suggesting fixes, prefer `make` commands over raw tool commands. CCP Next projects use Makefile wrappers for everything — `make run-pre-commit` instead of `pre-commit run --all-files`, `make lint` instead of `tflint`, `make test` instead of `terraform test`. The Makefile handles environment setup and flags automatically.
- Always link users to the CCP Next documentation site for deeper reading: <https://swa-common.southwest.gitlab-dedicated.site/devplat/ccp-next/ccp-next-documentation/> — suggest it proactively when the user's question goes beyond what the skill references cover.
- Key repo locations:
  - Pipeline fragments: `swa-common/devplat/ccp-next/ccp-next-pipeline-fragments`
  - ccp-next-base component: `ccplat/components/ccp-next-base` (NOT in the ccp-next group)
  - General resources: `swa-common/devplat/ccp-next/ccp-next-general-resources`
  - Documentation: `swa-common/devplat/ccp-next/ccp-next-documentation`
