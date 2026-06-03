# Module Pipeline Jobs

## Pipeline Flow

```text
.pre:   discontinued-env-vars-guard (MR only), ccp-next-version-checker
setup:  setup:local
lint:   pre-commit, lint:terra, lint:js, lint-python, spellcheck
build:  build:js, build:gradle
post:   package:js
test:   test:js, test-python, test:gradle, test-terraform
scans:  checkov-static-scan, attest-checkov-static-scan
publish: publish:module:staging (MR + MODULE_STAGING_ENABLED only)
release: semantic-release → creates chore(release) commit + semver tag
deploy:  publish:module (semver tag pipeline only)
```

Not every job runs in every pipeline. Jobs appear based on file detection, variable toggles, and pipeline trigger type (MR vs push vs tag).

## Setup Jobs

### setup:local

The foundation of the entire pipeline. Every other job depends on this one. It downloads `ccp-next-general-resources`, runs the module setup script, and produces `.general-resources.mk` — the Makefile that powers all the `make` targets used by other jobs.

If this job fails, the entire pipeline is blocked. Common failure: `ccp-next-general-resources` not in the project's dependencies.

### discontinued-env-vars-guard

Only runs on MR pipelines. Checks if you're using old variable names that were renamed in v2 (e.g., `NODEJS_BUILD_DISABLED` → `NODE_BUILD_DISABLED`). The job logs tell you exactly which variables to rename.

Bypass temporarily: `DISCONTINUED_ENV_VARS_IGNORE: 'true'`

### ccp-next-version-checker

Compares your installed `ccp-next-general-resources` version and your `.gitlab-ci.yml` pipeline fragments `ref:` against the latest available versions. Warns if outdated.

This job is allowed to fail by default — it's a nudge, not a gate. Disable with `CCP_NEXT_VERSION_CHECKER_DISABLED: 'true'`.

## Lint Jobs

### pre-commit

Runs all hooks defined in `.pre-commit-config.yaml` against the full repo. Common hooks: terraform-fmt, terraform-docs, trailing whitespace, end-of-file fixer.

This job fails when hooks modify files — meaning the committed code is out of sync with what the hooks produce. This is especially common on Renovate bot commits since Renovate doesn't run pre-commit hooks.

If this fails, tell the user to run locally:

```bash
make run-pre-commit
git add -A
git commit -m "chore: apply pre-commit fixes"
git push
```

### lint:terra

Runs `make lint` which executes tflint recursively across all `.tf` files. If no `.tflint.hcl` config exists, one is auto-generated with recommended terraform + aws plugins.

Disable: `TERRA_LINT_DISABLED: 'true'`
Only runs when `.tf` or `terragrunt.hcl` files exist.

If this fails, the user should run `make lint` locally. Suppress specific rules with `#tflint-ignore: rule_name` inline or `#tflint-ignore-file: rule_name` at the top of a file.

### lint:js

Runs `make lint-js` (ESLint). Only appears when JS/TS files exist in `{src,test,tests}/`.
Disable: `NODEJS_LINT_DISABLED: 'true'`

### lint-python

Runs `make lint-python` (black + ruff + optional pyright). Only appears when `poetry.lock` or `uv.lock` exists.
Disable: `PYTHON_LINT_DISABLED: 'true'`

If black fails, run `make fix-black` locally. If ruff fails, run `make fix-ruff` locally.

### spellcheck

Runs cspell using `.vscode/cspell.json` config. Add unknown words to the `words` array in that file, or use inline `cspell:ignore` comments for one-offs.

## Build Jobs

### build:js

Runs `make build-js`. Disabled by default (`NODEJS_BUILD_DISABLED: 'true'`). Enable by clearing the variable. Produces artifacts: `**/build`, `**/dist`, `**/*.runtime.js`.

### package:js

Runs `make package-js` in the `post_build` stage. Depends on `build:js`. Disabled by default (`NODEJS_PACKAGE_DISABLED: 'true'`).

### build:gradle

Runs `make build-gradle`. Only appears when `gradlew` or `build.gradle` exists.
Disable: `GRADLE_BUILD_DISABLED: 'true'`

## Test Jobs

### test:js

