---
name: ccp-next-deployment-support
description: >
  Diagnoses and fixes CCP Next (Terraform) deployment issues. When given a failing GitLab
  job URL, fetches the job log via GitLab API and diagnoses the error automatically.
  Covers pipeline upgrade errors, Checkov scan failures, multi-region deployment, EAS/auth
  issues, Lambda layer problems, runner/cache failures, state issues, local development,
  and more. Trained on 330 real customer support threads from #help-development-platforms.
  Use when a customer reports a CCP Next error or asks how to fix a CCP Next problem.
---

# CCP Next Deployment Support Skill

This skill diagnoses and resolves CCP Next (Terraform) platform issues. It is trained on
real customer support threads and covers the most common pain points.

## When to use this skill

Activate this skill when the user:

- Provides a failing GitLab job URL
- Pastes an error message from a CCP Next pipeline
- Asks why their pipeline is failing
- Asks how to fix a CCP Next issue
- Is stuck on a CCP Next deployment, upgrade, or configuration problem

## Workflow

### Step 1: Get the error

**If the user provides a GitLab job URL** (e.g., `https://southwest.gitlab-dedicated.com/my-group/my-project/-/jobs/12345678`):

1. Check if `GITLAB_TOKEN` is set
2. **If set:** Fetch the job log automatically:
   - Extract `gitlab_host`, `project_path`, and `job_id` from the URL
   - URL-encode the project path (replace `/` with `%2F`)
   - Fetch the log:

     ```bash
     curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
       "https://<gitlab_host>/api/v4/projects/<encoded_project_path>/jobs/<job_id>/trace"
     ```

   - Use the last 200 lines of the log for diagnosis (errors are usually at the bottom)
3. **If not set:** Ask the customer to paste the relevant error from the job log

**If the user pastes an error directly:** Use it as-is.

### Step 2: Diagnose

Match the error against the known patterns below. Give:

1. What caused the error
2. The specific fix (commands or config changes)
3. How to prevent it in the future

---

## PIPELINE UPGRADE (v1 → v2)

### Symptoms

- `discontinued environment variable` errors
- `CHECKOV_IAC_IGNORE_FAILURE is set` warnings
- Missing jobs after upgrade
- `file does not exist` errors referencing old pipeline paths
- Pre-commit failing after upgrade
- `deactivate: command not found`
- `publish-python-lib-releases` job missing

### Fixes

**Renamed variables (must update in `.gitlab-ci.yml`):**

| Old (v1) | New (v2) |
| ---------- | ---------- |
| `CHECKOV_IAC_IGNORE_FAILURE` | `CHECKOV_STATIC_SCAN_IGNORE_FAILURE` / `CHECKOV_DYNAMIC_SCAN_IGNORE_FAILURE` |
| `CHECKOV_IAC_SCAN_DISABLED` | `CHECKOV_STATIC_SCAN_DISABLED` / `CHECKOV_DYNAMIC_SCAN_DISABLED` |
| `OPTS_CHECKOV_IAC_SCAN` | `OPTS_CHECKOV_DYNAMIC_SCAN` |
| `OPTS_CHECKOV_IAC_STATIC_SCAN` | `OPTS_CHECKOV_STATIC_SCAN` |
| `TERRA_TEST_DISABLED` | `TERRAFORM_TEST_DISABLED` |
| `NODE_BUILD_DISABLED` | `NODEJS_BUILD_DISABLED` |
| `UNIT_TEST_DISABLED` | `NODEJS_TEST_DISABLED` / `GRADLE_TEST_DISABLED` |

**Step-by-step upgrade checklist:**

1. Clear runner cache FIRST (`Build → Pipelines → Clear Runner Caches`, requires Maintainer)
2. Upgrade `ccp-next-pipeline-fragments` ref to latest `2.x.x` in `.gitlab-ci.yml`
3. Upgrade `ccp-next-general-resources` to `>= 2.0.0` (`poetry update --sync` or `uv sync`)
4. Run `make setup` locally to regenerate `.general-resources.mk`
5. Run `make setup-env` to regenerate `.gitlab-deployments-ci.yml`
6. Copy `.pre-commit-config.yaml` from the latest matching template
7. Copy `Makefile` from the latest matching template
8. Rename all discontinued variables (see table above)
9. Commit and push

**Trivy removal:**

