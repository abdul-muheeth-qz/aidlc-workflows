# Shared CCP Next Review Checks

These checks apply to ALL CCP Next MR reviews (Lambda, Module, and Deployment). Run every check in this section regardless of project type. Complete all shared checks before moving to project-type-specific checks.

## 1. CCP Next Convention Checks

Apply the conventions defined in `references/ccp-next-conventions.md`. Inspect every `.tf` file in the MR diff and flag violations. Specifically flag:

- Block labels using hyphens instead of underscores
- Block labels that repeat the resource type
- Single resources of a type not named `"this"` without justification
- AWS resources missing Labels_Module usage (`module.root_labels.id` or any module sourced from `southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws` for names, and their `.tags` output for tags)
- AWS provider `default_tags` missing any required CCP Next tag keys (dynamic `"references"` expressions are acceptable)
- Variables missing `description` or `type` attributes
- Outputs missing `description` attributes
- Sensitive outputs missing `sensitive = true`

## 2. OPA Policy Checks

The CCP Next pipeline enforces OPA policies via `conftest`. Catch violations before the pipeline runs by checking the MR diff against the current policies.

**IMPORTANT — Fetch current policies**: Before running OPA checks, use the GitLab MCP to fetch the current rego policy files from the authoritative source repo:

- **Repository**: `swa-common/devplat/ccp-next/ccp-next-opa-policies`
- **Policy directory**: `policies/ccp/`
- Use `search` with scope `blobs` and project_id `swa-common/devplat/ccp-next/ccp-next-opa-policies` to find the policy files, or use `get_merge_request_diffs` patterns to read file contents from the default branch.
- Fetch these specific files:
  - `policies/ccp/tagging_policy/tagging_policy.rego` — required tag keys
  - `policies/ccp/providers_policy/providers_policy.rego` — approved providers list
  - `policies/ccp/module_source_policy/module_source_policy.rego` — approved module sources
  - `policies/ccp/lambda_runtime_policy/lambda_runtime_policy.rego` — deprecated Lambda runtimes (Lambda skill only)

Extract the approved/required lists directly from the rego files. Do NOT rely on hardcoded lists in this document — the rego files are the single source of truth and may be updated independently.

**Tagging policy** (source: `tagging_policy.rego`):

Read the `required_tag_keys` list from the rego file. The AWS provider `default_tags` block must include ALL tag keys defined in that list. Dynamic `"references"` expressions in the tags block are allowed by the OPA policy and should not be flagged. Flag missing required tag keys.

**Providers policy** (source: `providers_policy.rego`):

Read the `approved_providers` list from the rego file. Only providers on that list may be used. Flag any provider not on the approved list. Check `required_providers` blocks and any provider configurations in the diff.

**Module source policy** (source: `module_source_policy.rego`):

Read the `approved_git_sources` and `approved_registry_namespaces` lists from the rego file. Module sources must match an approved git source prefix or registry namespace. Check BOTH top-level and nested module sources. Flag any module source that does not match.

If the GitLab MCP cannot reach the OPA policies repo (e.g., authentication issue, repo not accessible), fall back to the lists documented in `references/ccp-next-conventions.md` and note in the review that the policy lists could not be verified against the latest source.

## 3. Checkov Compliance Checks

Check the MR diff for common Checkov compliance violations. These mirror the checks the CCP Next pipeline runs via Checkov scans.

- **S3 buckets**: Verify that `aws_s3_bucket` resources have:
  - Versioning enabled (via `aws_s3_bucket_versioning` or inline `versioning` block)
  - SSE-KMS encryption configured (via `aws_s3_bucket_server_side_encryption_configuration` with `aws:kms` or KMS key)
  - Public access blocked — apply the following logic:
    - **Raw `aws_s3_bucket` resources**: Flag if there is no accompanying `aws_s3_bucket_public_access_block` resource with all four settings (`block_public_acls`, `block_public_policy`, `ignore_public_acls`, `restrict_public_buckets`) set to `true`.
    - **S3 module usage** (e.g., `terraform-aws-modules/s3-bucket/aws` or CCP Next S3 modules): Do NOT flag the absence of an explicit `aws_s3_bucket_public_access_block` resource — these modules default all four public access block settings to `true`. Only flag if the module call explicitly sets any of the four public access block arguments to `false` (e.g., `block_public_acls = false`).
    - The goal is to catch genuinely missing or disabled public access blocking, not to flag module defaults that already enforce it.
  - Logging configured (via `aws_s3_bucket_logging` or inline `logging` block)
  - Flag missing configurations.

