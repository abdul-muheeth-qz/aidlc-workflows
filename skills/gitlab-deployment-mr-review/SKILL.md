---
name: gitlab-deployment-mr-review
description: >
  Reviews GitLab merge requests for CCP Next deployment repositories (Terraform and Terragrunt).
  Applies CCP Next deployment conventions, OPA policy checks, Checkov compliance, SWA module enforcement,
  security, performance, and architecture review. Auto-detects deployment type, fetches MR diffs,
  analyzes changes, and posts findings as inline comments on the MR. Use when the user asks to review
  a merge request for a deployment project (not a module or Lambda project).
---

# GitLab Deployment MR Review

## When to use this skill

Activate this skill when the user asks to:

- Review a deployment merge request (MR)
- Do a code review on a GitLab deployment MR
- Check a deployment MR for issues
- Provide feedback on deployment MR changes
- Review a Terragrunt or Terraform deployment MR
- Review an MR in a repo with `environments/`, `tfvars/`, or deployment-style Makefiles

Do NOT use this skill for module MRs or Lambda MRs — use the module MR review skill or Lambda MR review skill instead. Deployment repos are identified by the presence of `environments/` directories, `tfvars/` directories, Terragrunt `*.hcl` files, or deployment-style Makefiles.

## Prerequisites

- The GitLab MCP server must be connected and authenticated.
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

- `<skill-name>`: **Deployment**
- `<skill-findings-filename>`: **deployment-mr-review-findings.json**
- `<skill-specific-categories>`: `CCP Next`, `OPA Policy`, `Checkov`, `SWA Module`, `Security`, `Code Quality`, `Performance`, `Architecture`, `Deployment`, `Terraform Deployment`, `Terragrunt Deployment`, `Commit/Branch`, `README`, `Environment Drift`

### Step 3: Auto-detect deployment type

Before beginning any review analysis, inspect the MR diff file list to determine the deployment type. Detection MUST complete before the review engine begins analysis.

**Terragrunt deployment** — classify as Terragrunt_Deployment_Repo if ANY of these are true:

- The diff contains `terragrunt.hcl` files at any level
- The diff contains `.hcl` files within an `environments/` directory structure

**Terraform deployment** — classify as Terraform_Deployment_Repo if ALL of these are true:

- The diff contains a `terraform/` directory with `.tf` files
- The diff contains `tfvars/` directories or `.tfvars` files
- The diff does NOT contain any Terragrunt HCL files (`terragrunt.hcl` or `.hcl` files in `environments/`)

**Fallback** — if neither pattern matches, prompt the user to specify the deployment type before proceeding. Do not guess or assume.

Store the detected deployment type for use in subsequent steps. The type determines which deployment-specific checks are applied later.

### Step 4: Load reference material

Read `references/ccp-next-conventions.md` for CCP Next-specific conventions and best practices. Apply these standards during the review.

### Step 5: Shared review checks

Read `references/shared-checks.md` and apply ALL 14 shared checks (sections 1-14) against the MR diff. These checks cover CCP Next conventions, OPA policies, Checkov compliance, SWA module enforcement, security, code quality, performance, architecture, Terraform import warnings, version constraints, commit/branch validation, README validation, project structure validation, and public module reuse.

Complete all shared checks before moving to the deployment-type-specific sections below. Do NOT skip shared checks.

## Terraform Deployment Checks (ONLY apply this section if the repository is classified as a Terraform_Deployment_Repo)

These checks are specific to Terraform deployment repositories. Do NOT apply any of these checks to Terragrunt_Deployment_Repo repositories. This section is self-contained — do not cross-reference the Terragrunt deployment section below.

### 6a.1 tfvars Organization by Environment

Verify that tfvars files are organized by environment. The repository should contain environment-specific tfvars files following the naming convention:

- `lab.tfvars`
- `dev.tfvars`
- `qa.tfvars`
- `prod.tfvars`

These files should be located in a `tfvars/` directory (e.g., `terraform/tfvars/lab.tfvars`). Flag if:

- Expected environment tfvars files are missing (e.g., `prod.tfvars` does not exist)
- tfvars files use non-standard naming (e.g., `production.tfvars` instead of `prod.tfvars`)
- Environment-specific configuration is placed in a single shared tfvars file instead of per-environment files

### 6a.2 S3 Backend Configuration

Verify that the Terraform backend is configured with S3 and includes proper security settings. Check the `terraform` block's `backend "s3"` configuration for:

- **Encryption**: The backend must have `encrypt = true` to ensure state files are encrypted at rest. Flag missing encryption.
- **State locking**: The backend must have state locking configured to prevent concurrent modifications. Two locking mechanisms are valid:
  - **S3 native locking** (preferred for new projects on Terraform ≥ 1.10): The backend specifies `use_lockfile = true`. This uses S3's native conditional writes for locking and does not require a DynamoDB table.
  - **DynamoDB locking** (legacy): The backend specifies a `dynamodb_table` for state locking. This is still valid for existing projects but is no longer required for new CCP Next templates.
  - Flag if neither `use_lockfile = true` nor `dynamodb_table` is present — the backend has no state locking.
  - Do NOT flag a backend that uses `use_lockfile = true` without a `dynamodb_table` — S3 native locking is the recommended approach for new projects.
  - Do NOT flag a backend that uses `dynamodb_table` without `use_lockfile` — DynamoDB locking is still valid for existing projects.
- **Bucket and key**: The backend should reference `state_bucket` and `state_key` values (typically passed via `-backend-config` flags from the Makefile, not hardcoded). Flag hardcoded bucket names or keys.

Example of a correct backend configuration (S3 native locking — preferred for new projects):

```hcl
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
```

Example of a correct backend configuration (DynamoDB locking — legacy, still valid):

