# CCP Next Terraform Deployment Standards

## Overview

These IaC deployment rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when generating, reviewing, or modifying Terraform deployment projects on the CCP Next platform. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking IaC Deployment Finding Behavior

A **blocking IaC deployment finding** means:
1. The finding MUST be listed in the stage completion message under an "IaC Deployment Findings" section with the IAC-DEPLOY rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the IAC-DEPLOY rule ID, description, and stage context

If an IAC-DEPLOY rule is not applicable to the current project (e.g., IAC-DEPLOY-10 when no Lambda functions exist), mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking IaC deployment finding — follow the blocking finding behavior defined above.

### Partial Enforcement Mode

If the user selected **Partial** enforcement during opt-in, only rules IAC-DEPLOY-01 through IAC-DEPLOY-05 are enforced as blocking. All other rules (IAC-DEPLOY-06 through IAC-DEPLOY-19) are treated as advisory (non-blocking). Log the enforcement mode in `aidlc-docs/aidlc-state.md` under `## Extension Configuration`.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule IAC-DEPLOY-01: Labels Module Usage (Mandatory)

**Rule**: Every Terraform deployment project MUST use `ccp-next-labels-module` for ALL resource naming and tagging. No resource names or tags may be hardcoded.

Requirements:
- `context.tf` MUST exist under `./terraform/` — copied from the labels module exports, NEVER edited manually
- Root labels MUST be configured via `context.tf` with `module "root_labels"`
- Child labels MUST be created for specific resource groupings using `module "<resource>_labels"` with `context = module.root_labels.context`
- ALL resource names MUST use labels module outputs (e.g., `module.my_labels.id`)
- ALL resource tags MUST use labels module outputs (e.g., `module.my_labels.tags`)
- AWS provider MUST include `default_tags` block referencing `module.root_labels.tags`
- `department` MUST be set in `terraform/defaults.auto.tfvars`
- ID format follows: `{department}-{environment}-{namespace}-{name}-{attributes}`

**Verification**:
- `terraform/context.tf` exists and contains `module "root_labels"` sourced from `southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws`
- No resource has a hardcoded `name` attribute that bypasses the labels module
- No resource has a hardcoded `tags` block that bypasses the labels module
- `provider "aws"` includes a `default_tags` block with `tags = module.root_labels.tags`
- `terraform/defaults.auto.tfvars` contains a `department` value
- `context.tf` is not manually modified (it is an auto-generated export)

---

## Rule IAC-DEPLOY-02: Project Structure

**Rule**: ALL Terraform deployment code MUST live under the `./terraform/` directory following the canonical CCP Next project structure.

Required structure:
```text
terraform/
├── context.tf              # Auto-generated labels context (DO NOT EDIT)
├── main.tf                 # Module calls and data lookups
├── variables.tf            # Input variables
├── outputs.tf              # Outputs
├── provider.tf             # Provider config with default_tags
├── versions.tf             # Version constraints + S3 backend
├── defaults.auto.tfvars    # Variable defaults applied to all envs/namespaces
├── .terraform.lock.hcl     # Provider lock file (MUST be committed)
└── tfvars/
    └── <env_prefix>/
        └── <namespace>.tfvars  # Per-namespace overrides
```

Additional files for complex projects: `data.tf`, `locals.tf`, or service-specific files (`s3.tf`, `rds.tf`, `iam.tf`, `lambda.tf`).

**Verification**:
- Terraform files exist under `./terraform/`, NOT in project root or any other directory
- `.terraform.lock.hcl` is committed (not in `.gitignore`)
- `versions.tf` contains an empty `backend "s3" {}` block (never hardcoded backend values)
- `provider.tf` exists with AWS provider configuration
- `defaults.auto.tfvars` exists with at minimum `department` set
- No Terraform files exist outside `./terraform/` (excluding project config files like `.tflint.hcl`)

---

## Rule IAC-DEPLOY-03: Module Sourcing Restrictions

**Rule**: ALL Terraform modules MUST come from whitelisted sources only. Pipeline OPA policies enforce this — non-compliant sources will fail in CI.

Allowed sources (in preference order):
1. **CCP Next modules** — GitLab topic `ccp-next:module` (first choice)
2. **SWA Community modules** — GitLab topic `ccp-next:community:module` (provided "as-is")
3. **Whitelisted public registries**:
   - `terraform-aws-modules` (registry.terraform.io/namespaces/terraform-aws-modules)
   - `aws-ia` (registry.terraform.io/namespaces/aws-ia)
   - `cloudposse` (registry.terraform.io/namespaces/cloudposse)
