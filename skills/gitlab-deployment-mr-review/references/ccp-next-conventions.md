# CCP Next Conventions & Best Practices

Source: <https://southwest.gitlab-dedicated.com/swa-common/devplat/ccp-next/ccp-next-documentation>

## Terraform Block Labels

- Terraform block labels MUST use underscores (`_`), not hyphens
- Example: `resource "aws_s3_bucket" "my_bucket" {}` (correct)
- Block labels MUST NOT repeat the resource type — e.g., `resource "aws_sns_topic" "aws_sns_topic"` is forbidden
- When there is only a single resource of a given type, name it `"this"` — e.g., `resource "aws_s3_bucket" "this" {}`

## AWS Resource Naming

- Use the `ccp-next-labels-module` for consistent AWS resource naming
- Resource names MUST reference `module.root_labels.id` (or a child labels module)
- Any module whose source is `southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws` is also a valid labels module (e.g., `module.my_resource_labels.id`)
- A repo may have multiple labels module instances for different resources — this is expected and valid
- Hardcoded resource names are not allowed — always derive names from the labels module
- Resource names must follow SWA/CCP Next naming conventions
- Use the `CCPNamespace` tag to reference resources across deployment projects

## AWS Resource Tagging

- All AWS resources must include CCP Next required tags
- Use the `ccp-next-labels-module` to generate consistent tags via `module.root_labels.tags`
- Hardcoded tags are not allowed — always use the labels module for tag values
- Tags are used for cloud cost reporting and organizational automations
- The AWS provider must define `default_tags` with all required tag keys:
  - `CCPNamespace` — deployment namespace
  - `SWA:Name` — resource name following SWA conventions
  - `SWA:RepoId` — SWA repository identifier
  - `SWA:DashApplicationService` — DASH application service identifier
  - `EnvPrefix` — environment identifier (lab, dev, qa, prod)
  - `TFStateBucket` — Terraform state bucket name
  - `TFStateKey` — Terraform state file key
- Missing any of these required tags will trigger a pipeline failure via the tagging OPA policy

## Variables and Outputs

- All variables MUST have `description` and `type` attributes
- All outputs MUST have a `description` attribute
- Sensitive outputs MUST use `sensitive = true`
- Variables MUST use proper type constraints — avoid overly broad types like `any`
- Add `validation` blocks where type constraints alone are insufficient

## Providers & Modules Policy

- Only whitelisted Terraform providers and modules from approved namespaces are allowed

### Approved Providers (from `providers_policy.rego`)

- All `registry.terraform.io/hashicorp/*` providers
- `terraform.io/builtin/terraform`
- `registry.terraform.io/grafana/grafana`
- `registry.terraform.io/cloudposse/awsutils`
- `registry.terraform.io/opensearch-project/opensearch`

### Approved Module Sources (from `module_source_policy.rego`)

**Approved registry namespaces:**

- `terraform-aws-modules`
- `aws-ia`
- `cloudposse`
- `.` (relative paths)

Both top-level and nested module sources are checked against these approved lists.

### Enforcement

- Public registry modules/providers must come from pre-approved namespaces
- Using unapproved providers or module sources will be blocked by CCP Next pipelines
- To request a new provider, follow the official process in the documentation

## Version Constraints

- Terraform version constraint: MUST use a bounded range with both a lower bound (`>=`) and an upper bound (`<`), e.g., `>= 1.7.0, < 2.0.0`. The specific versions may change — what matters is that both bounds are present.
- AWS provider version constraint: MUST use a lower-bounded constraint (`>=`), e.g., `>= 6.0` or `~> 6.1`. The specific version may change — what matters is that a minimum version is enforced.

## OPA Policies

CCP Next enforces four OPA policies via the pipeline. The authoritative approved lists are defined in the rego files located at `ccp-next-opa-policies/policies/ccp/`:

- **Tagging policy** (`tagging_policy.rego`) — enforces required tag keys on the AWS provider `default_tags`
- **Providers policy** (`providers_policy.rego`) — enforces the approved Terraform providers list
- **Module source policy** (`module_source_policy.rego`) — enforces approved git sources and registry namespaces for module `source` attributes
- **Lambda runtime policy** (`lambda_runtime_policy.rego`) — blocks deprecated Lambda runtimes

