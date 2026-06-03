---
name: gitlab-module-mr-review
description: >
  Reviews GitLab merge requests for CCP Next Terraform module repositories.
  Applies shared CCP Next convention checks (naming, tagging, OPA policies, Checkov compliance,
  SWA module enforcement, security, code quality, performance, architecture) followed by
  module-specific checks (file structure validation, interface breaking changes, variable/context.tf
  constraints, labels module usage, SRE module exceptions). Fetches MR diffs via the GitLab MCP server,
  analyzes changes, and posts findings as inline comments on the MR.
  Use when the user asks to review a merge request for a module project (not a deployment or Lambda project).
---

# GitLab Module MR Review

## When to use this skill

Activate this skill when the user asks to:

- Review a module merge request (MR)
- Do a code review on a GitLab module MR
- Check a module MR for issues
- Provide feedback on module MR changes
- Review an MR in a Terraform module repository
- Review an MR in a repo with `main.tf`, `variables.tf`, `outputs.tf` at the project root (module layout)

Do NOT use this skill for deployment MRs or Lambda MRs — use the deployment MR review skill or Lambda MR review skill instead. Module repos are identified by Terraform files at the project root (not under a `terraform/` subdirectory) and the presence of standard module files (`main.tf`, `variables.tf`, `outputs.tf`, `provider.tf`, `versions.tf`).

## Prerequisites

- The GitLab MCP server must be connected and authenticated. If the MCP server is not connected or authentication fails, inform the user and stop the review.
- The user must provide either:
  - A GitLab MR URL (e.g., `https://gitlab.example.com/group/project/-/merge_requests/123`)
  - A project path and MR IID (e.g., "review MR 123 in my-group/my-project")

## Workflow

### Shared Workflow Steps

Read `references/shared-workflow.md` and follow the shared workflow steps for:

- Step 1: Identify the MR
- Step 2: Gather MR context
- Findings JSON structure, assembly, reliable writing, URL-encoding, posting, and chat summary
- Review guidelines

Use the following skill-specific placeholder values:

- `<skill-name>`: **Module**
- `<skill-findings-filename>`: **mr-review-findings.json**
- `<skill-specific-categories>`: `CCP Next`, `OPA Policy`, `Checkov`, `SWA Module`, `Security`, `Code Quality`, `Performance`, `Architecture`, `Module Structure`, `Module Interface`, `Commit/Branch`, `README`

### Step 3: Load reference material

Read `references/ccp-next-conventions.md` for CCP Next-specific conventions and best practices. Apply these standards during the review.

### Step 4: Shared review checks

Read `references/shared-checks.md` and apply ALL 14 shared checks (sections 1-14) against the MR diff. These checks cover CCP Next conventions, OPA policies, Checkov compliance, SWA module enforcement, security, code quality, performance, architecture, Terraform import warnings, version constraints, commit/branch validation, README validation, project structure validation, and public module reuse.

Complete all shared checks before moving to the module-specific section below. Do NOT skip shared checks even if the MR has no infrastructure changes.

## Module-Specific Checks (apply only to module repositories)

The following checks apply only to Terraform module repositories. Module repos are identified by Terraform files at the project root (not under a `terraform/` subdirectory) and the presence of standard module files. Run these checks after completing all shared checks above.

### Module File Structure Validation

Validate that the module follows the standard CCP Next file structure. Module repositories have a specific layout that differs from deployment repositories — Terraform files live at the project root, not under a `terraform/` subdirectory. Structural issues are caught early to prevent pipeline failures and ensure consistency across the platform.

- **Required files at project root**: Verify that the following standard module files exist at the project root:
  - `main.tf` — primary resource definitions
  - `variables.tf` — input variable declarations
  - `outputs.tf` — output value declarations
  - `provider.tf` — provider configuration
  - `versions.tf` — Terraform and provider version constraints

  If any of these files are missing from the project (not present in the MR diffs or the existing file listing), flag identifying which files are missing.

  Example violation: The module repository is missing `provider.tf` and `versions.tf` at the project root.

  Suggested fix: Create the missing files at the project root. Every module must have all five standard files to ensure consistent structure across the platform:

  ```text
  my-module/
  ├── main.tf
  ├── variables.tf
  ├── outputs.tf
  ├── provider.tf
  └── versions.tf
  ```

