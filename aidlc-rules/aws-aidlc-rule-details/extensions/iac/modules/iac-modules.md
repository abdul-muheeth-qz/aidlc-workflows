# CCP Next Terraform Module Development Standards

## Overview

These IaC module development rules are MANDATORY cross-cutting constraints that apply across all AI-DLC phases when generating, reviewing, or modifying Terraform module projects on the CCP Next platform. They are not optional guidance — they are hard constraints that stages MUST enforce when generating questions, producing design artifacts, generating code, and presenting completion messages.

**Enforcement**: At each applicable stage, the model MUST verify compliance with these rules before presenting the stage completion message to the user.

### Blocking IaC Module Finding Behavior

A **blocking IaC module finding** means:
1. The finding MUST be listed in the stage completion message under an "IaC Module Findings" section with the IAC-MODULE rule ID and description
2. The stage MUST NOT present the "Continue to Next Stage" option until all blocking findings are resolved
3. The model MUST present only the "Request Changes" option with a clear explanation of what needs to change
4. The finding MUST be logged in `aidlc-docs/audit.md` with the IAC-MODULE rule ID, description, and stage context

If an IAC-MODULE rule is not applicable to the current project (e.g., IAC-MODULE-10 when no community publishing is planned), mark it as **N/A** in the compliance summary — this is not a blocking finding.

### Default Enforcement

All rules in this document are **blocking** by default. If any rule's verification criteria are not met, it is a blocking IaC module finding — follow the blocking finding behavior defined above.

### Partial Enforcement Mode

If the user selected **Partial** enforcement during opt-in, only rules IAC-MODULE-01 through IAC-MODULE-06 are enforced as blocking. All other rules (IAC-MODULE-07 through IAC-MODULE-11) are treated as advisory (non-blocking). Log the enforcement mode in `aidlc-docs/aidlc-state.md` under `## Extension Configuration`.

### Verification Criteria Format

Verification items in this document are plain bullet points describing compliance checks. They are distinct from the `- [ ]` / `- [x]` progress-tracking checkboxes used in stage plan files. Each item should be evaluated as compliant or non-compliant during review.

---

## Rule IAC-MODULE-01: Module Project Structure

**Rule**: Terraform module projects MUST place module source files in the project root (NOT under `./terraform/`). The project MUST follow the canonical CCP Next module structure.

Required structure:
```text
project-root/
├── .gitlab-ci.yml              # Pipeline config (build-module)
├── .pre-commit-config.yaml     # Pre-commit hooks
├── .terraform-docs.yml         # terraform-docs config for root module
├── .tflint.hcl                 # tflint config
├── .editorconfig               # Editor formatting rules
├── .tarball-exclusions         # Files excluded from published tarball
├── Makefile                    # PROJECT_TYPE ?= module
├── pyproject.toml              # Python project config
├── uv.lock / poetry.lock      # Dependency lock file
├── release.config.js           # Semantic-release config
├── package.json                # Node deps (start version at 0.0.0)
├── context.tf                  # Labels module context (DO NOT EDIT)
├── main.tf                     # Module resources and logic
├── variables.tf                # Module input variables
├── outputs.tf                  # Module outputs
├── versions.tf                 # Terraform and provider version constraints
├── examples/
│   ├── full_config_options/    # All supported input variables
│   └── minimal_config_options/ # Minimum required inputs only
├── local/                      # Local deployment for smoke testing
└── tests/                      # Test files (.tftest.hcl)
```

Key differences from deployments:
- Terraform files live in project root, NOT `./terraform/`
- No `environments.yml` or `.gitlab-deployments-ci.yml`
- `.terraform.lock.hcl` is NOT committed (in `.gitignore`)
- `Makefile` sets `PROJECT_TYPE ?= module`