- v2 pipelines removed Trivy entirely — no action needed
- If still on v1 and need quick fix: `CSPE_TRIVY_SCANNER_DISABLED: 'true'`
- Recommended: upgrade to v2

**`deactivate: command not found`:**

- Caused by adding attestation components that override the `before_script`
- Fix: upgrade `attest-vsa` to latest version, remove `attest-peer-review` (CCP Next includes it out of the box)
- CCP Next v2 includes peer review attestation and Checkov — don't add them separately as components

**`publish-python-lib-releases` missing in v2:**

- CCP Next does NOT support publishing Python libraries
- Use `python-uv-template` or `python-pypi-lib` template instead

**`deploy-static-website.gitlab-ci.yml` not found:**

- Moved to `ccp-next-spa-template` in v2
- Reference: `southwest.gitlab-dedicated.com/swa-common/devplat/ccp-next/ccp-next-templates/ccp-next-spa-template`

**Poetry 1.x incompatible with v2:**

- v2 requires Poetry 2.x or UV
- Fix: upgrade Poetry to 2.x locally, regenerate `poetry.lock`, or migrate to UV

---

## CHECKOV / SECURITY SCAN

### `OPTS_CHECKOV_STATIC_SCAN` not working

**Symptom:** Checkov skip/soft-fail options have no effect

**Cause:** `OPTS_CHECKOV_STATIC_SCAN` was set in `environments.yml` — it has NO effect there. Static scan is not namespaced.

**Fix:** Move `OPTS_CHECKOV_STATIC_SCAN` to `.gitlab-ci.yml` variables section:

```yaml
variables:
  OPTS_CHECKOV_STATIC_SCAN: --quiet --support --download-external-modules true --soft-fail-on MEDIUM,CKV_TF_1
```

### Checkov skip not working after upgrade to 2.15.8+

**Cause:** CCP Next now includes Checkov out of the box. If you also added it as a separate component, there's a conflict.

**Fix:** Remove the separate Checkov component include from `.gitlab-ci.yml` — CCP Next handles it.

### External module findings (`/.external_modules/`)

**Cause:** Static scan evaluates external modules without your inputs applied. These findings reflect default module configs.

**Fix:** Dynamic scan is more authoritative. For static scan findings you can't fix:

```yaml
OPTS_CHECKOV_STATIC_SCAN: --quiet --support --download-external-modules true --soft-fail-on MEDIUM,CKV_TF_1
```

Consult `#team-cloudsecurity` before suppressing HIGH/CRITICAL.

### `CKV_AWS_45` — Lambda env vars expose secrets

**Fix:** Add inline skip before `environment_variables`:

```hcl
#checkov:skip=CKV_AWS_45:Environment variables contain configuration, not secrets
environment_variables = { ... }
```

### `--soft-fail-on MEDIUM,LOW` — redundant

`MEDIUM` already means MEDIUM and lower. `LOW` is redundant. Use just `--soft-fail-on MEDIUM`.

### Checkov failing on `checkov-static-scan` vs `checkov-dynamic-scan`

- `checkov-static-scan` — runs on source code, no plan needed, runs in MR pipelines
- `checkov-dynamic-scan` — runs on plan JSON, runs in release pipelines
- `OPTS_CHECKOV_STATIC_SCAN` controls static scan (set in `.gitlab-ci.yml` only)
- `OPTS_CHECKOV_DYNAMIC_SCAN` controls dynamic scan (can be set per-namespace in `environments.yml`)

---

## MULTI-REGION DEPLOYMENT

### Jobs only deploying to one region

**Cause:** Single namespace with `REGION` variable — only deploys to selected region.

**Fix:** Add separate namespaces per region in `environments.yml`:

```yaml
dev:
  dev0-us-east-1:
    variables:
      REGION: us-east-1
      DEPLOYMENT_NAMESPACE: dev0
      AUTO_DEV_APPLY: true
      DEPLOYMENT_RESOURCE_GROUP: ${NAMESPACE}
  dev0-us-west-2:
    variables:
      REGION: us-west-2
      DEPLOYMENT_NAMESPACE: dev0
      AUTO_DEV_APPLY: true
      DEPLOYMENT_RESOURCE_GROUP: ${NAMESPACE}
```

Then run `make setup-env` to regenerate `.gitlab-deployments-ci.yml`.

### `ENABLE_NOT_RECOMMENDED_MR_DEV_DEPLOY` only deploys to east