```hcl
terraform {
  backend "s3" {
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

### 6a.3 No Hardcoded Environment Values

Verify that environment-specific values are NOT hardcoded in `.tf` files. The following types of values MUST come from tfvars files or data sources:

- **AWS account IDs** (12-digit numeric strings like `123456789012`)
- **VPC IDs** (strings matching `vpc-` prefix)
- **Subnet IDs** (strings matching `subnet-` prefix)
- **Security group IDs** (strings matching `sg-` prefix)
- **Availability zones** (hardcoded AZ names like `us-east-1a`)
- **Region-specific ARNs** with embedded account IDs

Scan all `.tf` files in the diff for these patterns. Flag any hardcoded environment-specific value. The value should instead be defined in the environment's tfvars file and referenced via `var.<name>`, or retrieved via a `data` source (e.g., `data.aws_caller_identity`, `data.aws_vpc`).

### 6a.4 Tier Separation by Lifecycle and Change Frequency

Verify that resources are separated into tiers based on their lifecycle and change frequency. In a well-structured CCP Next Terraform deployment:

- **Networking tier**: VPC, subnets, route tables, NAT gateways — changes infrequently
- **Data tier**: RDS, DynamoDB, S3 buckets — changes infrequently, high-risk
- **Application tier**: Lambda, ECS, API Gateway — changes frequently
- **Monitoring tier**: CloudWatch alarms, dashboards — changes with application

Flag if:

- Resources with different lifecycles are mixed in the same Terraform state (e.g., VPC resources and Lambda functions in the same tier directory)
- A single tier contains both long-lived infrastructure (databases, networking) and frequently-deployed application resources
- There is no clear tier separation (all resources in a single flat directory)

Recommend organizing resources into separate tier directories (e.g., `terraform/tier1-networking/`, `terraform/tier2-data/`, `terraform/tier3-application/`) so that each tier can be planned and applied independently.

### 6a.5 Makefile Alignment with CCP Next Patterns

Verify that Makefile changes align with CCP Next general-resources patterns. If the MR diff includes Makefile changes, check for:

- **Standard targets**: The Makefile should include standard CCP Next targets such as `init`, `plan`, `apply`, `destroy`, and tier-specific variants (e.g., `plan-tier1`, `apply-tier1`).
- **Backend config passing**: The Makefile should pass backend configuration via `-backend-config` flags (e.g., `-backend-config="bucket=$(STATE_BUCKET)"`) rather than hardcoding backend values.
- **tfvars file reference**: Plan and apply targets should reference the correct tfvars file for the target environment (e.g., `-var-file=tfvars/$(ENV).tfvars`).
- **Consistent patterns**: Makefile targets should follow the same patterns as the CCP Next `ccp-next-general-resources` template repository.

Flag deviations from these patterns.

### 6a.6 Restricted tfvars Keys

The following variable keys MUST NOT be set in any `.tfvars` file. These values are injected by the CCP Next pipeline or derived from the environment and must not be overridden:

- `environment`
- `namespace`
- `region`
- `repo_id`
- `state_bucket`
- `state_key`

Scan every `.tfvars` file in the MR diff for any assignment to these keys (e.g., `environment = "dev"`, `region = "us-east-1"`). Flag ANY occurrence of a restricted key in a tfvars file, regardless of the value assigned. The key itself is forbidden in tfvars — the value does not matter.

## Terragrunt Deployment Checks (ONLY apply this section if the repository is classified as a Terragrunt_Deployment_Repo)

These checks are specific to Terragrunt deployment repositories. Do NOT apply any of these checks to Terraform_Deployment_Repo repositories. This section is self-contained — do not cross-reference the Terraform deployment section above.

### 6b.1 Include Blocks Reference Root terragrunt.hcl

Verify that tier-level `terragrunt.hcl` files use `include` blocks to reference a root `terragrunt.hcl` for DRY configuration. In a well-structured Terragrunt deployment:

- A root `terragrunt.hcl` at the top of the `environments/` directory defines shared configuration (remote state, provider generation, common inputs)
- Each tier's `terragrunt.hcl` includes the root config via an `include` block:

```hcl
include "root" {
  path = find_in_parent_folders()
}
```

Flag if:

- A tier-level `terragrunt.hcl` does not contain an `include` block referencing the root config
- The `include` block uses a hardcoded path instead of `find_in_parent_folders()`
- Configuration that belongs in the root `terragrunt.hcl` (e.g., remote state, provider generation) is duplicated in tier-level files

### 6b.2 Dependency Blocks for Cross-Tier References

Verify that cross-tier references use Terragrunt `dependency` blocks, NOT `depends_on`. In Terragrunt:

- `dependency` blocks are the correct mechanism for referencing outputs from other tiers:

```hcl
dependency "networking" {
  config_path = "../tier1-networking"
}

inputs = {
  vpc_id = dependency.networking.outputs.vpc_id
}
```

- `depends_on` is a Terraform-level construct and should NOT be used in `terragrunt.hcl` for cross-tier ordering

Flag if:

- A `terragrunt.hcl` file uses `depends_on` for cross-tier references instead of `dependency` blocks
- Cross-tier values are hardcoded instead of being pulled from `dependency` outputs

Flag if:

- A `dependency` block is missing `mock_outputs` for use during `plan` when the dependency has not yet been applied

### 6b.3 Circular Dependency Detection

Check for circular dependencies between tiers. Analyze the `dependency` blocks across all tier-level `terragrunt.hcl` files in the MR diff to detect cycles.

For example, if tier A depends on tier B and tier B depends on tier A, this creates a circular dependency that will cause `terragrunt run-all` to fail.

Build a dependency graph from the `dependency` blocks:

- For each tier's `terragrunt.hcl`, note which other tiers it depends on via `dependency` blocks
- Check if following the dependency chain leads back to the starting tier

Flag any circular dependency. Include the cycle path in the finding (e.g., "Circular dependency detected: tier1-networking → tier2-data → tier1-networking").

### 6b.4 Unnecessary run_all Usage

Flag unnecessary use of `run-all` (or `run_all`) when only a single tier has changed. Check the MR diff context:

- If the MR only modifies files within a single tier directory (e.g., only `environments/dev/tier2-data/` changed), then using `terragrunt run-all plan` or `terragrunt run-all apply` at the environment level is unnecessary overhead
- The pipeline or Makefile should target the specific tier that changed instead of running all tiers

Flag if:

- Pipeline configuration or Makefile targets use `run-all` commands when the MR scope is limited to a single tier
- There is no conditional logic to detect which tiers changed and scope the Terragrunt command accordingly

Recommend scoping Terragrunt commands to the changed tier for faster and safer deployments.

### 6b.5 TG_WORKING_DIRECTORY Usage

Verify that `TG_WORKING_DIRECTORY` is NOT used in deployment pipeline configurations. The `TG_WORKING_DIRECTORY` environment variable is a Terragrunt feature that overrides the working directory, but it should not be used in CCP Next deployment pipelines because:

- It bypasses the standard directory structure and can lead to unexpected behavior
- The pipeline should use explicit `--terragrunt-working-dir` flags or `cd` into the correct directory instead

Scan the MR diff for any reference to `TG_WORKING_DIRECTORY` in:

- `.gitlab-ci.yml` or CI pipeline configuration files
- Makefile targets
- Shell scripts used by the pipeline

Flag any occurrence and recommend using explicit directory targeting instead.

### 6b.6 No Duplicated Provider and Backend Configuration

Verify that provider and backend configuration is NOT duplicated across tier-level `terragrunt.hcl` files. In a well-structured Terragrunt deployment:

- The root `terragrunt.hcl` uses `generate` blocks to create provider and backend configuration:

```hcl
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = var.region
  default_tags { ... }
}
EOF
}

generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" { ... }
}
EOF
}
```

- Tier-level `terragrunt.hcl` files inherit this via the `include` block and should NOT redefine provider or backend configuration

Flag if:

- Multiple tier-level `terragrunt.hcl` files contain `generate "provider"` or `generate "backend"` blocks
- Provider or backend configuration appears in both the root and tier-level files
- Tier-level files override the root's generated provider or backend without clear justification

Recommend centralizing provider and backend configuration in the root `terragrunt.hcl` and using `include` to inherit it.

### Step 7: Environment Drift Detection

Compare configuration across environments (lab, dev, qa, prod) to detect unjustified differences. Environment drift occurs when configurations diverge without clear intent, leading to inconsistent behavior across environments.

### For Terraform Deployment Repos

Compare tfvars files across environments (`lab.tfvars`, `dev.tfvars`, `qa.tfvars`, `prod.tfvars`). For each variable key present in the MR diff:

- Check if the key exists in all environment tfvars files
- Check if the values differ across environments
- Determine if the difference is intentional or accidental

### For Terragrunt Deployment Repos

Compare `terragrunt.hcl` `inputs` blocks across environment directories (e.g., `environments/lab/`, `environments/dev/`, `environments/qa/`, `environments/prod/`). For each input key present in the MR diff:

- Check if the key exists in all environment configurations
- Check if the values differ across environments
- Determine if the difference is intentional or accidental

### Intentional vs. Unjustified Differences

**Allow** differences that follow a clear scaling pattern across environments:

- Instance sizes scaling up: `t3.small` (lab) → `t3.medium` (dev) → `t3.large` (qa) → `t3.xlarge` (prod)
- Replica counts increasing: `1` (lab) → `1` (dev) → `2` (qa) → `3` (prod)
- Retention periods increasing: `7` (lab) → `14` (dev) → `30` (qa) → `90` (prod)
- Feature flags: disabled in lower environments, enabled in prod
- Capacity/throughput values that scale with environment tier

**Flag** differences that appear unjustified:

- A variable key present in some environments but missing in others (unless it is a new variable being rolled out incrementally)
- Values that differ without a clear scaling pattern (e.g., different CIDR blocks that don't follow a scheme, different resource names that should be consistent)
- Boolean flags that are inconsistent without clear justification (e.g., `enable_monitoring = true` in prod but `false` in qa)
- Configuration that should be identical across environments (e.g., provider versions, module versions, resource types) but differs

When flagging drift, include the specific variable/input key, the values across environments, and a note about why the difference appears unjustified.