4. **Custom modules** built from `ccp-next-module-template`

No other module namespaces or sources are allowed.

**Verification**:
- Every `module` block's `source` attribute references one of the whitelisted sources
- No module uses a source from an unapproved registry namespace
- No module uses a raw GitHub/GitLab URL outside the approved organizations
- Module version constraints are specified (not floating or unpinned)
- If a public module is used, both the module source AND its transitive provider dependencies are from approved sources

---

## Rule IAC-DEPLOY-04: Provider Constraints

**Rule**: ALL Terraform providers MUST be HashiCorp Official. New providers require a DASH request with business justification (7-day SLA).

Requirements:
- Terraform version constraint: `>= 1.7.0, < 2.0.0`
- AWS provider: `~> 6.1`
- tflint required version: `>= 0.50` with `terraform` (preset: all) and `aws` (v0.45.0) plugins
- All providers MUST be locked in `.terraform.lock.hcl`
- No community or third-party providers without DASH approval

**Verification**:
- `versions.tf` specifies `required_version = ">= 1.7.0, < 2.0.0"` for Terraform
- `versions.tf` specifies `aws` provider with `~> 6.1` constraint
- `.terraform.lock.hcl` is committed and locks all providers
- No provider source uses a non-HashiCorp namespace without documented DASH approval
- `.tflint.hcl` specifies `required_version = ">= 0.50"` with terraform and aws plugins

---

## Rule IAC-DEPLOY-05: Naming and Coding Conventions

**Rule**: ALL Terraform code MUST follow CCP Next naming conventions consistently.

| Item | Convention | Example |
|---|---|---|
| Terraform files | `snake_case.tf` | `api_gateway.tf` |
| Resources/modules | `snake_case` | `module "api_gateway"` |
| Variables | `snake_case` | `var.enable_logging` |
| Outputs | `snake_case` | `output "bucket_arn"` |
| Single resource of type | name it `this` | `resource "aws_s3_bucket" "this"` |
| AWS resource names | Hyphens, via labels | `module.labels.id` |
| Block labels | Underscores, MUST NOT repeat resource type | `resource "aws_sns_topic" "notifications"` |

Coding standards:
- All variables MUST have `description` and `type`; add `validation` blocks where practical
- All outputs MUST have `description`; use `sensitive = true` for sensitive outputs
- Use `for_each` over `count` when iterating over known sets
- Use `locals` only for reused values or complex calculations — do not overuse
- Use `precondition`/`postcondition` blocks for runtime validation where appropriate
- ALL Terraform commands go through `make` targets — never run `terraform` directly

**Verification**:
- All `.tf` filenames use `snake_case`
- All resource, module, variable, and output names use `snake_case`
- No block label repeats the resource type (e.g., `resource "aws_sns_topic" "aws_sns_topic"` is forbidden)
- Every variable has `description` and `type` defined
- Every output has `description` defined
- `for_each` is used over `count` for known sets
- Single resources of their type are named `this`

---

## Rule IAC-DEPLOY-06: Environment Configuration

**Rule**: Deployment environments MUST be configured through `environments.yml` with auto-generated pipeline configuration. NEVER manually edit `.gitlab-deployments-ci.yml`.

Requirements:
- `environments.yml` defines all namespaces grouped by environment tier (dev, qa, prod)
- Run `make setup-env` after every edit to regenerate `.gitlab-deployments-ci.yml`
- NEVER set these inputs in tfvars: `environment`, `namespace`, `region`, `repo_id`, `state_bucket`, `state_key` — the platform injects them automatically
- NEVER hardcode AWS account IDs, regions, or environment names
- Per-namespace variable overrides go in `environments.yml`, not in `.gitlab-ci.yml`
- `AUTO_DEV_APPLY: true` should be set per-namespace (not globally) to avoid affecting other namespaces
- `DEPLOYMENT_RESOURCE_GROUP: ${NAMESPACE}` controls deployment ordering for concurrent namespace deployments

**Verification**:
- `environments.yml` exists at project root with proper structure
- `.gitlab-deployments-ci.yml` is not manually edited (it is auto-generated)
- No tfvars file contains `environment`, `namespace`, `region`, `repo_id`, `state_bucket`, or `state_key`
- No hardcoded AWS account IDs in Terraform files or tfvars
- No hardcoded region strings in Terraform files (use `var.region`)
- `AUTO_DEV_APPLY` is set per-namespace, not at the global level

---