- **No inline IAM policies**: Flag any use of `aws_iam_group_policy`, `aws_iam_role_policy`, or `aws_iam_user_policy` (inline policies). Recommend using `aws_iam_policy` with `aws_iam_role_policy_attachment` instead. Flag.

- **Encryption at rest**: Verify that data store resources have encryption configured:
  - RDS: `storage_encrypted = true` or KMS key specified
  - DynamoDB: `server_side_encryption` block with `enabled = true`
  - EBS volumes: `encrypted = true`
  - SQS: `kms_master_key_id` or `sqs_managed_sse_enabled = true`
  - SNS: `kms_master_key_id` specified
  - Flag missing encryption.

- **Security group rules**: Check `aws_security_group` and `aws_security_group_rule` resources against the denied CIDR list (`0.0.0.0/0`, `::/0`):
  - Ingress rules with denied CIDRs on non-standard ports (anything other than 80 and 443) → flag
  - Ingress rules with denied CIDRs on ports 80/443 → flag (may be intentional for public ALB or CloudFront)
  - Egress rules with denied CIDRs → flag (unless attached to a NAT gateway or explicitly documented)
  - Documented exceptions: public ALB security groups, CloudFront-facing resources, NAT gateway egress

- **IAM least-privilege**: Flag IAM policy documents (`aws_iam_policy`, `aws_iam_role_policy`, data sources) that use:
  - Wildcard actions (`"Action": "*"` or `"Action": ["*"]`)
  - Wildcard resources (`"Resource": "*"` or `"Resource": ["*"]`)
  - Flag.

## 4. SWA Module Enforcement and Networking Safety

CCP Next provides opinionated SWA modules for common infrastructure patterns. Flag hand-rolled resources that should use these modules.

| Raw resource types | Recommended module |
| --- | --- |
| `aws_vpc`, `aws_subnet`, `aws_nat_gateway`, `aws_route_table`, `aws_network_acl` | `ccp-next-vpc-module` |
| `aws_wafv2_web_acl`, `aws_wafv2_rule_group` | `ccp-next-waf-module` |
| `aws_api_gateway_rest_api`, `aws_apigatewayv2_api` | `ccp-next-api-gateway-module` |
| `aws_api_gateway_domain_name`, `aws_apigatewayv2_domain_name` | `ccp-next-custom-domain-module` |
| `aws_route53_zone` (when configured as a private zone) | `ccp-next-private-hz-module` |

Flag any of these raw resources and recommend the corresponding SWA module.

**WAF association check**: Flag any web-facing resource (`aws_lb` with `internal = false`, `aws_api_gateway_rest_api`, `aws_apigatewayv2_api`, `aws_cloudfront_distribution`) that does not have an associated WAF web ACL (`aws_wafv2_web_acl_association` or `web_acl_id` attribute). Flag.

**Security group denied CIDR logic**:

Denied CIDRs: `0.0.0.0/0`, `::/0`

- **Ingress** on non-standard ports (anything other than 80 and 443) with denied CIDRs → **flag**, unless the resource is explicitly documented as requiring broad access
- **Ingress** on ports 80/443 with denied CIDRs → **flag** (acknowledge may be intentional for public ALB or CloudFront)
- **Egress** with denied CIDRs → **flag**, unless attached to a NAT gateway or explicitly documented as an exception

## 5. Security Review

Security findings are the highest priority category. Flag these issues above all other categories in the review output.

