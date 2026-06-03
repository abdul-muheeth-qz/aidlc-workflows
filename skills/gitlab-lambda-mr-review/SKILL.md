---
name: gitlab-lambda-mr-review
description: >
  Reviews GitLab merge requests for CCP Next Lambda project repositories.
  Applies shared CCP Next convention checks (naming, tagging, OPA policies, Checkov compliance,
  SWA module enforcement, security, code quality, performance, architecture) followed by
  Lambda-specific checks (directory structure, runtime deprecation, packaging/handler validation,
  execution role IAM, Lambda Terraform patterns). Fetches MR diffs via the GitLab MCP server,
  analyzes changes, and posts findings as inline comments on the MR.
  Use when the user asks to review a merge request for a Lambda project (not a module or deployment project).
---

# GitLab Lambda MR Review

## When to use this skill

Activate this skill when the user asks to:

- Review a Lambda merge request (MR)
- Do a code review on a GitLab Lambda MR
- Check a Lambda MR for issues
- Provide feedback on Lambda MR changes
- Review an MR in a repo with `src/`, `layer/`, and `terraform/` directories (Lambda project layout)

Do NOT use this skill for module MRs or deployment MRs — use the module MR review skill or deployment MR review skill instead. Lambda repos are identified by the presence of `src/` (function source code), `layer/` (layer dependencies), and `terraform/` (infrastructure) directories.

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

- `<skill-name>`: **Lambda**
- `<skill-findings-filename>`: **lambda-mr-review-findings.json**
- `<skill-specific-categories>`: `CCP Next`, `OPA Policy`, `Checkov`, `SWA Module`, `Security`, `Code Quality`, `Performance`, `Architecture`, `Commit/Branch`, `README`, `Lambda Structure`, `Lambda Runtime`, `Lambda Packaging`, `Lambda IAM`, `Lambda Terraform`

### Step 3: Load reference material

Read `references/ccp-next-conventions.md` for CCP Next-specific conventions and best practices. Apply these standards during the review.

### Step 4: Shared review checks

Read `references/shared-checks.md` and apply ALL 14 shared checks (sections 1–14) against the MR diff. These checks cover CCP Next conventions, OPA policies, Checkov compliance, SWA module enforcement, security, code quality, performance, architecture, Terraform import warnings, version constraints, commit/branch validation, README validation, project structure validation, and public module reuse.

Complete all shared checks before moving to the Lambda-specific section below. Do NOT skip shared checks even if the MR has no Terraform changes — commit/branch and README checks still apply.

### Step 5: Lambda-Specific Checks (ONLY apply this section for Lambda project repositories)

This section contains checks that are specific to CCP Next Lambda project repositories. These checks apply IN ADDITION to all shared checks from Step 4. Do NOT skip shared checks — always run Step 4 first, then apply these Lambda-specific checks.

Lambda repos are identified by the presence of `src/` (function source code), `layer/` (layer dependencies), and `terraform/` (infrastructure) directories. If the MR diff does not contain this directory structure, note that Lambda-specific checks could not be fully applied due to missing directory structure, but still run all shared checks.

#### 5.1 Lambda Directory Structure Validation

CCP Next Lambda projects follow a strict directory layout. Inspect every file path in the MR diff and flag files that are in the wrong directory.

**Expected directory structure:**

```text
<project_root>/
├── src/              # Lambda function source code (.py, .js, .ts, .go, .java)
├── layer/            # Lambda layer dependencies (requirements.txt, package.json)
├── terraform/        # All Terraform infrastructure files (.tf)
├── pyproject.toml    # Python project/dependency management
├── uv.lock or poetry.lock  # Dependency lock file
├── README.md
└── ...
```

**Checks:**