## Rule IAC-DEPLOY-07: Checkov Security Scanning Compliance

**Rule**: ALL generated Terraform code MUST pass Checkov static and dynamic scans. Code MUST be generated following patterns that satisfy Checkov checks by default.

Required patterns:
- **S3 buckets**: Enable versioning, SSE-KMS encryption, block public access, enable access logging
- **SQS queues**: Enable encryption (`sqs_managed_sse_enabled = true`), configure dead-letter queue with `redrive_policy`
- **Security groups**: Never use `0.0.0.0/0` for ingress; use specific CIDR blocks
- **IAM**: Least-privilege policies, no wildcard actions/resources, no inline policies
- **Encryption**: Enable at-rest encryption for all data stores (RDS, DynamoDB, EBS, S3, SQS, SNS)
- **Logging**: Enable CloudTrail, VPC Flow Logs, S3 access logging where applicable
- **Tags**: Always use labels module tags (covers required tag checks)

Suppression requires CloudSec exemption from `#team-cloudsecurity` Slack channel. Pipeline enforcement: hard-fail on CRITICAL/HIGH, soft-fail on MEDIUM.

**Verification**:
- S3 bucket resources include versioning, encryption, public access block, and logging configuration
- SQS queue resources include encryption and dead-letter queue configuration
- No security group has inbound `0.0.0.0/0` on any port except 80/443 on a public load balancer
- IAM policies do not use wildcard actions (`*`) or wildcard resources (`*`) without documented exception
- All data stores have encryption at rest enabled
- Checkov skip comments (`#checkov:skip=`) include a justification and documented CloudSec exemption reference
- `--download-external-modules true` is retained in any scan option overrides

---

## Rule IAC-DEPLOY-08: Pipeline and Versioning

**Rule**: Deployment projects MUST follow CCP Next pipeline and versioning conventions for consistent, traceable releases.

Requirements:
- Include `ccp-next-pipeline-fragments` at a pinned ref version in `.gitlab-ci.yml`
- Semantic-release `tagFormat` uses `${version}` (no `v` prefix) — tags are `1.0.0`, not `v1.0.0`
- Start `version` at `0.0.0` in both `package.json` and `pyproject.toml`
- Commit message format drives versioning: `fix:` → PATCH, `feat:` → MINOR, `BREAKING CHANGE:` → MAJOR
- `make deploy` and `make destroy` are local-only targets — they error out in CI pipelines
- Deployments from pipelines can only be triggered from semver tags or `<NAMESPACE>_current` tags
- Production destroy requires manual confirmation

**Verification**:
- `.gitlab-ci.yml` includes `ccp-next-pipeline-fragments` with a pinned version ref
- `release.config.js` uses `tagFormat: "${version}"` (no `v` prefix)
- `package.json` starts at version `0.0.0` for new projects
- `pyproject.toml` starts at version `0.0.0` for new projects
- No pipeline configuration allows direct deploy to production without approval gates
- Commit messages follow conventional commit format with JIRA ticket references

---

## Rule IAC-DEPLOY-09: Cross-Repo References and State

**Rule**: Cross-repo infrastructure references MUST use AWS data sources with CCP Next tag filters or SSM Parameter Store. NEVER use `terraform_remote_state` data sources.

Requirements:
- State is scoped per-repo — each deployment manages its own state
- Cross-repo lookups use `data "aws_*"` blocks with CCP Next tag filters (preferred) or `data "aws_ssm_parameter"` (alternative)
- Backend block MUST be empty: `backend "s3" {}` — platform injects all values
- State bucket naming: `swa-ec-tf-state-${AWS_ACCOUNT_NUMBER}-${REGION}`
- Local state uses separate namespace: `local-${USER}-${NAMESPACE}` to prevent pipeline collision
- Document deploy-order dependencies between repos

**Verification**:
- No `terraform_remote_state` data source exists in the codebase
- Cross-repo references use `data "aws_vpc"`, `data "aws_subnets"`, or `data "aws_ssm_parameter"` with tag filters
- Backend block is empty (`backend "s3" {}`) with no hardcoded values
- No state bucket names or state key paths are hardcoded
- Deploy-order dependencies are documented when they exist

---

## Rule IAC-DEPLOY-10: Lambda Source Code Structure

**Rule**: Lambda function source code MUST follow CCP Next conventions for packaging and deployment.