- **Hardcoded secrets**: Flag any hardcoded secrets, tokens, credentials, API keys, passwords, or AWS account IDs found in the MR diff. Look for patterns like `AKIA`, `sk-`, `password =`, `secret =`, `token =`, `credential =`, and 12-digit numeric strings that look like AWS account IDs. Flag.
- **Overly permissive IAM**: Flag IAM policies with wildcard actions (`"*"`) or wildcard resources (`"*"`). Recommend scoping to specific actions and resource ARNs. Flag.
- **Missing encryption**: Flag any data store resource (S3, RDS, DynamoDB, EBS, SQS, SNS) that does not have encryption configured with KMS or service-managed encryption. Flag.
- **Broad security group rules**: Apply the denied CIDR logic from section 4. Flag security groups with overly broad ingress or egress rules using `0.0.0.0/0` or `::/0`. Check for unjustified open port ranges. Respect documented exceptions for public-facing resources (public ALB, CloudFront, NAT gateway).
- **Sensitive outputs**: Flag any `output` block that exposes sensitive data (passwords, tokens, keys, connection strings, database endpoints with credentials) without setting `sensitive = true`. Flag.
- **Unapproved providers/modules**: Flag any provider or module source that is not on the approved lists from section 2. Flag.

## 6. Code Quality Review

- **Naming**: Flag unclear or misleading resource, variable, and local names that do not convey purpose. Flag.
- **Code duplication**: Flag duplicated code across files. Recommend extracting shared logic into modules or locals. Flag.
- **Dead code**: Flag unused variables, locals, or data sources that are defined but never referenced. Flag.
- **Complex expressions**: Flag overly complex expressions or deeply nested conditionals that reduce readability. Recommend simplifying with locals or breaking into smaller expressions. Flag.
- **Missing descriptions**: Flag variables without `description` attributes and outputs without `description` attributes. Flag.
- **for_each over count**: When iterating over a known set of items, recommend `for_each` instead of `count`. `for_each` produces stable resource addresses and avoids index-shift issues when items are added or removed. Flag `count` usage on known sets.
- **Sentinel default with validation anti-pattern**: Flag variables that use a placeholder default value combined with a validation block that rejects that default. This is a roundabout way of making a variable required. If a variable must be provided by the caller, omit the `default` entirely — Terraform will enforce it at plan time. Flag.

## 7. Performance Review

- **Unnecessary depends_on**: Flag `depends_on` arguments that create artificial ordering bottlenecks where Terraform can already infer the dependency from resource references. Recommend removing unnecessary `depends_on` to allow parallel execution. Flag.
- **Missing lifecycle blocks**: Flag resources that would benefit from `create_before_destroy = true` for zero-downtime deployments (e.g., security groups, launch templates, target groups). Flag.
- **Redundant data source lookups**: Flag repeated `data` source lookups for the same resource across multiple files or modules. Recommend sharing the result via locals, variables, or dependency outputs. Flag.
- **Resources needing modularization**: Flag groups of resources that are repeated and should be extracted into a reusable module. Flag.

## 8. Architecture Review