- **Source code files outside src/**: Flag any source code file (`.py`, `.js`, `.ts`, `.go`, `.java`) that is placed at the project root or in any directory other than `src/` (or its subdirectories). Files like `README.md`, `Makefile`, configuration files (`.json`, `.yaml`, `.yml`, `.toml`), and CI/CD files are excluded from this check. Flag with category `Lambda Structure`.

- **Terraform files outside terraform/**: Flag any `.tf` file placed at the project root instead of under the `terraform/` directory. All Terraform infrastructure files (`main.tf`, `variables.tf`, `outputs.tf`, `provider.tf`, `versions.tf`, etc.) MUST be under `terraform/`. Flag with category `Lambda Structure`.

- **Layer dependency files outside layer/**: Flag layer dependency files (`requirements.txt`, `package.json`, `package-lock.json`, `Gemfile`, `go.mod`) placed at the project root or in directories other than `layer/` (or its subdirectories). Note: a `package.json` in `src/` for Node.js Lambda source is acceptable if the project uses a bundled packaging approach, but `requirements.txt` at the root is always a misplacement for Lambda repos. Flag with category `Lambda Structure`.

- **Missing pyproject.toml**: Flag if no `pyproject.toml` file exists at the project root. CCP Next projects use `pyproject.toml` for Python dependency and project management (pre-commit, linting, build tooling). Flag with category `Lambda Structure`.

- **Missing lock file**: Flag if neither `uv.lock` nor `poetry.lock` exists at the project root alongside `pyproject.toml`. A lock file ensures reproducible dependency resolution. Flag with category `Lambda Structure`.

**Suggested fix format**: "Move `<file>` to `<correct_directory>/`. CCP Next Lambda projects require source code in `src/`, layer dependencies in `layer/`, and Terraform files in `terraform/`."

- **Validate findings against actual content before flagging**: Before flagging a missing or misplaced file, scan the actual content of the relevant directory and files to verify the finding is relevant. Do not flag a missing file if the project functions correctly without it. For example, do not flag a missing `variables.tf` in a subdirectory if that directory declares no variables beyond what inherited or symlinked files already provide. The goal is to catch genuine structural gaps, not enforce a rigid file checklist that produces false positives.

#### 5.2 Lambda Runtime Policy Checks

The CCP Next pipeline enforces a Lambda runtime deprecation policy via OPA. Catch deprecated runtime usage before the pipeline fails.

**Reference**: `ccp-next-opa-policies/policies/ccp/lambda_runtime_policy/lambda_runtime_policy.rego`

**Deprecated runtimes** (from `lambda_runtime_policy.rego` — this is the authoritative list, do NOT maintain a separate list):

```text
dotnet6, python3.8, nodejs16.x, dotnet7, java8, go1.x, provided, ruby2.7,
nodejs14.x, python3.7, dotnetcore3.1, nodejs12.x, python3.6, dotnet5.0,
dotnetcore2.1, nodejs10.x, ruby2.5, python2.7, nodejs8.10, nodejs4.3,
nodejs4.3-edge, nodejs6.10, dotnetcore1.0, dotnetcore2.0, nodejs
```

**Checks:**

- **Direct `aws_lambda_function` resources**: Inspect the `runtime` attribute of every `aws_lambda_function` resource in the MR diff. If the runtime value matches any entry in the deprecated runtimes list above, flag with category `Lambda Runtime`.

- **Module arguments**: If the MR uses a Lambda module (e.g., a CCP Next Lambda module or `terraform-aws-modules/lambda/aws`), check any `runtime` argument passed to the module. If the runtime value matches a deprecated runtime, flag with category `Lambda Runtime`.

**Suggested fix format**: "Runtime `<runtime>` is deprecated per CCP Next Lambda runtime policy. Update to a supported runtime (e.g., `python3.12`, `nodejs20.x`, `java21`). See `ccp-next-opa-policies/policies/ccp/lambda_runtime_policy/lambda_runtime_policy.rego` for the full deprecated list."

#### 5.3 Lambda Packaging and Handler Validation

Verify that Lambda packaging configuration correctly references source code in the `src/` directory.

**Checks:**

- **source_path validation**: Inspect `source_path` attributes in Lambda function resources, packaging resources (e.g., `archive_file` data sources used for Lambda zips), or module arguments. The `source_path` MUST point to a file or directory within `src/`. Flag any `source_path` that references a path outside `src/` (e.g., pointing to the project root, `terraform/`, or `layer/`) with category `Lambda Packaging`.

- **Python handler validation**: For Lambda functions using a Python runtime (`python3.x`), the `handler` attribute should follow the pattern `<module_name>.<function_name>`. Verify that `src/<module_name>.py` exists (check the MR diff for the file, or note if it cannot be verified from the diff alone). If the handler references a module that does not appear to exist in `src/`, flag with category `Lambda Packaging`.

  Example: `handler = "handler.lambda_handler"` → verify `src/handler.py` exists.

- **Node.js handler validation**: For Lambda functions using a Node.js runtime (`nodejs*.x`), the `handler` attribute should follow the pattern `<file_name>.<export_name>`. Verify that `src/<file_name>.js` or `src/<file_name>.mjs` exists (check the MR diff for the file, or note if it cannot be verified from the diff alone). If the handler references a file that does not appear to exist in `src/`, flag with category `Lambda Packaging`.

  Example: `handler = "index.handler"` → verify `src/index.js` or `src/index.mjs` exists.

- **Handler paths outside src/**: Flag any `handler` value that explicitly references a path outside `src/` (e.g., `terraform/handler.lambda_handler` or `../handler.lambda_handler`) with category `Lambda Packaging`.

**Suggested fix format**: "Update `source_path` to point to a file or directory within `src/`. CCP Next Lambda projects keep all function source code in the `src/` directory." / "Verify that handler `<handler>` corresponds to an existing file in `src/`. Expected `src/<module_name>.py` for Python or `src/<file_name>.js` for Node.js."

#### 5.4 Lambda Execution Role IAM Checks

Lambda execution roles MUST follow strict least-privilege principles. Unlike module repos where SRE modules may receive exceptions for broad service permissions, Lambda execution roles have NO exceptions — every wildcard is flagged.

**Checks:**

- **Wildcard resource ARNs**: Flag any IAM policy statement attached to a Lambda execution role (via `aws_iam_role_policy`, `aws_iam_policy` attached to the Lambda role, or inline policy in the role) that uses `"*"` as a resource ARN. This includes `"Resource": "*"` and `"Resource": ["*"]`. Flag with category `Lambda IAM`.

- **Wildcard actions**: Flag any IAM policy statement attached to a Lambda execution role that uses `"*"` as an action. This includes `"Action": "*"` and `"Action": ["*"]`. Also flag overly broad action patterns like `"s3:*"` or `"dynamodb:*"` when the function only needs specific operations. Flag with category `Lambda IAM`.

- **Excessive permissions**: Flag Lambda execution roles that grant permissions beyond what the function requires. For example:
  - Full S3 access (`s3:*`) when the function only reads from a single bucket
  - Full DynamoDB access (`dynamodb:*`) when the function only queries a single table
  - Access to services not referenced in the Lambda function code or configuration
  - Flag with category `Lambda IAM`.

- **Specific resource ARNs**: Verify that managed policies or inline policies attached to the Lambda execution role use specific resource ARNs rather than broad wildcards. For example, `arn:aws:s3:::my-bucket/*` is acceptable, but `arn:aws:s3:::*` is not. Flag broad ARN patterns with category `Lambda IAM`.

- **No SRE exception**: Unlike module repos where SRE-maintained modules may use broader permissions for cross-account or multi-service orchestration, Lambda execution roles enforce strict least-privilege with NO exceptions. Every wildcard in a Lambda execution role is a finding.

**Suggested fix format**: "Lambda execution role uses wildcard `<wildcard>` in `<action|resource>`. Scope to specific `<actions|resource ARNs>` required by the function. Lambda execution roles must follow strict least-privilege with no exceptions."

#### 5.5 Lambda Terraform Patterns

Verify Lambda-specific Terraform configuration patterns.

**Checks:**

- **Missing timeout**: Flag any `aws_lambda_function` resource that does not define a `timeout` attribute. The default Lambda timeout is 3 seconds, which is often insufficient. Recommend setting an explicit timeout based on the function's expected execution time. Flag with category `Lambda Terraform`.

- **Missing memory_size**: Flag any `aws_lambda_function` resource that does not define a `memory_size` attribute. The default is 128 MB, which may be insufficient for many workloads. Recommend setting an explicit memory size based on the function's requirements. Flag with category `Lambda Terraform`.

- **Environment variable secrets**: Inspect the `environment` block of `aws_lambda_function` resources. Flag any environment variable value that resembles a secret, token, or credential. Look for patterns such as:
  - Values starting with `AKIA` (AWS access key IDs)
  - Values starting with `sk-` or `sk_` (API secret keys)
  - Variable names containing `PASSWORD`, `SECRET`, `TOKEN`, `CREDENTIAL`, `API_KEY`, `PRIVATE_KEY` with hardcoded (non-reference) values
  - Long base64-encoded strings that look like credentials
  - Recommend using AWS Secrets Manager or SSM Parameter Store instead of hardcoded values. Flag with category `Lambda Terraform`.

- **Approved Lambda resource types**: Verify that Lambda functions use either a direct `aws_lambda_function` resource or an approved CCP Next Lambda module. Flag any third-party or unapproved Lambda module that is not from the approved module sources (see section 4.2 module source policy). Flag with category `Lambda Terraform`.

- **Labels_Module naming for Lambda resources**: Verify that `aws_lambda_function` resource names (the `function_name` attribute) reference `module.root_labels.id` or a child labels module for consistent naming. Flag hardcoded function names that do not use the Labels_Module with category `Lambda Terraform`.

**Suggested fix format**: "Add explicit `timeout` to `aws_lambda_function.<name>`. The default 3-second timeout is often insufficient." / "Add explicit `memory_size` to `aws_lambda_function.<name>`. The default 128 MB may be insufficient." / "Environment variable `<var_name>` appears to contain a hardcoded secret. Use AWS Secrets Manager or SSM Parameter Store instead." / "Lambda function name should reference `module.root_labels.id` for consistent CCP Next naming."

#### 5.6 Labels Module Usage (Lambda terraform/ directory)

All AWS resources in the Lambda project's `terraform/` directory MUST use the Labels_Module for consistent naming and tagging. This check reinforces the shared Labels_Module check (section 4.1) with Lambda-specific context.

**Checks:**

- **Resource names**: Every AWS resource in `terraform/` that supports a `name` or `name_prefix` argument MUST reference `module.root_labels.id` (or a child labels module like `module.<child>_labels.id`). Flag hardcoded resource names (string literals not referencing the labels module) with category `Lambda Terraform`.

  Examples of correct usage:

  ```hcl
  resource "aws_lambda_function" "this" {
    function_name = module.root_labels.id
    # ...
  }

  resource "aws_sqs_queue" "this" {
    name = "${module.root_labels.id}-queue"
    # ...
  }
  ```

  Examples of incorrect usage (flag these):

  ```hcl
  resource "aws_lambda_function" "this" {
    function_name = "my-hardcoded-function-name"  # Should use module.root_labels.id
    # ...
  }
  ```

- **Resource tags**: Every AWS resource in `terraform/` that supports a `tags` argument MUST reference `module.root_labels.tags` (or a child labels module). Flag hardcoded tags maps that do not reference the labels module with category `Lambda Terraform`. Note: resources that rely solely on the AWS provider `default_tags` (section 4.1) are acceptable if the provider is correctly configured.

  Examples of correct usage:

  ```hcl
  resource "aws_sqs_queue" "this" {
    name = "${module.root_labels.id}-queue"
    tags = module.root_labels.tags
  }
  ```

  Examples of incorrect usage (flag these):

  ```hcl
  resource "aws_sqs_queue" "this" {
    name = "my-queue"
    tags = {
      Name = "my-queue"  # Should use module.root_labels.tags
    }
  }
  ```

- **Hardcoded names and tags**: Flag any AWS resource that uses a hardcoded string literal for its name or a hardcoded map for its tags instead of referencing the Labels_Module. Flag with category `Lambda Terraform`.

**Suggested fix format**: "Resource `<resource_type>.<resource_name>` uses a hardcoded name. Use `module.root_labels.id` for consistent CCP Next naming." / "Resource `<resource_type>.<resource_name>` uses hardcoded tags. Use `module.root_labels.tags` for consistent CCP Next tagging."
