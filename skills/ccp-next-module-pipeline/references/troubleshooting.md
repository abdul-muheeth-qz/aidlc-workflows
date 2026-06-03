# Module Pipeline Troubleshooting

## Known Errors

### 1. setup:local fails — ".general-resources.mk not found"

**What happened**: The `ccp-next-general-resources` package failed to install or the setup script didn't produce the expected Makefile.

**Fix**: Verify `ccp-next-general-resources` is listed in your project's `pyproject.toml` dependencies and that the lock file (`poetry.lock` or `uv.lock`) includes it. If it's missing, add it and regenerate the lock file.

### 2. "Command not found: xxxxxx"

**What happened**: The GitLab runner cache has stale or missing binaries from a previous pipeline run.

**Fix**: Go to Build → Pipelines → Clear runner caches, then create a **new** pipeline. Simply re-running the failed job usually doesn't work because the cache is loaded at job start. This commonly happens after upgrading CCP Next versions.

### 3. No new version released after merge

**What happened**: `semantic-release` didn't create a tag because the commit messages don't match the expected format.

**Fix**: Commits must use conventional prefixes:

- `fix: description` → patch bump
- `feat: description` → minor bump
- `BREAKING CHANGE:` in the commit footer → major bump
- `perf:` does NOT trigger a release

Also verify `release.config.{cjs,js,mjs}` exists in the project root. Without it, semantic-release won't run at all.

### 4. publish:module not running

**What happened**: This job has very specific trigger conditions — it only runs on semver tag pipelines created by `chore(release)` commits.

**Check these in order**:

1. Did semantic-release actually run? Check the merge pipeline for a `get-next-version` or `semantic-release` job.
2. Was a tag created? Check the project's tags page.
3. Is `SEMANTIC_RELEASE_DISABLED` set to `'true'`?
4. Does `release.config.{cjs,js,mjs}` exist?

### 5. publish:module:staging not appearing

**What happened**: The staging publish job requires two conditions to be true simultaneously.

**Both must be true**:

- `MODULE_STAGING_ENABLED: 'true'` is set in `.gitlab-ci.yml` variables
- The pipeline is an MR pipeline (not a branch push or tag)

If either condition is missing, the job won't appear.

### 6. Checkov scan failures

**What happened**: Checkov found IaC policy violations in your `.tf` files.

**How it works in the module pipeline**:

- MEDIUM findings soft-fail (pipeline continues)
- HIGH and CRITICAL findings block the pipeline
- The `local/` directory is automatically skipped (`--skip-path local`)

**Options**:

- Fix the finding (preferred)
- Set `CHECKOV_STATIC_SCAN_IGNORE_FAILURE: 'true'` to allow failure (not recommended for production)
- HIGH/CRITICAL suppressions require Cybersecurity team approval

### 7. tflint errors

**What happened**: tflint found issues with your Terraform code (unused variables, deprecated syntax, AWS-specific warnings, etc.).

**Fix**: The error message includes the rule name and a link to documentation. Suppress specific findings:

- Single block: `#tflint-ignore: rule_name` above the resource/variable
- Entire file: `#tflint-ignore-file: rule_name` at the top

Run `make lint` locally to catch these before pushing.

### 8. "Invalid registry module source address"

**What happened**: You're using the GitLab repository URL as the module source instead of the Terraform registry format.

**Fix**: Go to Operate → Terraform modules in your GitLab project to find the correct source format:

```hcl
source  = "southwest.gitlab-dedicated.com/<group>/<module-name>/aws"
version = "1.2.0"
```

### 9. Discontinued environment variables error

**What happened**: The `discontinued-env-vars-guard` job detected old variable names from v1 that have been renamed in v2.

**Fix**: The job output tells you exactly which variables to rename. Update them in your `.gitlab-ci.yml`. Bypass temporarily with `DISCONTINUED_ENV_VARS_IGNORE: 'true'` while you migrate.

### 10. terraform test fails with backend error

**What happened**: `terraform test` needs to initialize without a remote backend (`-backend=false`), but something is overriding that.

**Fix**: The `terraform-test` component handles this automatically. If it still fails, check that `OPTS_TF_INIT` isn't being set to something that conflicts in your `.gitlab-ci.yml` or Makefile.

### 11. Resource name exceeds maximum length

**What happened**: AWS has character limits on resource names, and the CCP Next naming convention (which includes namespace, environment, etc.) can exceed them.

**Fix**: Use `id_length_limit` in the CCP Next Labels Module to cap the generated name length.

### 12. ccp-next-version-checker fails

**What happened**: Your `ccp-next-general-resources` package or `ccp-next-pipeline-fragments` ref is outdated.

**Fix**: Update the `ref:` in your `.gitlab-ci.yml` to the latest pipeline fragments version, and update your Python lock file to pull the latest `ccp-next-general-resources`.

**Note**: This job is allowed to fail by default — it's a warning, not a blocker. But staying current avoids compatibility issues.

## Diagnostic Checklist

When debugging a module pipeline failure, work through these in order:

1. **Which job failed?** The job name tells you exactly where to look.
2. **What triggered the pipeline?** MR, push to default branch, or semver tag? Different triggers produce different jobs.
3. **What's the commit message?** Affects whether semantic-release runs and whether version-bump skip rules apply.
4. **Is it a Renovate pipeline?** Renovate MRs and merges have special skip rules that suppress most jobs.
5. **Are any `*_DISABLED` variables set?** A job might be intentionally turned off.
6. **Do the expected files exist?** Jobs like `lint:terra`, `test-terraform`, `lint:js` only run when their file types are detected. No `.tf` files = no terraform jobs.
7. **Is the runner cache stale?** If commands are missing or behaving oddly, clear the cache and run a fresh pipeline.

## FAQ

| Question | Answer |
| --- | --- |
| How to test a module before merging? | Set `MODULE_STAGING_ENABLED: 'true'` in `.gitlab-ci.yml` |
| How to override the module name? | Set `MODULE_NAME` in `.gitlab-ci.yml` variables |
| Where are published modules? | Operate → Terraform modules in GitLab |
| How to delete a module version? | Operate → Terraform modules → delete button on the right |
| What linters run? | tflint (Terraform), black + ruff (Python), ESLint (Node.js) |
| How to see the full resolved pipeline? | Build → Pipeline editor → Full Configuration |
| Sonar scan failing? | Sonar is not included by default — add the `sonar/sonar` component to your includes |
| Spellcheck failing? | Add words to `.vscode/cspell.json` or use inline `cspell:ignore` comments |
| How to enable Node.js build? | Set `NODEJS_BUILD_DISABLED: ''` (empty string) in `.gitlab-ci.yml` |
| Why did my pipeline not run? | Check workflow rules — most common: branch pipeline suppressed because an MR is open |

## Support

- Slack: [#help-development-platforms](https://swa-technology.enterprise.slack.com/archives/C0169BU5WKB)
- Docs: [ccp-next docs site](https://swa-common.southwest.gitlab-dedicated.site/devplat/ccp-next/ccp-next-documentation/)