- **Multi-repo pattern violations**: Flag cases where lifecycle concerns are mixed (e.g., VPCs, subnets, and route tables in the same state file as application resources). Recommend separating foundational networking by lifecycle and change frequency. Note: application-specific security groups (e.g., for Lambda VPC attachment) are acceptable in the same repo as the application — only shared/foundational networking should be separated. Flag.
- **Tight coupling**: Flag tight coupling between modules or projects (e.g., direct resource references across projects instead of using outputs/data sources/remote state). Flag.
- **Missing or incorrect Labels_Module**: Flag AWS resources that do not use a valid labels module for names and tags. Valid labels module references include `module.root_labels.id` / `module.root_labels.tags` or the `.id` / `.tags` output of any module whose source is `southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws`. A repo may have multiple labels module instances for different resources — this is expected. Flag resources with hardcoded names or tags that bypass the labels module entirely. Flag.
- **Environment drift**: Flag configuration differences between environments (lab, dev, qa, prod) that lack explicit justification. Intentional differences (instance sizes, replica counts) following a clear scaling pattern are acceptable. Flag unjustified drift.
- **Breaking interface changes**: Flag changes that rename or remove variables, outputs, resources, or fields from variable object types that may be consumed by other repositories or tiers. Detect these specific patterns in the MR diff:

  - **Removed variables**: A `variable` block name appears in removed lines but not in added lines. Flag.
  - **Renamed variables**: A `variable` block name appears in removed lines and a different name appears in added lines with similar attributes. Flag.
  - **Removed outputs**: An `output` block name appears in removed lines but not in added lines. Flag.
  - **Renamed outputs**: An `output` block name appears in removed lines and a different name appears in added lines with a similar value expression. Flag.
  - **Removed resources that consumers depend on**: A `resource` block is removed without a corresponding `removed` block (Terraform 1.7+). Flag and recommend adding a `removed` block with `destroy = false`.
  - **Removed fields from variable object types**: A field is removed from an `object({...})` type definition inside a `variable` block. Flag.

  When ANY breaking change is detected, also produce a consolidated summary finding with:
  - `category: "Architecture"`
  - Title: `Breaking changes detected — major version bump required`
  - A list of all breaking changes found
  - A recommendation to bump the major version (e.g., `v1.x.x` → `v2.0.0`)
  - A recommendation to use a breaking change commit message (`feat!:` prefix or `BREAKING CHANGE:` footer)
  - A recommendation to document the migration path in the MR description and CHANGELOG
  - A recommendation to coordinate with downstream consumers before merging
  - For removed resources, recommend adding `removed` blocks with `destroy = false` to prevent state destruction

## 9. Terraform Import Warning

- **Warning**: Produce a warning about dual-control risks. Terraform import brings existing resources under Terraform state management, but if those resources were originally created by CloudFormation (or another IaC tool), both tools may attempt to manage the same resource, leading to conflicts and drift.
- **Recommendation**: Recommend the blue-green migration pattern — create new resources with Terraform alongside the existing ones, migrate traffic/references, then decommission the old resources.
- **Exceptions**: Note that exceptions exist for large S3 buckets and databases where recreation is impractical or would cause data loss. In these cases, import is acceptable but should be carefully coordinated with the team that owns the original resource.

Flag.

## 10. Version Constraints

Verify Terraform and provider version constraints in the MR diff.

- **Terraform version**: The `required_version` constraint in the `terraform` block MUST use a bounded range with both a lower bound (`>=`) and an upper bound (`<`). For example, `>= 1.7.0, < 2.0.0` is valid. The specific version numbers may change over time — what matters is that both bounds are present. Flag if:
  - The `required_version` is missing entirely
  - Only a lower bound is specified without an upper bound (e.g., `>= 1.7.0` alone)
  - Only an upper bound is specified without a lower bound
  - An exact version pin is used (e.g., `= 1.7.0`) instead of a range
  - No version constraint is defined at all

- **AWS provider version**: The AWS provider version constraint in `required_providers` MUST use a lower-bounded constraint (`>=`). For example, `>= 6.0` or `~> 6.1` are both valid. The specific version number may change — what matters is that a minimum version is enforced. Flag if:
  - The AWS provider version constraint is missing entirely
  - An exact version pin is used (e.g., `= 6.1.0`) instead of a range
  - No version constraint is defined for the AWS provider

## 11. Commit Message and Branch Name Validation

Verify that commit messages and branch names follow CCP Next conventions.

**Commit message validation**: Each commit message in the MR MUST match the following regex pattern:

```text
^((build|chore|ci|docs|feat|fix|refactor|revert|style|test)(\(\w+.*\))?(: )((.*\s*)*))|^(Notes added by 'git notes add')|(Initial [Cc]ommit$)|^((chore|feat|fix)\(deps\):(.*\s*)*)|^Revert ".*"\nThis reverts commit .*
```

This enforces conventional commit format (e.g., `feat: add new resource`, `fix(networking): correct CIDR block`, `chore(deps): update provider`). Flag non-conforming commit messages, identifying the specific commit and the expected format.

**Branch name validation**: The MR source branch name MUST match the following regex pattern:

```text
^(chore|ci|docs|feat|fix|maint|refactor|renovate|test)\/.*|(dev|development|master)$
```

This enforces branch naming like `feat/add-lambda`, `fix/handler-path`, `chore/update-deps`. Flag non-conforming branch names, identifying the branch name and the expected format.

## 12. README Validation

Verify that the project has a meaningful README.

- **README exists**: Check that a `README.md` file exists in the project root. If the MR diff does not include a README and no README is referenced in the project, flag.
- **Default template detection**: Flag a `README.md` that appears to be a default template — for example, containing only boilerplate headings (like "# Project Name", "## Getting Started", "## Prerequisites") with no project-specific content filled in. Flag.
- **Content relevance**: Flag a `README.md` that does not reflect the actual project purpose, usage, or configuration. Flag.

## 13. Project Structure Validation

Verify that the project root contains required CCP Next project management files.

- **Missing pyproject.toml**: Flag if no `pyproject.toml` file exists at the project root. CCP Next projects use `pyproject.toml` for Python dependency and project management (pre-commit, linting, build tooling). Flag.

- **Missing lock file**: Flag if neither `uv.lock` nor `poetry.lock` exists at the project root alongside `pyproject.toml`. A lock file ensures reproducible dependency resolution. Flag.

## 14. Public Module Reuse Check

Before writing custom Terraform modules or deploying basic resources with hand-rolled configurations, check whether a suitable public module already exists on the [Terraform Registry](https://registry.terraform.io/). Reusing well-maintained community or official modules reduces code to maintain, provides battle-tested defaults, and accelerates delivery.

- **Hand-rolled resources that have public module equivalents**: When the MR introduces new resources that could be replaced by a public Terraform Registry module from an approved namespace (see section 2 — module source policy), recommend that the author search the registry first. Common examples include:
  - ALB/NLB setups (`aws_lb`, `aws_lb_listener`, `aws_lb_target_group`) — consider `terraform-aws-modules/alb/aws`
  - RDS instances or clusters (`aws_db_instance`, `aws_rds_cluster`) — consider `terraform-aws-modules/rds/aws`
  - ECS services (`aws_ecs_service`, `aws_ecs_task_definition`) — consider `terraform-aws-modules/ecs/aws`
  - S3 buckets with full compliance config — consider `terraform-aws-modules/s3-bucket/aws`
  - IAM roles and policies — consider `terraform-aws-modules/iam/aws`
  - CloudWatch log groups and alarms — consider `terraform-aws-modules/cloudwatch/aws`
  - Step Functions — consider `terraform-aws-modules/step-functions/aws`
  - EventBridge — consider `terraform-aws-modules/eventbridge/aws`

  This is a recommendation, not a hard requirement. Flag with category `Code Quality` and a suggestion to search the registry. Do not flag if the MR is modifying existing resources rather than creating new ones, or if the resource configuration is trivial (e.g., a single `aws_cloudwatch_log_group` with no complex setup).

  Example finding body: "This MR introduces several hand-rolled ALB resources (`aws_lb`, `aws_lb_listener`, `aws_lb_target_group`). Consider using `terraform-aws-modules/alb/aws` from the Terraform Registry — it handles listener rules, target group health checks, and access logging out of the box. Search the registry at <https://registry.terraform.io/> for modules that match your use case before writing custom infrastructure."

- **New custom modules that duplicate public functionality**: When the MR creates a new module (e.g., a new directory with `main.tf`, `variables.tf`, `outputs.tf`) that wraps a small number of AWS resources, recommend checking the Terraform Registry for an existing module that covers the same use case. Writing a custom module is justified when the public module does not meet CCP Next conventions or organizational requirements, but the author should document why the public alternative was not suitable.

  Example finding body: "This MR introduces a new custom module for S3 bucket provisioning. The `terraform-aws-modules/s3-bucket/aws` module on the Terraform Registry provides versioning, encryption, public access blocking, and logging configuration with sensible defaults. If the public module does not meet CCP Next requirements, document the gap to justify the custom implementation."