**Fix:** Same as above — add region-specific namespaces. MR deploy only triggers for namespaces defined in `environments.yml`.

### Hierarchical tfvars (v2 feature)

You can have environment-level variables that apply to all namespaces in that environment:

```text
tfvars/
  dev/
    env.tfvars          # applies to all dev namespaces
    dev0.tfvars         # applies to dev0 only
    dev0-us-east-1.tfvars  # applies to dev0-us-east-1 only
```

### CloudFront WAF in multi-region

CloudFront WAF scope is `CLOUDFRONT` — can only be created in `us-east-1`. For west region deployments, set `web_acl_id = null` and soft-fail the relevant Checkov checks.

---

## EAS / AUTH ISSUES

### `Unable to find OpenID/SAML identity for user NNNN`

**Cause:** `AUTO_DEV_APPLY: true` is set and the semantic-release service account triggered the pipeline after a merge. Service accounts don't have deploy roles — by design.

**Fix:** Re-run the failed job manually as yourself. This is expected behavior, not a bug.

### Pipeline "blocked" state

**Cause:** Deploy jobs are manual by design. Someone must manually trigger which namespace to deploy.

**This is expected behavior.** The pipeline stays blocked until a human triggers the deploy job.

### `AUTO_DEV_APPLY` not working

**Cause:** Must be set per namespace, not globally. Also requires a `fix:` or `feat:` commit to trigger.

```yaml
dev:
  dev0:
    variables:
      AUTO_DEV_APPLY: true
```

### `dev_prep` job missing in v2

**Cause:** v2 removed prep jobs. Credentials are now sourced as part of plan/deploy jobs directly.

**Fix:** No action needed. Use the `plan` job as a pre-implementation task on CRs — it doesn't modify resources.

### `ENABLE_NOT_RECOMMENDED_MR_DEV_DEPLOY` not showing deploy jobs

**Cause:** Must push with a version bump commit (`fix:` or `feat:`). No version bump = reduced jobs to conserve GitLab resources.

**Fix:** Make a commit with `fix: <description>` or `feat: <description>` prefix.

---

## RUNNER / CACHE / NEXUS

### `Permission denied: .venv` or `PosixPath('.venv')`

**Cause:** Stale Python `.venv` lingering in runner cache from a previous run.

**Fix:** Clear runner cache: `Build → Pipelines → Clear Runner Caches` (requires Maintainer role), then re-run the job.

### `chmod: changing permissions of deployment_env_setup.sh: Operation not permitted`

**Cause:** Same — stale runner cache.

**Fix:** Clear runner cache (same as above).

### `six (1.17.0): Failed` / `All attempts to connect to nexus-tools.swacorp.com failed`

**Cause:** Nexus connectivity issue — usually transient.

**Fix:** Clear runner cache and retry. If persistent, check VPN/network.

### tflint `403 API rate limit exceeded` (GitHub)

**Cause:** tflint bootstraps plugins directly from GitHub. GitHub rate limits can throttle requests.

**Fix:** Just retry the job after 5-10 minutes. This is a known tflint quirk — no permanent fix available.

### `Command not found: <tool>` after major version upgrade

**Cause:** Stale runner cache with old tool versions.

**Fix:** Clear runner cache (`Build → Pipelines → Clear Runner Caches`), then create a new pipeline.

---

## PIPELINE JOBS / RELEASE

### Deploy jobs not showing in pipeline

**Cause:** Normal branch pipelines don't show deploy jobs — expected behavior.

**Deploy jobs appear when:**

- You merge to the default branch (creates a release tag, then deploy jobs appear on the tag pipeline)
- You have `ENABLE_NOT_RECOMMENDED_MR_DEV_DEPLOY: 'true'` set AND it's a merge request pipeline (not a branch pipeline) AND you pushed with a `fix:` or `feat:` commit

### No release pipeline / chore release not triggering

**Cause:** Commit message doesn't follow semantic-release format.

**Fix:** Use `fix:`, `feat:`, or `BREAKING CHANGE:` in commit messages. `chore:`, `docs:`, `ci:` do NOT trigger a release.

If this is a brand new repo with no previous tags:

1. Manually create a tag (e.g., `0.0.1` or `1.0.0`) via GitLab UI
2. Then run a pipeline from that tag

### `Couldn't Determine Next Version`

**Cause:** No previous release tag exists for semantic-release to base the next version on.

**Fix:** Manually create a version tag (e.g., `0.0.1`) via GitLab UI → Repository → Tags.