- **Terraform files at root, not under terraform/ subdirectory**: Verify that `.tf` files are located at the project root and NOT under a `terraform/` subdirectory. Module repositories place Terraform files directly at the root — the `terraform/` subdirectory pattern is used by deployment repositories, not modules. If the MR diff shows `.tf` files under a `terraform/` directory (e.g., `terraform/main.tf`, `terraform/variables.tf`), flag.

  Example violation:

  ```text
  terraform/main.tf
  terraform/variables.tf
  terraform/outputs.tf
  ```

  Suggested fix: Move all Terraform files from the `terraform/` subdirectory to the project root. Module repositories must have Terraform files at the root level:

  ```text
  # Wrong (deployment layout):
  terraform/main.tf

  # Correct (module layout):
  main.tf
  ```

- **Files in incorrect directories**: Flag any Terraform files (`.tf`) placed in directories that do not follow the expected module structure. In a module repository, `.tf` files should be at the project root or in well-known subdirectories like `modules/` (for child modules) or `examples/` (for usage examples). Flag `.tf` files found in unexpected directories (e.g., `src/`, `infra/`, `deploy/`, `terraform/`).

  Example violation: `src/main.tf` or `infra/networking.tf` in a module repository.

  Suggested fix: Move the Terraform files to the project root or into a recognized subdirectory (`modules/` for child modules, `examples/` for usage examples). The standard module layout keeps all primary Terraform files at the root.

- **Validate example directory findings against actual content**: Before flagging missing files in `examples/` subdirectories (e.g., a missing `variables.tf`), scan the example's actual content to verify the finding is relevant. An example directory only needs a `variables.tf` if it declares variables beyond what `context.tf` already provides. Similarly, an example only needs an `.auto.tfvars` file if it defines variables that require values for testing. Do not flag a missing file if the example functions correctly without it — the goal is to catch genuine gaps, not enforce a rigid file checklist that produces false positives.

  How to verify: Review the example's `main.tf` and any symlinked files (e.g., `context.tf`, `outputs.tf`) to determine what variables are declared and whether they have defaults. If all declared variables have defaults or are provided by `context.tf`, a separate `variables.tf` is not needed.

  Example of a valid finding: An example's `main.tf` references `var.custom_setting` but no `variables.tf` or `context.tf` declares that variable — the example would fail to plan.

- **Missing pyproject.toml**: Flag if no `pyproject.toml` file exists at the project root. CCP Next projects use `pyproject.toml` for Python dependency and project management (pre-commit, linting, build tooling). Flag with category `Module Structure`.

- **Missing lock file**: Flag if neither `uv.lock` nor `poetry.lock` exists at the project root alongside `pyproject.toml`. A lock file ensures reproducible dependency resolution. Flag with category `Module Structure`.  Example of a false positive: An example symlinks `context.tf` from the root (which declares all context variables with defaults) and `main.tf` hardcodes all other values — no `variables.tf` is needed.

- **Terraform version constraint**: Check the `versions.tf` file for the Terraform version constraint. The `required_version` MUST use a bounded range with both a lower bound (`>=`) and an upper bound (`<`). For example, `>= 1.7.0, < 2.0.0` is valid. The specific version numbers may change over time — what matters is that both bounds are present. Flag if:
  - The `required_version` is missing entirely
  - Only a lower bound is specified without an upper bound (e.g., `>= 1.7.0` alone)
  - Only an upper bound is specified without a lower bound
  - An exact version pin is used (e.g., `= 1.7.0`) instead of a range

  Example violation:

  ```hcl
  terraform {
    required_version = ">= 1.3.0"
  }
  ```

  Suggested fix: Add an upper bound to create a bounded range:

  ```hcl
  terraform {
    required_version = ">= 1.7.0, < 2.0.0"
  }
  ```

  The lower bound ensures access to required Terraform features. The upper bound prevents unexpected breaking changes from a major version upgrade. Both bounds are required.