Requirements:
- Source code lives under `src/` at the project root (NOT under `terraform/`)
- Single Lambda: `src/handler.js` (or `handler.py`) with package manifest
- Multiple Lambdas: Each gets its own subdirectory (`src/processor/`, `src/notifier/`)
- Each Lambda module MUST have a unique `source_path` — never point two modules at the same source directory
- Shared code goes in a Lambda layer (`src/shared/`)
- Python: use `prefix_in_zip = "src"` and per-Lambda `pyproject.toml` for function-specific dependencies
- Node.js: use esbuild or webpack bundling commands in `source_path`

**Verification**:
- Lambda source code is under `src/`, not under `terraform/`
- Each Lambda function has its own subdirectory when multiple exist
- No two Lambda module blocks reference the same `source_path`
- Shared code is in a layer directory, not duplicated across functions
- Lambda source has its own package manifest for dependencies

---

## Rule IAC-DEPLOY-11: SRE Lambda Naming

**Rule**: Lambda functions invoked directly for operational tasks MUST follow SRE naming conventions.

Requirements:
- Function names MUST be prefixed with `SRE-` to be invocable in QA/PROD environments
- Use labels module with `SRE-` prefix: `function_name = "SRE-${module.sre_labels.id}"`
- No VPC required for SRE functions
- QA/PROD invocation requires assuming `SWACSOperations` role first
- Document invocation patterns (sync, async, dry-run) in the project README

**Verification**:
- SRE Lambda function names include the `SRE-` prefix via labels module
- SRE function documentation includes role assumption instructions for QA/PROD
- Invocation examples cover sync, async, and dry-run patterns where applicable
- SRE functions do not require VPC unless explicitly justified

---

## Rule IAC-DEPLOY-12: CloudWatch and DASH Integration

**Rule**: Alarm monitoring MUST reference DASH SNS topics via `data` blocks — NEVER use variables with placeholder ARNs.

Requirements:
- Use `data "aws_sns_topic"` to look up DASH topics by name: `DASH-Low`, `DASH-Medium`, `DASH-High`
- Alarm names and tags MUST use labels module outputs
- Alarms MUST include: `alarm_description`, `dimensions`, and appropriate `alarm_actions`
- If DASH SNS topics are not present, escalate via `##help-aws-dash-incident-integration` Slack channel

**Verification**:
- CloudWatch alarms reference DASH topics via `data "aws_sns_topic"` blocks, not variable placeholders
- Alarm resources use labels module for `alarm_name` and `tags`
- Every alarm has an `alarm_description` explaining what it monitors
- No alarm uses a hardcoded SNS topic ARN

---

## Rule IAC-DEPLOY-13: Blast Radius Architecture

**Rule**: Infrastructure repos MUST be structured by blast radius (impact of failure) and touch level (frequency of change).

Requirements:
- **Low touch, high blast radius** (VPCs, networking, shared IAM): separate repo, infrequent changes
- **High touch, low blast radius** (Lambdas, app config): separate repo, frequent deploys
- **Medium touch, medium blast radius** (databases, queues, storage): separate repo per domain
- Each repo deploys independently with its own `environments.yml`, state, and pipeline
- Cross-repo references use AWS data sources (see IAC-DEPLOY-09)
- Document deploy-order dependencies between repos

**Verification**:
- Infrastructure is not monolithically deployed from a single repo covering all resource types
- High-risk shared resources (VPC, IAM) are separated from high-frequency application resources
- Each repo has its own independent state and pipeline
- Cross-repo dependencies are documented

---

## Rule IAC-DEPLOY-14: Required AWS Provider default_tags Keys

**Rule**: The AWS provider block MUST define `default_tags` containing ALL 7 required CCP Next tag keys. Missing any key will trigger a pipeline failure via the tagging OPA policy.

Required tag keys:
- `CCPNamespace` — deployment namespace
- `SWA:Name` — resource name following SWA conventions
- `SWA:RepoId` — SWA repository identifier
- `SWA:DashApplicationService` — DASH application service identifier (ServiceNow UUID)
- `EnvPrefix` — environment identifier (`lab`, `dev`, `qa`, `prod`)
- `TFStateBucket` — Terraform state bucket name
- `TFStateKey` — Terraform state file key