Runs `make test-js`. Produces coverage reports (cobertura) and JUnit XML.
Disable: `NODEJS_TEST_DISABLED: 'true'`

### test-python

Runs `make test-python` (pytest with coverage). Produces HTML + XML coverage and JUnit XML.
Disable: `PYTHON_TEST_DISABLED: 'true'`

### test:gradle

Runs `make test-gradle`. Depends on `build:gradle` artifacts.
Disable: `GRADLE_TEST_DISABLED: 'true'`

### test-terraform

Runs `terraform test` against the module code. This is the primary way to validate module logic in CI.

Two modes:

- **Mocked providers** (`aws-account-checkout-disabled: 'true'`): No AWS credentials needed. Tests run against mock data.
- **Ephemeral environment**: Real AWS credentials checked out via EAS. Tests run against actual AWS resources.

Disable: `TERRAFORM_TEST_DISABLED: 'true'`
Only runs when `.tf` or `.tftest.hcl` files exist.

## Security Scanning

### checkov-static-scan

Static IaC analysis on `.tf` files. Runs independently — no dependencies on other jobs. Uses `--skip-path local` to ignore the local smoke testing directory.

**How severity works**:

- MEDIUM findings soft-fail (pipeline continues but the finding is still reported). These should still be resolved during development — soft-fail is a grace period, not a pass.
- HIGH and CRITICAL findings block the pipeline and must be fixed or get a Cybersecurity exemption.

Disable: `CHECKOV_STATIC_SCAN_DISABLED: 'true'`
Allow failure: `CHECKOV_STATIC_SCAN_IGNORE_FAILURE: 'true'`

### attest-checkov-static-scan

Creates an attestation record for the checkov scan results. Companion to `checkov-static-scan`.
Disable: `ATTEST_CHECKOV_STATIC_SCAN_DISABLED: 'true'`

## Release & Publish

### semantic-release

Runs on pushes to protected/default branches. Analyzes commit messages since the last tag, determines the next version, creates a `chore(release): X.Y.Z` commit and a `vX.Y.Z` tag.

Requires `release.config.{cjs,js,mjs}` in the project root.
Disable: `SEMANTIC_RELEASE_DISABLED: 'true'`

### publish:module

**The main output of the module pipeline.** Only runs on semver tag pipelines triggered by `chore(release)` commits.

What it does:

1. Reads version from `version.txt` (created by semantic-release)
2. Finds all `.tf` files and replaces `_MODULE_VERSION_` and `_MODULE_NAME_` placeholders with actual values
3. Creates `module.tar.gz` (respecting `.tarball-exclusions`)
4. Uploads to GitLab Terraform Module Registry via `curl PUT` to the packages API

Dependencies: `get-next-version` by default. Override with `publish-module_dependencies` input to add `build:js` or `build:python` if your module ships built artifacts.

### publish:module:staging

Same publish logic but runs in the `publish` stage on MR pipelines. Requires `MODULE_STAGING_ENABLED: 'true'` in `.gitlab-ci.yml`.

Use this to test a module version in a deployment project before merging. The staging version includes a pre-release suffix so it won't conflict with real releases.

## Publishing Workflow

### Standard flow

1. Open MR → pipeline runs lint, test, scan
2. Merge to default branch → semantic-release creates `v1.2.0` tag
3. Tag pipeline → `publish:module` uploads to GitLab Terraform Module Registry
4. Consumers reference it:

   ```hcl
   module "example" {
     source  = "southwest.gitlab-dedicated.com/<group>/<module-name>/aws"
     version = "1.2.0"
   }
   ```

### Staging flow (test before merge)

1. Add `MODULE_STAGING_ENABLED: 'true'` to `.gitlab-ci.yml`
2. Open MR (can be draft) → `publish:module:staging` publishes pre-release
3. Test from another project using the staging version
4. Remove the variable, merge when satisfied

### Module template variables

These placeholders in `.tf` files get auto-replaced during publish:

```hcl
variable "module_name" {
  default = "_MODULE_NAME_"    # DO NOT change this default
}
variable "module_version" {
  default = "_MODULE_VERSION_" # DO NOT change this default
}
```

Changing these defaults breaks the publish process.