**Verification**:
- Module Terraform files (`main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `context.tf`) exist at project root
- No `./terraform/` directory contains module source files
- `Makefile` contains `PROJECT_TYPE ?= module`
- `.terraform.lock.hcl` is listed in `.gitignore`
- `.terraform.lock.hcl` is NOT committed to version control
- `examples/` directory exists with `full_config_options/` and `minimal_config_options/`
- `local/` directory exists for smoke testing
- `tests/` directory exists with `.tftest.hcl` files

---

## Rule IAC-MODULE-02: Labels Module Integration

**Rule**: Module projects MUST use `ccp-next-labels-module` via `context.tf` at project root. The labels module provides naming and tagging for all resources created by the module.

Requirements:
- `context.tf` is copied from labels module exports — DO NOT EDIT manually
- Update by re-copying from labels module source (curl from GitLab API)
- Access context values as `module.root_labels.<var>` (e.g., `module.root_labels.id`, `module.root_labels.tags`)
- Pass context downstream: `context = module.root_labels.context`
- Use `module.root_labels.enabled` to gate resource creation
- `context.tf` MUST be placed in: project root, `examples/full_config_options/`, `examples/minimal_config_options/`, and `local/`
- Create child labels for specific resource groupings with `CCPModuleVersion` and `CCPModuleName` tags

Child labels pattern:
```hcl
module "my_resource_labels" {
  source  = "southwest.gitlab-dedicated.com/swa-common/ccp-next-labels-module/aws"
  version = "0.7.0"
  name    = "my-resource"
  context = module.root_labels.context
  tags = {
    CCPModuleVersion = var.module_version
    CCPModuleName    = var.module_name
  }
}
```

**Verification**:
- `context.tf` exists at project root with `module "root_labels"` sourced from labels module
- `context.tf` is duplicated in `examples/full_config_options/`, `examples/minimal_config_options/`, and `local/`
- Resources use `module.root_labels.enabled` (or child labels `.enabled`) for conditional creation
- Child labels include `CCPModuleVersion` and `CCPModuleName` tags
- No resource has hardcoded names or tags that bypass the labels module
- `context.tf` is not manually modified

---

## Rule IAC-MODULE-03: Input Variables

**Rule**: Module input variables MUST follow CCP Next conventions for documentation, typing, and special variables.

Requirements:
- ALL variables MUST have `description` and `type`
- Add `validation` blocks where possible and practical
- Module-specific variables go in `variables.tf` at root — context variables are in `context.tf`
- MUST include `module_name` and `module_version` special variables with `_MODULE_NAME_` and `_MODULE_VERSION_` defaults (set automatically by pipeline)

Required special variables:
```hcl
variable "module_name" {
  type        = string
  default     = "_MODULE_NAME_"
  description = "The name of this module. DO NOT change var name or the default value. This will be set automatically"
}

variable "module_version" {
  type        = string
  default     = "_MODULE_VERSION_"
  description = "The version of this module. DO NOT change var name or the default value. This will be set automatically"
}
```

**Verification**:
- Every variable in `variables.tf` has `description` and `type`
- `module_name` variable exists with default `"_MODULE_NAME_"` and correct description
- `module_version` variable exists with default `"_MODULE_VERSION_"` and correct description
- Validation blocks exist for variables with constrained domains (enums, ranges, formats)
- No context variables are duplicated in `variables.tf` (they belong in `context.tf`)

---

## Rule IAC-MODULE-04: Outputs

**Rule**: Module outputs MUST be comprehensive, well-documented, and handle conditional resource creation gracefully.

Requirements:
- ALL outputs MUST have `description`
- Use `sensitive = true` for sensitive outputs
- Use `precondition`/`postcondition` blocks for runtime validation where appropriate
- Output values that consumers might need — err on the side of more outputs
- Handle conditional resource creation with length checks or ternary expressions

Conditional output pattern:
```hcl
output "sns_topic_arn" {
  value       = length(aws_sns_topic.ccp_sns_topic) > 0 ? aws_sns_topic.ccp_sns_topic[0].arn : null
  description = "SNS topic ARN"
}
```

**Verification**:
- Every output in `outputs.tf` has a `description`
- Outputs for conditionally-created resources handle the absent case (return `null` or empty)
- Sensitive outputs use `sensitive = true`
- Module exposes outputs that consumers commonly need (ARNs, IDs, names, endpoints)
- No output references a resource without accounting for `count` or `for_each` conditional creation

---

## Rule IAC-MODULE-05: Coding Standards

**Rule**: Module Terraform code MUST follow CCP Next coding standards and naming conventions.

Requirements:
- Use `for_each` over `count` when iterating over known sets
- Use `locals` only for reused values or complex calculations
- Terraform version constraint: `>= 1.7.0, < 2.0.0`
- AWS provider: `>= 5.24.0` (module root, permissive) / `~> 6.0` (local deployment)
- tflint: `>= 0.50` with terraform (preset: all) and aws (v0.45.0) plugins
- Use `module.root_labels.enabled` to gate resource creation
- Use `name_prefix` with labels where supported
- Block labels MUST NOT repeat the resource type
- All naming conventions from IAC-DEPLOY-05 apply (snake_case files, resources, variables, outputs; single resource named `this`)

**Verification**:
- `versions.tf` specifies `required_version = ">= 1.7.0, < 2.0.0"`
- `versions.tf` specifies `aws` provider with `>= 5.24.0` constraint (permissive for consumers)
- `local/versions.tf` uses `~> 6.0` for the AWS provider
- Resources use `count = module.root_labels.enabled ? 1 : 0` for conditional creation
- `for_each` is used over `count` for known sets
- No block label repeats the resource type
- All file, resource, variable, and output names follow snake_case convention

---

## Rule IAC-MODULE-06: Example Configurations

**Rule**: Modules MUST provide both full and minimal example configurations demonstrating usage patterns.

Requirements:
- `examples/full_config_options/`: all supported input variables with example values
  - `full.auto.tfvars` — auto-loaded by `terraform test` (filename convention)
  - `main.tf` calling the module with `source = "../../"`
  - `context.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- `examples/minimal_config_options/`: minimum required inputs only
  - `minimal.auto.tfvars` — NOT auto-loaded by tests (different naming)
  - `main.tf` calling the module with `source = "../../"`
  - `context.tf`, `outputs.tf`, `versions.tf`
- Both examples have pass-through outputs for test assertions

**Verification**:
- `examples/full_config_options/` directory exists with `main.tf`, `context.tf`, `outputs.tf`, `versions.tf`, and `full.auto.tfvars`
- `examples/minimal_config_options/` directory exists with `main.tf`, `context.tf`, `outputs.tf`, `versions.tf`, and `minimal.auto.tfvars`
- Both `main.tf` files reference `source = "../../"`
- `full.auto.tfvars` contains values for ALL module variables
- `minimal.auto.tfvars` contains values for ONLY required variables
- Both examples have pass-through outputs matching root module outputs

---

## Rule IAC-MODULE-07: Testing with Mock Providers

**Rule**: Module tests MUST use `mock_provider` since iTest accounts (shared AWS test accounts) are NOT supported from CCP Next pipelines.

Requirements:
- Test files live in `tests/` and end with `.tftest.hcl`
- `test_units.tftest.hcl` — unit tests with mock providers testing the module directly
- `test_examples.tftest.hcl` — tests validating example configurations
- Use `command = plan` (not apply) since tests use mocked providers
- Mock providers use alias pattern: `mock_provider "aws" { alias = "fake" }`
- Set required context variables in the `variables {}` block
- Test examples by referencing their directory: `module { source = "./examples/full_config_options" }`

What to test:
- Expected resources are planned based on input variables
- Default values are applied correctly
- Conditional creation works (`enabled = false` creates no resources)
- Tags include `CCPModuleName` and `CCPModuleVersion`
- Input validation rejects invalid values
- Resource naming follows labels module conventions

Running tests: `make test` (automatically adds `OPTS_TF_INIT='-backend=false'`)

**Verification**:
- `tests/test_units.tftest.hcl` exists with at least one `run` block using `mock_provider`
- `tests/test_examples.tftest.hcl` exists testing at least the full_config example
- All test runs use `command = plan`
- Mock providers are configured with alias pattern
- Tests verify resource creation, naming, tagging, and conditional logic
- Tests set required context variables (department, environment, namespace, repo_id, state_bucket, state_key)
- Pure logic modules (no providers) may omit `mock_provider` and test directly against outputs

---

## Rule IAC-MODULE-08: Local Smoke Testing

**Rule**: The `local/` directory MUST provide a fully functional deployment configuration for smoke testing against real AWS accounts.

Requirements:
- `local/main.tf` calls the module with `source = "../"` and passes inputs
- `local/provider.tf` — AWS provider with `default_tags` from labels
- `local/versions.tf` — version constraints + empty `backend "s3" {}`
- `local/defaults.auto.tfvars` — default variable values for local testing
- `local/variables.tf` — deployment-specific variables (includes `region`)
- `local/context.tf` — copy of root `context.tf`
- Include supporting infrastructure (e.g., VPC module call) if the module requires it
- No `.terraform.lock.hcl` committed from `local/`
- `local/` is excluded from Checkov static scans (`--skip-path local`)
- `local/` is excluded from the published tarball (`.tarball-exclusions`)

**Verification**:
- `local/` directory exists with `main.tf`, `provider.tf`, `versions.tf`, `defaults.auto.tfvars`, `variables.tf`, `context.tf`
- `local/main.tf` references `source = "../"`
- `local/provider.tf` includes `default_tags` block with labels module tags
- `local/versions.tf` contains empty `backend "s3" {}` block
- Supporting infrastructure is included when the module has dependencies (e.g., VPC)
- No `.terraform.lock.hcl` exists in `local/`
- `local/` appears in `.tarball-exclusions`

---

## Rule IAC-MODULE-09: Checkov Static Scanning

**Rule**: Module projects run ONLY static scans (no dynamic scans). Generated code MUST pass Checkov static scanning by default.

Requirements:
- Default options: `--quiet --support --download-external-modules true --skip-path local --soft-fail-on MEDIUM`
- `local/` directory is excluded from scanning
- Hard-fail on CRITICAL/HIGH, soft-fail on MEDIUM
- Remediate all MEDIUM findings before publishing
- Keep `--download-external-modules true` in options even when overriding
- Suppression requires CloudSec exemption with inline skip syntax including justification
- External module findings (under `/.external_modules/`) may require CloudSec consultation

**Verification**:
- Generated resources follow Checkov-compliant patterns (encryption, logging, access controls)
- No Checkov skip annotations without documented justification
- `--download-external-modules true` is present in any custom scan options
- `--skip-path local` is present in scan options
- All CRITICAL/HIGH findings are resolved
- MEDIUM findings are resolved or have documented exemption path

---

## Rule IAC-MODULE-10: Publishing Pipeline

**Rule**: Module publishing follows CCP Next pipeline conventions. Publishing happens ONLY from pipelines — never locally.

Requirements:
- `.gitlab-ci.yml` includes `ccp-next-pipeline-fragments` `build-module.gitlab-ci.yml`
- Semantic-release `tagFormat` uses `${version}` (no `v` prefix)
- Start `version` at `0.0.0` in `package.json` and `pyproject.toml`
- Commit message format: `fix:` → PATCH, `feat:` → MINOR, `BREAKING CHANGE:` → MAJOR
- `MODULE_STAGING_ENABLED: 'true'` for testing pre-release versions from MR branches
- `.tarball-exclusions` lists files excluded from published package
- Pipeline stages: MR (lint, test, scan) → Merge (tag) → Release (package, publish)

Branch channels:
- `master` → `swa-releases`
- `release/v.alpha.x` → prerelease with `a` tag
- `release/v.beta.x` → prerelease with `b` tag
- `release/v.rc.x` → prerelease with `rc` tag
- Feature branches → `swa-dev` with `dev` tag

**Verification**:
- `.gitlab-ci.yml` includes `build-module.gitlab-ci.yml` from pipeline fragments at a pinned ref
- `release.config.js` uses `tagFormat: "${version}"`
- `package.json` and `pyproject.toml` version is `0.0.0` for new projects
- `.tarball-exclusions` exists and excludes non-distributable files
- Commit messages follow conventional commit format

---

## Rule IAC-MODULE-11: Community Module Requirements

**Rule**: Modules published as community modules MUST meet additional visibility and documentation requirements.

Requirements:
- Project visibility set to `internal`
- README includes community module disclaimer at the top (no CCP NEXT team support or warranty)
- Apply `ccp-next:community:module` GitLab topic label
- ALL CI/CD jobs passing
- ALL documentation links functional
- CCP NEXT team does NOT own, maintain, or support community modules
- CCP reserves the right to remove non-compliant community modules

**Verification**:
- README contains the community module disclaimer verbatim
- Project has `ccp-next:community:module` topic label applied
- CI/CD pipeline is fully passing
- All links in README and documentation are functional
- Project visibility is set to `internal`
- If not publishing as community module, mark this rule as N/A

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Enforcement |
|---|---|---|
| Requirements Analysis | IAC-MODULE-01, IAC-MODULE-11 | Project type and publishing intent must be captured |
| Application Design | IAC-MODULE-02, IAC-MODULE-03, IAC-MODULE-04 | Module interface design (inputs, outputs, labels) |
| Infrastructure Design | IAC-MODULE-01 through IAC-MODULE-06 | Module structure, examples, and coding standards |
| Code Generation (Planning) | ALL | Code generation plan must address all applicable rules |
| Code Generation (Generation) | IAC-MODULE-01 through IAC-MODULE-09 | Generated code must comply with all rules |
| Build and Test | IAC-MODULE-07, IAC-MODULE-08, IAC-MODULE-09, IAC-MODULE-10 | Testing, scanning, and pipeline instructions |

At each applicable stage:
- Evaluate all IAC-MODULE rule verification criteria against the artifacts produced
- Include an "IaC Module Compliance" section in the stage completion summary listing each rule as compliant, non-compliant, or N/A
- If any rule is non-compliant, this is a blocking IaC module finding — follow the blocking finding behavior defined in the Overview
- Include IAC-MODULE rule references in design documentation and code comments where clarification is needed