- **AWS provider version constraint**: Check the `versions.tf` file for the AWS provider version constraint. The required AWS provider version MUST use a lower-bounded constraint (`>=`). For example, `>= 6.0` or `~> 6.1` are both valid. The specific version number may change — what matters is that a minimum version is enforced. Flag if:
  - The constraint is missing entirely
  - An exact version pin is used (e.g., `= 6.1.0`) instead of a range

  Example violation:

  ```hcl
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = "6.1.0"
      }
    }
  }
  ```

  Suggested fix: Use a lower-bounded constraint instead of an exact pin:

  ```hcl
  terraform {
    required_providers {
      aws = {
        source  = "hashicorp/aws"
        version = ">= 6.1"
      }
    }
  }
  ```

  Modules should declare the minimum provider version they need and let the consuming deployment control the upper bound via its own lock file and version constraints.

### Module Interface and Breaking Change Checks

Module interfaces are contracts — variables are the inputs consumers pass in, and outputs are the values consumers depend on. Renaming or removing a variable or output is a breaking change that can silently break every consumer of the module. Detect these changes by comparing removed and added blocks in the MR diff.

- **Renamed variables**: Detect renamed variables by comparing the MR diff for removed and added `variable` blocks. A rename is indicated when a `variable` block name appears in removed lines (prefixed with `-`) and a different `variable` block name appears in added lines (prefixed with `+`) with similar attributes (same `type`, similar `description`). Flag explaining that renaming a variable breaks all consumers that reference the old variable name in their module calls.

  How to detect in the diff:
  - A `variable "<old_name>"` block appears in removed lines
  - A `variable "<new_name>"` block appears in added lines
  - The two blocks have similar structure (same type, similar description, similar default)

  Example violation:

  ```diff
  - variable "vpc_id" {
  -   description = "ID of the VPC"
  -   type        = string
  - }
  + variable "network_vpc_id" {
  +   description = "ID of the VPC"
  +   type        = string
  + }
  ```

  Suggested fix: If the rename is intentional, provide a deprecation path for consumers. Keep the old variable with a default that references the new one, or coordinate with all downstream consumers before merging. Consider a major version bump to signal the breaking change:

  ```hcl
  variable "vpc_id" {
    description = "DEPRECATED: Use network_vpc_id instead. ID of the VPC."
    type        = string
    default     = null
  }

  variable "network_vpc_id" {
    description = "ID of the VPC"
    type        = string
    default     = null
  }

  locals {
    effective_vpc_id = coalesce(var.network_vpc_id, var.vpc_id)
  }
  ```

  Document the breaking change in the MR description and consider a major version bump.

- **Removed variables**: Detect variables that existed before the MR but are removed in the diff. A removed variable is indicated when a `variable` block name appears in removed lines but no corresponding `variable` block with the same name appears in added lines. Flag explaining that removing a variable breaks all consumers that pass a value for that variable — Terraform will error with "An argument named X is not expected here."

  How to detect in the diff:
  - A `variable "<name>"` block appears in removed lines (prefixed with `-`)
  - No `variable "<name>"` block with the same name appears in added lines (prefixed with `+`)

  Example violation:

  ```diff
  - variable "enable_logging" {
  -   description = "Whether to enable access logging"
  -   type        = bool
  -   default     = true
  - }
  ```

  Suggested fix: If the variable is no longer needed, deprecate it first rather than removing it outright. Keep the variable with a deprecation notice and ignore its value internally. Remove it in a future major version after consumers have had time to update:

  ```hcl
  variable "enable_logging" {
    description = "DEPRECATED: Logging is now always enabled. This variable will be removed in the next major version."
    type        = bool
    default     = true
  }
  ```