### `release.config.js` issues

**Cause:** Truncated or misconfigured `release.config.js`.

**Fix:** Copy `release.config.js` from the latest matching CCP Next template.

### Pipeline stuck "Waiting for resource"

**Cause:** `DEPLOYMENT_RESOURCE_GROUP` is set and a previous pipeline is holding the lock, or jobs are queued waiting for human approval.

**Fix:**

1. Check `Operate → Environments` for active deployments
2. Check `https://gitlab.../api/v4/projects/<id>/resource_groups/<namespace>-deploy/upcoming_jobs`
3. Cancel any stuck pipelines and retry

---

## LAMBDA / LAYER ISSUES

### `No module named X` / `Runtime.ImportModuleError`

**Cause 1:** Dependency added to `layer/pyproject.toml` but `poetry.lock` not updated.
**Fix:** `cd layer && poetry lock && cd ..` then redeploy.

**Cause 2:** Dependency not in `layer/pyproject.toml` at all.
**Fix:** Add it to `layer/pyproject.toml`, run `cd layer && poetry lock`.

**Cause 3:** Native C library (confluent-kafka, pydantic-core, cryptography, cffi) compiled for wrong architecture.
**Fix:** Use `build_in_docker = true` for local deploys. Pipeline builds on Linux runners work automatically.

### Handler not found / `Unable to import module`

**Cause:** Mismatch between `handler`, `prefix_in_zip`, and actual file structure.

**Rules:**

- With `prefix_in_zip = "src"` → handler must be `src.lambda_function.lambda_handler`
- Without prefix → handler is `lambda_function.lambda_handler`
- Node.js with esbuild: handler prefix must match `:zip` command prefix

### Multiple lambdas — code changes not detected

**Cause:** Multiple lambdas sharing the same `source_path` directory.

**Fix:** Each lambda MUST have a unique subdirectory under `src/`:

```text
src/
  lambda_one/
    lambda_function.py
  lambda_two/
    lambda_function.py
```

Use `hash_extra` if you must share a source path:

```hcl
source_path = [{
  path       = "${path.module}/../src"
  hash_extra = "lambda_one"
}]
```

### Docker not found in pipeline

**Cause:** `build_in_docker = true` is set — Docker is not available in GitLab runners.

**Fix:** Remove `build_in_docker = true` for pipeline deployments. Only use it for local deploys on macOS.

### ARM64 lambda failing to build

**Cause:** Lambda configured for `arm64` but running on `build-runner` (x86). Need `arm-runner` tag.

**Fix:** Add to `environments.yml`:

```yaml
dev:
  dev0:
    variables:
      ARM_RUNNER: "true"
```

### Python 3.13 incompatibility

**Cause:** Some native deps (pydantic-core, rpds-py, cffi) don't support Python 3.13 yet.

**Fix:** Use Python 3.12:

```yaml
variables:
  PYTHON_VERSION: "3.12"
```

---

## STATE / BACKEND ISSUES

### `Backend Configuration Changed`

**Cause:** `NAMESPACE`, `ENV_PREFIX`, or AWS account changed — old backend config cached in `.terraform/`.

**Fix:**

```sh
make clean  # removes .terraform dir
# OR
make init OPTS_TF_INIT="-reconfigure"
```

### `Saved plan is stale`

**Cause:** State was changed by another operation after the plan was created.

**Fix:** Delete the old plan file, run a new `make plan`, then `make deploy`.

### State lock stuck (`Error acquiring the state lock`)

**Fix (preferred for dev):** Log into AWS console → S3 → find the state bucket → delete the `.lock` file manually.

State bucket naming: `swa-ec-tf-state-<account-number>-<region>`
Lock file path: same as state file with `.lock` suffix (e.g., `terraform.tfstate.lock`)

### State key mismatch after repo rename/move

**Cause:** State key includes the repo path. Renaming or moving the repo breaks the key.

**Fix:** Either rename the repo back, or manually rename the state file path in S3 (make a copy first).

---

## LABELS MODULE

### `department cannot be null or empty string`

**Cause:** `defaults.auto.tfvars` is missing or `department` is not set in it.

**Fix:** Add to `terraform/defaults.auto.tfvars`:

```hcl
department = "your-department"
```

### `dash_application_service` UUID — where to find it