CCP Next uses `conftest` (not `opa` directly) for IaC reliability scanning.

- Makefile target: `ccp-iac-scan` (replaces old `opa-iac-scan`)
- Pipeline job: `<env>_<namespace>_ccp_iac_scan`

## IaC Scanning

- CCP Next uses `conftest` (not `opa` directly) for IaC reliability scanning
- Makefile target: `ccp-iac-scan` (replaces old `opa-iac-scan`)
- Pipeline job: `<env>_<namespace>_ccp_iac_scan`
- Checkov is used for security scanning

## SWA Module Enforcement

Certain AWS resources MUST use the corresponding SWA module instead of being hand-rolled:

| Raw Resource Types | Recommended Module |
| --- | --- |
| `aws_vpc`, `aws_subnet`, `aws_nat_gateway`, `aws_route_table`, `aws_network_acl` | `ccp-next-vpc-module` |
| `aws_wafv2_web_acl`, `aws_wafv2_rule_group` | `ccp-next-waf-module` |
| `aws_api_gateway_rest_api`, `aws_apigatewayv2_api` | `ccp-next-api-gateway-module` |
| `aws_api_gateway_domain_name`, `aws_apigatewayv2_domain_name` | `ccp-next-custom-domain-module` |
| `aws_route53_zone` (private) | `ccp-next-private-hz-module` |

Web-facing resources (ALB, API Gateway, CloudFront) should have an associated WAF web ACL.

## Checkov / Security Scanning

Checkov is used for security scanning in CCP Next pipelines. Key rules include:

- S3 buckets: versioning enabled, SSE-KMS encryption, public access blocked, logging configured
- No inline IAM policies
- Encryption at rest for all data stores (RDS, DynamoDB, EBS, SQS, SNS)
- Security group rules checked against denied CIDR list (`0.0.0.0/0`, `::/0`)
- IAM policies follow least-privilege — no wildcard actions or resources

## Module File Structure

Module repositories follow a standard file structure with Terraform files at the project root (not under a `terraform/` subdirectory):

- `main.tf` — primary resource definitions
- `variables.tf` — input variable declarations
- `outputs.tf` — output value declarations
- `provider.tf` — provider configuration
- `versions.tf` — Terraform and provider version constraints
- `context.tf` — auto-generated file, MUST NOT be manually edited
- `pyproject.toml` — Python project/dependency management (MUST exist at project root)
- `uv.lock` or `poetry.lock` — dependency lock file (MUST exist alongside `pyproject.toml`)

Tests go in the `test/` directory.

Use `ccp-next-module-template` as the starting point for new modules.

## Lambda Project Structure

Lambda projects follow a specific directory layout:

```text
<project_root>/
├── src/              # Lambda function source code
├── layer/            # Lambda layer dependencies
├── terraform/        # All Terraform infrastructure files
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── versions.tf
├── README.md
└── ...
```

- Source code files (.py, .js, .ts, .go, .java) belong in `src/`
- Layer dependency files (requirements.txt, package.json) belong in `layer/`
- Terraform .tf files belong in `terraform/`, not at the project root
- A `pyproject.toml` file MUST exist at the project root for Python dependency and project management
- A lock file (`uv.lock` or `poetry.lock`) MUST exist at the project root alongside `pyproject.toml`

## Terragrunt

- Avoid using `TG_WORKING_DIRECTORY` in Terragrunt deployment pipelines
- Use proper `include` and `dependency` blocks for cross-module references

## Multi-Repo Deployment

- Separate infrastructure by lifecycle, ownership, and change frequency
- Core networking (VPCs, subnets, route tables, NAT gateways) in separate repos from application resources. Application-specific security groups (e.g., for Lambda VPC attachment) are fine in the same repo as the application — only shared/foundational networking should be separated.
- Use data sources and `CCPNamespace` tag for cross-repo resource lookups