- **Renamed outputs**: Detect renamed outputs by comparing the MR diff for removed and added `output` blocks. A rename is indicated when an `output` block name appears in removed lines and a different `output` block name appears in added lines with a similar `value` expression. Flag explaining that renaming an output breaks all consumers that reference the old output name (e.g., `module.my_module.old_output_name` will fail with "This object does not have an attribute named old_output_name").

  How to detect in the diff:
  - An `output "<old_name>"` block appears in removed lines
  - An `output "<new_name>"` block appears in added lines
  - The two blocks have a similar `value` expression

  Example violation:

  ```diff
  - output "bucket_arn" {
  -   description = "ARN of the S3 bucket"
  -   value       = aws_s3_bucket.this.arn
  - }
  + output "s3_bucket_arn" {
  +   description = "ARN of the S3 bucket"
  +   value       = aws_s3_bucket.this.arn
  + }
  ```

  Suggested fix: If the rename is intentional, provide both the old and new output names during a transition period. Keep the old output as a deprecated alias pointing to the same value, then remove it in a future major version:

  ```hcl
  output "bucket_arn" {
    description = "DEPRECATED: Use s3_bucket_arn instead. ARN of the S3 bucket."
    value       = aws_s3_bucket.this.arn
  }

  output "s3_bucket_arn" {
    description = "ARN of the S3 bucket"
    value       = aws_s3_bucket.this.arn
  }
  ```

  Document the breaking change in the MR description and consider a major version bump.

- **Removed outputs**: Detect outputs that existed before the MR but are removed in the diff. A removed output is indicated when an `output` block name appears in removed lines but no corresponding `output` block with the same name appears in added lines. Flag explaining that removing an output breaks all consumers that reference it — Terraform will error with "This object does not have an attribute named X."

  How to detect in the diff:
  - An `output "<name>"` block appears in removed lines (prefixed with `-`)
  - No `output "<name>"` block with the same name appears in added lines (prefixed with `+`)

  Example violation:

  ```diff
  - output "endpoint_url" {
  -   description = "The endpoint URL of the service"
  -   value       = aws_lb.this.dns_name
  - }
  ```

  Suggested fix: If the output is no longer relevant, deprecate it first rather than removing it outright. Keep the output with a deprecation notice and a null or empty value, then remove it in a future major version:

  ```hcl
  output "endpoint_url" {
    description = "DEPRECATED: This output will be removed in the next major version."
    value       = null
  }
  ```

- **Removed resources that consumers depend on**: Detect `resource` blocks that are removed in the MR diff without a corresponding `removed` block (Terraform 1.7+). When a module manages a resource via `for_each` or directly, and that resource block is deleted, any consumer that already has instances of that resource in their Terraform state will see Terraform plan to **destroy** those resources on the next apply. This can cause outages if the resources are still in use (e.g., VPC links, security groups, IAM roles referenced by other infrastructure). Flag.

  How to detect in the diff:
  - A `resource "<type>" "<name>"` block appears in removed lines (prefixed with `-`)
  - No `resource "<type>" "<name>"` block with the same type and name appears in added lines
  - No `removed { from = <type>.<name> }` block appears in added lines to handle the state transition safely

  Example violation:

  ```diff
  - resource "aws_api_gateway_vpc_link" "this" {
  -   for_each = var.vpc_links
  -
  -   name        = each.value.name
  -   target_arns = each.value.target_arns
  -   tags        = module.root_labels.tags
  - }
  ```

  Suggested fix: Add a `removed` block to safely detach the resource from Terraform state without destroying it:

  ```hcl
  removed {
    from = aws_api_gateway_vpc_link.this

    lifecycle {
      destroy = false
    }
  }
  ```

  This tells Terraform to remove the resource from state management without destroying the actual infrastructure, giving consumers time to migrate.

- **Removed fields from variable object types**: Detect when a field is removed from an `object({...})` type definition inside a `variable` block. When a module's variable accepts an object type and a field is removed from that type, any consumer currently passing that field will get a Terraform type validation error. Flag.

  How to detect in the diff:
  - An attribute name appears in removed lines within an `object({...})` type definition (e.g., `vpc_link_key = optional(string)`)
  - No attribute with the same name appears in added lines within the same object type

  Example violation:

  ```diff
    integration_config = object({
      connection_type      = optional(string)
      credentials          = optional(string)
  -   vpc_link_key         = optional(string)
  +   connection_id        = optional(string)
    })
  ```

  Suggested fix: Keep the old field as a deprecated optional alongside the new fields during a transition period:

  ```hcl
  integration_config = object({
    connection_type      = optional(string)
    credentials          = optional(string)
    connection_id        = optional(string)        # New: pass VPC Link ID directly
    vpc_link_key         = optional(string)        # DEPRECATED: use connection_id instead
  })
  ```

  Or accept this as a breaking change and bump the major version.