It's in the ServiceNow URL when you click on your Application Service:
`https://southwest.service-now.com/now/nav/ui/classic/params/target/cmdb_ci_service_auto.do?sys_id=<UUID>`

The `sys_id` value is the UUID.

### Resource name too long

**Fix:** Use `id_length_limit` on the labels module:

```hcl
module "labels_short" {
  source          = "southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws"
  version         = "0.7.0"
  id_length_limit = 25
  context         = module.root_labels.context
}
```

---

## LOCAL DEVELOPMENT

### Windows not supported

CCP Next does not support Windows/GitBash.

**Fix:** Use VSCode DevContainers:

- Install VSCode + DevContainers extension
- Clone `ccp-next-devcontainer`: `southwest.gitlab-dedicated.com/swa-common/devplat/ccp-next/ccp-next-devcontainer`
- Follow the Windows README inside the repo

### Local namespace prepends `local-<username>-`

**This is by design.** Local deployments use `local-<username>-<namespace>` to prevent collision with pipeline-deployed resources.

If you need to reference SSM parameters or resources from the pipeline namespace, use `var.gitlab_ci`:

```hcl
variable "gitlab_ci" {
  type    = bool
  default = false
}

data "aws_ssm_parameter" "my_param" {
  name = var.gitlab_ci ? "/prod/dev0/param" : "/prod/dev0/param"
  # or use different paths based on environment
}
```

`GITLAB_CI` is automatically `true` in pipelines.

### SSL certificate error on Mac (local deploy)

**Fix:**

```sh
poetry run pip config set global.trusted-host nexus-tools.swacorp.com
```

Or add to `~/.config/pip/pip.conf`:

```ini
[global]
index-url = https://nexus-tools.swacorp.com/repository/all-pypi/simple
timeout = 60
trusted-host = nexus-tools.swacorp.com
```

### `make plan` — `Too many command line arguments`

**Cause:** Space in the directory path (e.g., `Documents/My Projects/repo`).

**Fix:** Move the repo to a path without spaces.

---

## POETRY / UV / DEPENDENCIES

### `pyproject.toml changed significantly since poetry.lock was last generated`

**Fix:** Run `poetry lock` (or `cd layer && poetry lock` for layer deps), then commit the updated `poetry.lock`.

### `poetry.lock` in `layer/` out of date

**Fix:** `cd layer && poetry lock && cd ..` then commit.

### `~/swa-bundle.pem` not working

**Cause:** Poetry doesn't expand `~` in paths.

**Fix:** Use the absolute path: `/Users/<username>/swa-bundle.pem`

### `setup-poetry fails` / `ccp-next-general-resources is outdated`

**Fix:** Run `poetry update --sync` then `make setup`.

### Module publish `403 Forbidden — version already exists`

**Cause:** `pyproject.toml` version is out of sync with `package.json`.

**Fix:** Manually edit `pyproject.toml` to match the version in `package.json`, commit, and let semantic-release handle future versions.

---

## MODULE SOURCE / OPA POLICY

### `module_source_policy — Module source not approved`

**Cause:** Module source URL format is wrong, or module is not from a whitelisted namespace.

**Whitelisted sources:**

1. `southwest.gitlab-dedicated.com/swa-common/...` (CCP Next modules)
2. `terraform-aws-modules/<module>/aws` (NOT `registry.terraform.io/terraform-aws-modules/...`)
3. `aws-ia/<module>/aws`
4. `cloudposse/<module>/aws`

**EKS module fix:**

```hcl
# WRONG
source = "registry.terraform.io/terraform-aws-modules/eks/aws"

# CORRECT
source  = "terraform-aws-modules/eks/aws"
version = "21.18.0"
```

---

## TOKEN / AUTH

### `401 Unauthorized` on module download

**Cause:** `TF_TOKEN_southwest_gitlab__dedicated_com` not set or expired.

**Fix:**

1. Generate a new GitLab personal access token with `read_api`, `read_repository`, `read_registry` scopes
2. Export: `export TF_TOKEN_southwest_gitlab__dedicated_com=<token>` (note: double underscore for dots)
3. Tokens expire after 1 year — regenerate when getting 401

### `make plan` failing with module download error

**Cause:** GitLab token expired or not set.

**Fix:** See token setup docs: `swa-common.southwest.gitlab-dedicated.site/devplat/ccp-next/ccp-next-documentation/getting_started/tokens/`

---

## VPC / NETWORKING

### `ccp-next-vpc-module` — public subnets require secondary CIDR