Compliant pattern:
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      CCPNamespace                = var.namespace
      "SWA:Name"                  = var.namespace
      "SWA:RepoId"                = var.repo_id
      "SWA:DashApplicationService" = var.dash_application_service
      EnvPrefix                   = var.env_prefix
      TFStateBucket               = var.tf_state_bucket
      TFStateKey                  = var.tf_state_key
    }
  }
}
```

Dynamic `"references"` expressions in the tags block are allowed by the OPA policy.

**Verification**:
- AWS provider `default_tags` block contains all 7 required keys: `CCPNamespace`, `SWA:Name`, `SWA:RepoId`, `SWA:DashApplicationService`, `EnvPrefix`, `TFStateBucket`, `TFStateKey`
- Tag values reference variables (not hardcoded strings)
- No required tag key is missing from the `default_tags` block

---

## Rule IAC-DEPLOY-15: conftest for IaC OPA Scanning

**Rule**: CCP Next uses `conftest` (not `opa` directly) for IaC reliability scanning. The Makefile target is `ccp-iac-scan`. The pipeline job is `<env>_<namespace>_ccp_iac_scan`. OPA policies are cloned from `ccp-next-opa-policies` at a pinned tag.

Requirements:
- `ccp-iac-scan` Makefile target runs `conftest test` against the Terraform plan JSON output
- OPA policies are sourced from `ccp-next-opa-policies` at a pinned tag (`CCP_NEXT_IAC_POLICIES_TAG`)
- `CHECKOV_API_KEY_CCP_NEXT` is configured in CI/CD for Prisma Cloud integration
- No `--soft-fail` or `--skip-check` overrides exist without documented Cloud Security exemptions

Compliant:
```makefile
ccp-iac-scan:
    conftest test --policy ccp-next-opa-policies/policies tfplan-$(ENV)-checkov.json
```

Non-compliant:
```makefile
ccp-iac-scan:
    opa eval --data ccp-next-opa-policies/policies ...  # use conftest, not opa
```

**Verification**:
- `ccp-iac-scan` Makefile target uses `conftest test`, not `opa eval`
- `CCP_NEXT_IAC_POLICIES_TAG` is defined and pinned to a specific version
- No `--soft-fail` or `--skip-check` overrides exist without documented exemptions
- `CHECKOV_API_KEY_CCP_NEXT` is referenced in CI/CD configuration

---

## Rule IAC-DEPLOY-16: SWA Module Enforcement

**Rule**: Certain AWS resources MUST use the corresponding SWA CCP Next module instead of being hand-rolled. Raw usage of these resource types is flagged by OPA policies and MR reviews.

| Raw Resource Types | Required Module |
|---|---|
| `aws_vpc`, `aws_subnet`, `aws_nat_gateway`, `aws_route_table`, `aws_network_acl` | `ccp-next-vpc-module` |
| `aws_wafv2_web_acl`, `aws_wafv2_rule_group` | `ccp-next-waf-module` |
| `aws_api_gateway_rest_api`, `aws_apigatewayv2_api` | `ccp-next-api-gateway-module` |
| `aws_api_gateway_domain_name`, `aws_apigatewayv2_domain_name` | `ccp-next-custom-domain-module` |
| `aws_route53_zone` (private) | `ccp-next-private-hz-module` |

If a project has a documented exception (e.g., migration in progress), note it as advisory rather than blocking.

**Verification**:
- No raw VPC resources (`aws_vpc`, `aws_subnet`, `aws_nat_gateway`, `aws_route_table`, `aws_network_acl`) without `ccp-next-vpc-module`
- No raw WAF resources (`aws_wafv2_web_acl`, `aws_wafv2_rule_group`) without `ccp-next-waf-module`
- No raw API Gateway resources without the corresponding CCP Next API Gateway or Custom Domain module
- No raw private Route53 zones without `ccp-next-private-hz-module`
- Documented exceptions are noted in the compliance summary

---

## Rule IAC-DEPLOY-17: UV Package Manager Requirement

**Rule**: CCP Next projects MUST use UV as the Python package manager (not Poetry). `pyproject.toml` must use `[project]` and `[dependency-groups]` sections with `[tool.uv]` configuration. `uv.lock` must exist. `poetry.lock` must NOT be committed.

Required pyproject.toml structure:
```toml
[project]
name = "your-project"
version = "1.0.0"
requires-python = ">=3.12,<4.0"
dependencies = ["ccp-next-general-resources>=2.5.0,<3.0"]

[dependency-groups]
dev = ["pre-commit>=4.3.0,<5", "pytest>=8.4.2,<9"]