### Breaking Change Summary and Version Bump Recommendation

When ANY breaking change is detected (renamed/removed variables, renamed/removed outputs, removed resources, or removed fields from object types), the review MUST include a consolidated breaking change summary finding in addition to the individual findings. This summary finding ensures the MR author and reviewers have a clear, actionable checklist.

The summary finding MUST:

- Use `category: "Module Interface"`
- Use the title: `Breaking changes detected — major version bump required`
- Be attached to the first changed file in the MR diff at line 1
- Include in the body:
  1. A list of all breaking changes detected (variable removals, output removals, resource deletions, field removals)
  2. A recommendation to bump the module's major version (e.g., `v1.x.x` → `v2.0.0`) per semantic versioning
  3. A recommendation to add a `BREAKING CHANGE:` footer to the merge commit message (e.g., `feat!: remove vpc_links in favor of connection_id\n\nBREAKING CHANGE: vpc_links variable and aws_api_gateway_vpc_link resource removed`)
  4. A recommendation to document the migration path in the MR description and CHANGELOG
  5. A recommendation to coordinate with downstream consumers before merging

Example summary finding body:

```markdown
This MR contains breaking changes that will affect downstream consumers:

1. **Removed variable:** `vpc_links` — consumers passing this variable will get "An argument named vpc_links is not expected here"
2. **Removed field:** `vpc_link_key` from `resources.integration_config` — consumers using this field will get a type validation error
3. **Removed resource:** `aws_api_gateway_vpc_link.this` — consumers with this resource in state will see it planned for destruction

**Recommendations:**
- Bump the module version to the next major version (e.g., `v1.x.x` → `v2.0.0`)
- Use a breaking change commit message: `feat!: remove vpc_links in favor of connection_id`
- Add a `BREAKING CHANGE:` footer to the commit message body
- Document the migration path in the MR description and CHANGELOG
- Coordinate with downstream consumer teams before merging
- Consider adding `removed` blocks for deleted resources to prevent state destruction
```

For all breaking change findings, recommend that the MR author:

1. Verify whether any downstream consumers depend on the changed variable, output, resource, or field
2. Coordinate with consumer teams before merging
3. Bump the major version to signal the breaking change via semantic versioning
4. Use a conventional commit with a breaking change indicator (`feat!:` prefix or `BREAKING CHANGE:` footer)
5. Document the breaking change prominently in the MR description and CHANGELOG
6. For removed resources, add `removed` blocks with `destroy = false` to prevent state destruction

### Module Variable and context.tf Checks

Module variables define the public interface — their type constraints determine what consumers can pass in. Overly broad types like `any` weaken the interface contract and allow invalid inputs to slip through undetected until apply time. Additionally, `context.tf` is an auto-generated file managed by the labels module tooling and must not be manually edited.

- **Variables must use proper type constraints (not `any`)**: Verify that every `variable` block in the module uses a specific type constraint (`string`, `number`, `bool`, `list(...)`, `map(...)`, `object({...})`, `set(...)`, `tuple([...])`) rather than the overly broad `any` type. Using `type = any` defeats Terraform's type checking and allows consumers to pass values of any shape — errors surface only at apply time instead of at plan time. Flag `type = any` as a finding.

  Example violation:

  ```hcl
  variable "config" {
    description = "Application configuration"
    type        = any
  }
  ```

  Suggested fix: Define the expected structure explicitly so Terraform validates inputs at plan time:

  ```hcl
  variable "config" {
    description = "Application configuration"
    type = object({
      app_name    = string
      environment = string
      replicas    = number
      features    = list(string)
    })
  }
  ```

  If the variable genuinely needs to accept multiple shapes, use a `union` type or `optional()` attributes to express the flexibility while still providing type safety.