**Cause:** Public subnets, internal subnets, and internal data subnets can only be created from the `100.64.0.0/16` secondary CIDR range — by design.

**Fix:** Either enable secondary CIDR block, or don't create public subnets.

### Transit Gateway — cannot reuse CCP Legacy attachment

CCP Next creates a new Transit Gateway attachment. You cannot reuse an attachment created by CCP Legacy.

### Lambda ENIs not deleting after function deletion

**Cause:** AWS takes 20-40 minutes to delete Lambda ENIs after function deletion.

**Fix:** Wait 20-40 minutes, then retry. If still stuck after 24 hours, open an AWS support ticket.

### Subnet too small — `InsufficientFreeAddressesInSubnet`

**Cause:** `/30` subnets are too small — AWS reserves 5 IPs, leaving 0 usable.

**Fix:** Use at least `/24` subnets.

---

## MAKE / SETUP ISSUES

### `make setup` fails with Poetry deprecation warnings

**Cause:** `pyproject.toml` uses old Poetry format (`[tool.poetry.name]` deprecated).

**Fix:** Update `pyproject.toml` to use `[project]` section format, or upgrade to UV.

### `.gitlab-deployments-ci.yml` has uncommitted changes (setup:local fails)

**Cause:** `environments.yml` was edited but `make setup-env` was not run before committing.

**Fix:** Run `make setup-env` locally, commit `.gitlab-deployments-ci.yml`, and push.

### `make plan` — `Error: Too many command line arguments`

**Cause:** Space in directory path.

**Fix:** Move repo to a path without spaces.

### Provider version mismatch / lock file

**Fix:** `make update-tf-lock` — regenerates `.terraform.lock.hcl` for all platforms.

---

## MISC / EDGE CASES

### `terraform-docs` pre-commit hook fails (Go 1.25+)

**Fix:** Pin golang version in `.pre-commit-config.yaml`:

```yaml
default_language_version:
  golang: "1.24.6"
```

### Fork relationship — MRs going to wrong project

**Fix:** Settings → General → Remove fork relationship.

### Module not published / version conflict in registry

**Cause:** Another repo with the same name already published that version.

**Fix:** Go to `Operate → Terraform Modules` in the conflicting repo and delete the published version.

### `Couldn't Determine Next Version` (semantic-release)

**Fix:** Manually create a version tag (e.g., `0.0.1`) via GitLab UI → Repository → Tags.

### `department` variable not being passed

**Cause:** `defaults.auto.tfvars` missing or `department` not set.

**Fix:** Add `department = "your-dept"` to `terraform/defaults.auto.tfvars`.

### `DEPLOYMENT_RESOURCE_GROUP` — pipeline stuck waiting

**Cause:** A previous pipeline is holding the resource group lock.

**Fix:**

1. Check `Operate → Environments` for active deployments
2. Cancel any stuck pipelines
3. Retry

### Python lint/test jobs not running

**Cause:** Disabled by default.

**Fix:** Add to `.gitlab-ci.yml`:

```yaml
variables:
  PYTHON_LINT_DISABLED: "false"
  PYTHON_TEST_DISABLED: "false"
```

### `OPTS_CHECKOV_STATIC_SCAN` in Makefile not working

**Cause:** Makefile variables are not shell variables — they don't automatically become environment variables.

**Fix:** Use `export`:

```makefile
export OPTS_CHECKOV_STATIC_SCAN := "--skip-path tests"
```

### `Error: creating CloudWatch Logs Log Group, The specified log group already exists`

**Cause:** Log group already exists (from a previous deploy or destroy). Lambda module creates log groups by default.

**Fix:** Use `use_existing_cloudwatch_log_group = true` in the Lambda module, or import the existing log group into state.

### `Provider produced inconsistent final plan`

**Cause:** Bug in the AWS provider version.

**Fix:** Try a different AWS provider version in `versions.tf`. Check the provider changelog for known bugs.

### `IAM Role already exists` during deploy

**Cause:** Terraform state is out of sync — resource exists in AWS but not in state.

**Fix:** Either import the resource into state, rename it slightly to avoid the clash, or delete the orphaned resource from AWS console.

### `Error: Module output value precondition failed — department cannot be null`

**Cause:** `department` variable is empty. Check `defaults.auto.tfvars`.

**Fix:** Set `department = "your-dept"` in `terraform/defaults.auto.tfvars`.