[tool.uv]
index-url = "https://nexus-tools.swacorp.com/repository/all-pypi/simple"
native-tls = true
package = false
```

Requirements:
- `pyproject.toml` uses `[project]` section (not `[tool.poetry]`)
- `[tool.uv]` section is configured with `native-tls = true` and `package = false`
- `uv.lock` exists and is committed
- `poetry.lock` does NOT exist in the repository
- Version constraints use `>=x.y.z,<next-major` format (not Poetry's `^x.y.z` caret syntax)
- `[[tool.uv.index]]` entries configured for SWA Nexus repositories

**Verification**:
- `pyproject.toml` uses `[project]` section (not `[tool.poetry]`)
- `[tool.uv]` section is present with `native-tls = true` and `package = false`
- `uv.lock` exists in the repository
- No `poetry.lock` file exists in the repository
- No `[tool.poetry]` or `[tool.poetry.dependencies]` sections exist in `pyproject.toml`
- Version constraints use `>=x.y.z,<next-major` format

---

## Rule IAC-DEPLOY-18: Commit Message and Branch Conventions

**Rule**: Commit messages MUST follow conventional commit format. Branch names MUST follow CCP Next branch naming conventions. These conventions drive semantic-release versioning and pipeline behavior.

Commit message format:
```
^((build|chore|ci|docs|feat|fix|refactor|revert|style|test)(\(\w+.*\))?(: )((.*\s*)*))|^(Notes added by 'git notes add')|(Initial [Cc]ommit$)
```

Branch name format:
```
^(chore|ci|docs|feat|fix|maint|refactor|renovate|test)\/.*|(dev|development|master)$
```

Requirements:
- All commits follow conventional commit format with a type prefix
- `fix:` → PATCH release, `feat:` → MINOR release, `BREAKING CHANGE:` in body → MAJOR release
- `chore:`, `docs:`, `ci:` do NOT trigger a release
- Branch names use the pattern `<type>/<description>` (e.g., `feat/add-lambda`, `fix/state-lock`)
- Protected branches: `dev`, `development`, `master`

**Verification**:
- Commit messages follow conventional commit format with valid type prefixes
- Branch names follow the `<type>/<description>` pattern or are protected branch names
- No commits exist without a recognized type prefix (except initial commits)
- JIRA ticket references are included where applicable

---

## Rule IAC-DEPLOY-19: Terraform State Backend and .gitignore

**Rule**: All Terraform deployment projects MUST use S3 as the remote backend with an empty backend block. State files MUST NOT be committed. The `.gitignore` MUST exclude state files and plan outputs. The `assert-remote-backend` Makefile target MUST be present.

Requirements:
- `versions.tf` contains `backend "s3" {}` (empty — platform injects all values)
- State bucket naming follows: `swa-ec-tf-state-<AWS_ACCOUNT_NUMBER>-<REGION>`
- State key follows: `<CI_PROJECT_NAMESPACE>/<CI_PROJECT_NAME>/<NAMESPACE>/terraform.tfstate`
- Backend is initialized with `encrypt=true` and `use_lockfile=true`
- `assert-remote-backend` Makefile target is present and called before `deploy`
- `.gitignore` excludes: `*.tfstate`, `*.tfstate.backup`, `.terraform/`, `*-plan.out`, `*-plan-checkov.json`

**Verification**:
- `versions.tf` contains an empty `backend "s3" {}` block with no hardcoded values
- No `terraform.tfstate` or `terraform.tfstate.backup` files are committed
- `.gitignore` excludes `*.tfstate`, `*.tfstate.backup`, `.terraform/`, `*-plan.out`, and `*-plan-checkov.json`
- `assert-remote-backend` Makefile target exists
- No state bucket names or keys are hardcoded in Terraform files

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Requirements Analysis | IAC-DEPLOY-06, IAC-DEPLOY-13 | Environment and architecture decisions must be captured |
| Application Design | IAC-DEPLOY-03, IAC-DEPLOY-13, IAC-DEPLOY-16 | Module selection and blast radius architecture |
| Infrastructure Design | ALL | All rules apply to infrastructure design artifacts |
| Code Generation (Planning) | ALL | Code generation plan must address all applicable rules |
| Code Generation (Generation) | IAC-DEPLOY-01 through IAC-DEPLOY-19 | Generated code must comply with all rules |
| Build and Test | IAC-DEPLOY-04, IAC-DEPLOY-07, IAC-DEPLOY-08, IAC-DEPLOY-15, IAC-DEPLOY-19 | Validation, scanning, and pipeline instructions |

At each applicable stage:
- Evaluate all IAC-DEPLOY rule verification criteria against the artifacts produced
- Include an "IaC Deployment Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking IaC deployment finding — follow the blocking finding behavior defined in the Overview
- Include IAC-DEPLOY rule references in design documentation and code comments where clarification is needed