- **Recommend validation blocks where type constraints are insufficient**: When a variable's type constraint alone cannot enforce the valid input range (e.g., a `string` that must match a specific pattern, a `number` that must be within a range, or an enum-like value from a fixed set), recommend adding a `validation` block. This is a suggestion to strengthen the interface, not a hard requirement.

  Patterns to look for:
  - `type = string` variables that represent environment names, AWS regions, ARNs, or other structured strings
  - `type = number` variables that represent counts, port numbers, or sizes with valid ranges
  - `type = string` variables with a `default` value that suggests a fixed set of allowed values

  Example — variable that would benefit from validation:

  ```hcl
  variable "environment" {
    description = "Deployment environment"
    type        = string
    default     = "dev"
  }
  ```

  Suggested improvement:

  ```hcl
  variable "environment" {
    description = "Deployment environment"
    type        = string
    default     = "dev"

    validation {
      condition     = contains(["lab", "dev", "qa", "prod"], var.environment)
      error_message = "Environment must be one of: lab, dev, qa, prod."
    }
  }
  ```

  Another example — numeric range:

  ```hcl
  variable "instance_count" {
    description = "Number of instances to create"
    type        = number
    default     = 1
  }
  ```

  Suggested improvement:

  ```hcl
  variable "instance_count" {
    description = "Number of instances to create"
    type        = number
    default     = 1

    validation {
      condition     = var.instance_count >= 1 && var.instance_count <= 100
      error_message = "Instance count must be between 1 and 100."
    }
  }
  ```

- **Flag manual edits to context.tf**: The `context.tf` file is auto-generated by the labels module tooling (e.g., `terraform-null-label` or `ccp-next-labels-module` scaffolding). It defines the standard context variables (`namespace`, `environment`, `stage`, `name`, `attributes`, `tags`, etc.) and must not be manually edited. Manual edits to `context.tf` will be overwritten the next time the labels module tooling regenerates the file, causing silent regressions.

  If the MR diff includes changes to a file named `context.tf`, flag.

  How to detect: Check the MR diff file list for any file path ending in `context.tf` (at the project root or in a child module directory). If `context.tf` appears in the diff with added or modified lines, flag it.

  Example violation: The MR diff shows modifications to `context.tf`:

  ```diff
  --- a/context.tf
  +++ b/context.tf
  @@ -10,6 +10,7 @@
   variable "context" {
     type = any
     default = {
  +    custom_field = "my-value"
       enabled             = true
       namespace           = null
  ```

  Suggested fix: Do not manually edit `context.tf`. If you need to customize the context variables, do so in your module's `main.tf` or `variables.tf` by overriding the context values when calling the labels module:

  ```hcl
  module "root_labels" {
    source = "southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws"

    context = merge(var.context, {
      # Override specific context values here
      name = "my-custom-name"
    })
  }
  ```

  If the labels module tooling needs to be updated, regenerate `context.tf` using the tooling rather than editing it by hand.

- **SRE module exception — allow broad IAM permissions**: Modules built for SRE use (SRE modules) intentionally require broad IAM permissions for the services they operate on, including wildcard regions and broad service-level permissions. When the module is identified as an SRE module, do NOT flag broad IAM permissions as security issues.

  How to identify an SRE module: Look for indicators in the module's metadata:
  - The repository name or path contains `sre` (e.g., `ccp-next-sre-ec2-module`, `sre-rds-recovery-module`)
  - The MR description or README mentions SRE purpose, operational tooling, or incident response
  - The module's description references cross-region access, broad service permissions, or operational automation

  When an SRE module is detected, the following IAM patterns are acceptable and should NOT be flagged:
  - Wildcard resource ARNs scoped to a specific service (e.g., `"Resource": "arn:aws:ec2:*:*:instance/*"`)
  - Broad service-level actions for the operated service (e.g., `"Action": ["ec2:Describe*", "ec2:Stop*", "ec2:Start*"]`)
  - Cross-region permissions (e.g., `"Resource": "arn:aws:rds:*:*:db:*"`)

  These patterns would normally be flagged by the security review (section 4e) and Checkov compliance checks (section 4c), but SRE modules have a legitimate operational need for broader permissions on the specific service they manage.

  Example — acceptable IAM policy in an SRE EC2 module:

  ```json
  {
    "Effect": "Allow",
    "Action": [
      "ec2:DescribeInstances",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:RebootInstances"
    ],
    "Resource": "arn:aws:ec2:*:*:instance/*"
  }
  ```

  This would normally trigger a wildcard resource finding, but for an SRE module managing EC2 instances across regions, this is expected and should not be flagged.

  Note: The SRE exception applies only to the specific service the module operates on. Broad permissions on unrelated services (e.g., an SRE EC2 module with `s3:*` permissions) should still be flagged as a security concern.

### Labels Module Usage (Module-Specific)

The shared CCP Next convention check (section 4a) covers general Labels_Module usage — this module-specific section goes deeper into the patterns expected in module repositories. In a module repo, the `ccp-next-labels-module` is the authoritative source for resource names and tags. Every AWS resource that supports `name` and `tags` arguments must use the labels module rather than constructing names or tags manually. This ensures consistent naming conventions, cost allocation tagging, and compliance across the entire CCP Next platform.

- **Resource names must use `module.root_labels.id` or a child labels module**: Every AWS resource that accepts a `name`, `name_prefix`, or equivalent naming argument MUST derive its name from the labels module. The standard pattern is `module.root_labels.id` for the root module's label. When a module creates multiple resources that need distinct names, use a child labels module instance with additional attributes to differentiate them — do not concatenate strings manually.

  Flag any AWS resource whose name argument does not reference `module.root_labels.id` or a child labels module (e.g., `module.<child_labels>.id`).

  Patterns to detect:
  - Hardcoded string literals in `name` or `name_prefix` arguments (e.g., `name = "my-bucket"`)
  - String interpolation that does not include a labels module reference (e.g., `name = "${var.project}-${var.environment}-bucket"`)
  - Variable references used directly as names without labels module (e.g., `name = var.bucket_name`)
  - `format()` or `join()` calls constructing names without labels module input

  Acceptable patterns:
  - `name = module.root_labels.id` — standard root label
  - `name = module.bucket_labels.id` — child labels module for a specific resource
  - `name_prefix = "${module.root_labels.id}-"` — labels module with a suffix for resources that require unique names
  - `name = "${module.root_labels.id}-replica"` — labels module with a qualifier when multiple resources of the same type need distinct names

  Example violation:

  ```hcl
  resource "aws_s3_bucket" "this" {
    bucket = "my-app-${var.environment}-data"
    tags   = module.root_labels.tags
  }
  ```

  Suggested fix:

  ```hcl
  resource "aws_s3_bucket" "this" {
    bucket = module.root_labels.id
    tags   = module.root_labels.tags
  }
  ```

  Example violation — multiple resources with manually constructed names:

  ```hcl
  resource "aws_sqs_queue" "primary" {
    name = "${var.project_name}-primary-queue"
  }

  resource "aws_sqs_queue" "dlq" {
    name = "${var.project_name}-dlq"
  }
  ```

  Suggested fix — use child labels modules for distinct names:

  ```hcl
  module "primary_queue_labels" {
    source  = "southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws"
    context = module.root_labels.context
    attributes = ["primary"]
  }

  module "dlq_labels" {
    source  = "southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws"
    context = module.root_labels.context
    attributes = ["dlq"]
  }

  resource "aws_sqs_queue" "primary" {
    name = module.primary_queue_labels.id
    tags = module.primary_queue_labels.tags
  }

  resource "aws_sqs_queue" "dlq" {
    name = module.dlq_labels.id
    tags = module.dlq_labels.tags
  }
  ```

- **Resource tags must use `module.root_labels.tags`**: Every AWS resource that accepts a `tags` argument MUST use `module.root_labels.tags` (or the tags from a child labels module). The labels module produces a complete tag map containing all required CCP Next tags — manually constructing tags bypasses the platform's tagging standards and will fail OPA policy checks.

  Flag any AWS resource whose `tags` argument does not reference `module.root_labels.tags` or a child labels module's tags (e.g., `module.<child_labels>.tags`).

  Patterns to detect:
  - Inline tag maps (e.g., `tags = { Name = "my-resource" }`)
  - `merge()` calls that do not include a labels module tags reference as the base (e.g., `tags = merge({ Custom = "value" }, var.extra_tags)`)
  - Variable references used directly as tags without labels module (e.g., `tags = var.tags`)
  - Empty tags or missing `tags` argument entirely on resources that support tagging

  Acceptable patterns:
  - `tags = module.root_labels.tags` — standard root label tags
  - `tags = module.bucket_labels.tags` — child labels module tags
  - `tags = merge(module.root_labels.tags, { Additional = "value" })` — labels module tags as the base with additional custom tags merged in

  Example violation:

  ```hcl
  resource "aws_sqs_queue" "this" {
    name = module.root_labels.id
    tags = {
      Name        = "my-queue"
      Environment = var.environment
      Project     = var.project
    }
  }
  ```

  Suggested fix:

  ```hcl
  resource "aws_sqs_queue" "this" {
    name = module.root_labels.id
    tags = module.root_labels.tags
  }
  ```

  Example — acceptable use of merge for additional tags:

  ```hcl
  resource "aws_sqs_queue" "this" {
    name = module.root_labels.id
    tags = merge(module.root_labels.tags, {
      QueueType = "fifo"
    })
  }
  ```

- **Flag hardcoded resource names**: Flag any AWS resource where the `name`, `name_prefix`, `bucket`, `function_name`, `cluster_name`, `db_name`, `queue_name`, `topic_name`, or equivalent naming argument contains a hardcoded string literal that does not reference the labels module. Hardcoded names bypass the platform's naming conventions, making resources difficult to identify, track, and correlate across environments. Flag.

  Common naming arguments to check across resource types:
  - `aws_s3_bucket`: `bucket`
  - `aws_sqs_queue`: `name`
  - `aws_sns_topic`: `name`
  - `aws_lambda_function`: `function_name`
  - `aws_ecs_cluster`: `name`
  - `aws_rds_cluster`: `cluster_identifier`
  - `aws_dynamodb_table`: `name`
  - `aws_kms_key`: `alias` (via `aws_kms_alias`)
  - `aws_security_group`: `name`
  - `aws_lb`: `name`
  - `aws_cloudwatch_log_group`: `name`
  - General: `name`, `name_prefix`

  Example violation:

  ```hcl
  resource "aws_lambda_function" "this" {
    function_name = "my-app-processor"
    runtime       = "python3.12"
    handler       = "index.handler"
    role          = aws_iam_role.this.arn
  }
  ```

  Suggested fix:

  ```hcl
  resource "aws_lambda_function" "this" {
    function_name = module.root_labels.id
    runtime       = "python3.12"
    handler       = "index.handler"
    role          = aws_iam_role.this.arn
    tags          = module.root_labels.tags
  }
  ```

- **Flag hardcoded tags**: Flag any AWS resource where the `tags` argument contains a hardcoded inline tag map instead of referencing the labels module. Hardcoded tags will not include the required CCP Next tag keys (RepoId, CCPNamespace, SWA:Name, SWA:RepoId, SWA:DashApplicationService, EnvPrefix, TFStateBucket, TFStateKey) and will fail OPA tagging policy checks in the pipeline. Flag.

  Patterns to flag:
  - Inline tag maps with no labels module reference: `tags = { Name = "foo", Environment = "dev" }`
  - Tags constructed entirely from variables without labels module: `tags = var.tags`
  - Tags using `merge()` without labels module tags as the base: `tags = merge(var.common_tags, { Name = "foo" })`
  - Missing `tags` argument on resources that support tagging (the resource will inherit `default_tags` from the provider, but explicit `tags = module.root_labels.tags` is the expected pattern in modules)

  Example violation:

  ```hcl
  resource "aws_dynamodb_table" "this" {
    name         = module.root_labels.id
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "id"

    tags = {
      Name        = "my-table"
      Team        = "platform"
      Environment = var.environment
    }
  }
  ```

  Suggested fix:

  ```hcl
  resource "aws_dynamodb_table" "this" {
    name         = module.root_labels.id
    billing_mode = "PAY_PER_REQUEST"
    hash_key     = "id"

    tags = module.root_labels.tags
  }
  ```

  Example violation — tags from variable without labels module:

  ```hcl
  resource "aws_sns_topic" "this" {
    name = module.root_labels.id
    tags = var.common_tags
  }
  ```

  Suggested fix:

  ```hcl
  resource "aws_sns_topic" "this" {
    name = module.root_labels.id
    tags = module.root_labels.tags
  }
  ```
