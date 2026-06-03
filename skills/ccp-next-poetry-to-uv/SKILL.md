---
name: ccp-next-poetry-to-uv
description: >
  Migrates CCP Next projects from Poetry to UV. Scans and fixes everything automatically —
  pyproject.toml, Makefile, release.config.js, .pre-commit-config.yaml, .gitlab-ci.yml,
  Terraform, and Lambda layers. No prompts required. Use when a customer wants to switch
  their project from Poetry to UV.
---

# Poetry to UV Migration

UV support requires `ccp-next-pipeline-fragments >= 2.15.5` and `ccp-next-general-resources >= 2.5.0`. Pipelines auto-detect UV when `uv.lock` is present.

## When to use this skill

Activate this skill when the user asks to:

- Migrate a project from Poetry to UV
- Convert a deployment, module, or Lambda project to use UV
- Switch the package manager from Poetry to UV

## pyproject.toml Reference

### Deployment/module projects

The sections below are always required for every project:

```toml
[project]
name = "your-project"
version = "1.0.0"
authors = [{email = "<team@example.com>", name = "Your Team"}]
dependencies = [
  "boto3>=1.34.113",
  "requests>=2.32.3",
]
description = "your description"
readme = "README.md"
requires-python = ">=3.12,<4.0"

[dependency-groups]
dev = [
  "ccp-next-general-resources>=2.5.0,<3.0",
  "checkov>=3.2.353,<4",
  "coverage>=7.10.7,<8",
  "pre-commit>=4.3.0,<5",
  "pytest-cov>=5.0.0,<6",
  "pytest>=8.4.2,<9",
]
lint = [
  "black>=26.1.0,<27",
  "ruff>=0.15.0,<0.16",
]

[tool.uv]
index-url = "https://nexus-tools.swacorp.com/repository/all-pypi/simple"
native-tls = true
package = false

[[tool.uv.index]]
name = "swa-pypi"
url = "https://nexus-tools.swacorp.com/repository/pypi/simple"

[[tool.uv.index]]
name = "swa-releases"
url = "https://nexus-tools.swacorp.com/repository/pypi-releases/simple"

[[tool.uv.index]]
explicit = true
name = "swa-dev"
url = "https://nexus-tools.swacorp.com/repository/pypi-dev/simple"

[tool.tomlsort]
all = true
in_place = true
sort_first = ["project", "dependency-groups", "tool", "tool.uv"]
spaces_before_inline_comment = 2
trailing_comma_inline_array = true
overrides."project".first = ["name", "version"]
overrides."tool.tomlsort.sort_first".inline_arrays = false
```

`native-tls = true` uses the system TLS — SWA certs are already installed, no extra config needed. `package = false` means this project is not a published library. Omit it only for published packages using `uv_build` (like `ccp-next-general-resources` itself).

Do not add a `[[tool.uv.index]]` entry named `swa` pointing to `all-pypi/simple`. That URL is already covered by `index-url` at the top of `[tool.uv]`. Only the three named indexes above (`swa-pypi`, `swa-releases`, `swa-dev`) belong in the index list.

Runtime dependencies (packages the Lambda function itself imports, like `boto3` and `requests`) go in `[project].dependencies`, not in `[dependency-groups].dev`. Only tooling used during development and testing goes in `[dependency-groups].dev`.

After applying the required sections above, scan the rest of the file. If additional tool sections exist (like `[tool.black]` or `[tool.ruff]`), check them for structural issues caused by the Poetry migration — dotted inline keys, misplaced `[lint.*]` sections, outdated `target-version` values. Fix those issues but do not add sections that are not already there.

### Lambda layer projects

Layer `pyproject.toml` uses `dependencies` in `[project]` directly — these are runtime packages for Lambda, not dev tooling:

```toml
[project]
name = "layer-name"
version = "0.0.1"
dependencies = ["requests>=2.7,<3"]
requires-python = ">=3.12,<4.0"

[tool.uv]
index-url = "https://nexus-tools.swacorp.com/repository/all-pypi/simple"
native-tls = true
package = false

[[tool.uv.index]]
name = "swa-pypi"
url = "https://nexus-tools.swacorp.com/repository/pypi/simple"

[[tool.uv.index]]
name = "swa-releases"
publish-url = "https://nexus-tools.swacorp.com/repository/pypi-releases/"
url = "https://nexus-tools.swacorp.com/repository/pypi-releases/simple"

[[tool.uv.index]]
explicit = true
name = "swa-dev"
publish-url = "https://nexus-tools.swacorp.com/repository/pypi-dev/"
url = "https://nexus-tools.swacorp.com/repository/pypi-dev/simple"

[tool.tomlsort]
all = true
in_place = true
sort_first = ["project", "dependencies", "tool", "tool.uv"]
spaces_before_inline_comment = 2
trailing_comma_inline_array = true
overrides."project".first = ["name", "version"]
overrides."tool.tomlsort.sort_first".inline_arrays = false
```

## Migration Steps

### Step 1: Determine what needs changing

Scan the project and build a list of what still needs to be done:

- Check for `poetry.lock` (needs migration) vs `uv.lock` (already done)
- Check pipeline fragment version in `.gitlab-ci.yml` — must be `>= 2.15.5`
- Find all `pyproject.toml` files — includes root, `layer/`, and any `examples/` fixtures
- Check Makefile for all `poetry` references including custom targets
- Check `release.config.js` for `poetry` references and for `successComment` (needs to become `successCommentCondition`)
- Check `release.config.js` git assets list for `uv.lock` — add it if missing
- Check `.pre-commit-config.yaml` for `poetry.lock`
- Check `.gitlab-ci.yml` for `poetry install`, `poetry run`, and `python-poetry` Docker image
- Check Terraform for `poetry_install`, `lambda_layer_poetry`, `lambda_function_poetry`, and `poetry/` S3 paths
- Check if `pyproject.toml` already has a `[project]` section (hybrid template)
- Check `examples/fixtures/` for Poetry fixture directories that need UV equivalents created alongside them

Skip any step that is already done.

### Step 2: Update all pyproject.toml files

For each `pyproject.toml` found (root, `layer/`, `examples/` fixtures):

**Root project:** Remove `[tool.poetry]`, `[tool.poetry.dependencies]`, `[tool.poetry.group.*.dependencies]`, `[build-system]`, `dynamic = ["dependencies"]` from `[project]`, and `homepage` and `repository` fields from `[project]` if present. Some projects already have a partial `[project]` section — keep existing fields (`name`, `version`, `authors`, `description`, `readme`, `requires-python`) and just remove the Poetry-specific parts. Replace the entire tool configuration with the UV configuration from the reference above. The reference shows the complete expected shape of the file — use it as the target, not just a partial guide.

Runtime deps from `[tool.poetry.dependencies]` (excluding `python`) go into `[project].dependencies`. Dev deps from `[tool.poetry.group.dev.dependencies]` go into `[dependency-groups].dev`. Use `>=x.y.z,<next-major` version constraints, not Poetry's `^x.y.z` caret syntax.

When updating `[dependency-groups].dev`, use the full three-part minimum version for `ccp-next-general-resources`. Write `"ccp-next-general-resources>=2.5.0,<3.0"` not `"ccp-next-general-resources>=2.5,<3"`.

If the project has `[tool.ruff]` with dotted inline keys like `lint.ignore`, `lint.select`, or `lint.unfixable`, convert them to proper TOML subsections (`[tool.ruff.lint]`, `[tool.ruff.lint.flake8-annotations]`, etc.). Similarly, any top-level `[lint.*]` sections that are not nested under `[tool.ruff]` are misplaced — move them to `[tool.ruff.lint.*]`. Check the project's target branch or the latest version of the template to confirm the current expected ruff config shape, and align to that. Remove any ruff settings that no longer exist in the version of ruff the project uses. Update `target-version` in `[tool.ruff]` and `[tool.black]` to match the Python versions the project currently targets — check the target branch for the correct values rather than assuming specific versions.

**If the project looks different from the reference:** The reference is based on the lambda template. Other projects may have fewer sections, different dependency groups, no `[tool.black]` or `[tool.ruff]` at all, or additional custom sections. That is fine. The migration rules that apply to every project are the same regardless of shape:

- Remove all `[tool.poetry*]` and `[build-system]` sections
- Remove `dynamic = ["dependencies"]` from `[project]`
- Remove `[project.urls]` if present
- Add `[tool.uv]` and the three `[[tool.uv.index]]` entries
- Move runtime deps to `[project].dependencies`
- Move dev deps to `[dependency-groups]` groups using `>=x.y.z,<next-major` constraints
- Update `[tool.tomlsort]` to use `sort_first = ["project", "dependency-groups", "tool", "tool.uv"]`
- Fix any structural issues in existing tool sections (like misplaced `[lint.*]` or dotted ruff keys) but do not add tool sections that were not already there

When in doubt about what a section should look like after migration, check the project's target branch. That is always the source of truth over the reference in this document.

**Layer and example fixtures:** Use the layer pattern — `dependencies` in `[project]` directly, not `[dependency-groups]`. This applies to `layer/pyproject.toml`, `examples/fixtures/poetry_layer/pyproject.toml`, `examples/fixtures/poetry_deps_in_docker/pyproject.toml`, and any other fixture that has a `[tool.poetry.dependencies]` section. When migrating, set the `name` field to reflect UV (e.g. `layer-uv`, `lambdatwodeps`) and update the `description` to reference UV instead of Poetry.

### Step 3: Rename and reorganize example fixtures

If the project has `examples/fixtures/` directories that contain Poetry-based `pyproject.toml` files or Docker images using `python-poetry`, create UV equivalents alongside them. Do not delete the Poetry fixture directories — they stay to show the Poetry pattern.

For each Poetry fixture directory, create a matching UV fixture directory with the same structure. Update the `pyproject.toml` to use the UV layer pattern. If the fixture has a `docker/` subdirectory with a `Dockerfile` referencing a `python-poetry` image, create a matching UV docker fixture using the `python-build` image instead:

```dockerfile
ARG BUILD_PLATFORM="linux/amd64"

FROM --platform=${BUILD_PLATFORM} 290503755741.dkr.ecr.us-east-1.amazonaws.com/swa-common/ccp/docker/python-build/amazonlinux2023:0.1.0

USER swa-user

COPY --chown=swa-user:swa-user entrypoint.sh /home/swa-user/entrypoint.sh

RUN chmod +x /home/swa-user/entrypoint.sh

ENTRYPOINT [ "/home/swa-user/entrypoint.sh" ]
```

Copy `entrypoint.sh` as-is from the Poetry fixture — it does not need changes.

Also check all other fixture subdirectories (such as `src_multiple_lambdas/`) for any `pyproject.toml` files that still have Poetry content and migrate them using the layer pattern.

### Step 4: Generate lock files

Run `uv lock` in every directory that contains a `pyproject.toml` that was migrated or newly created in this migration. That includes the root, `layer/`, and any UV fixture directories under `examples/fixtures/`.

Do not run `uv lock` in directories that intentionally keep Poetry content — those stay unchanged.

### Step 5: Update pipeline fragment version

Only needed if below `2.15.5`. If on `1.x.x`, do not upgrade without reviewing breaking changes — use the pipeline upgrade assistant agent.

### Step 6: Update Makefile

Replace all Poetry references:

| Poetry | UV |
| -------- | ---- |
| `poetry install` | `uv sync --all-groups` |
| `poetry install --no-dev` | `uv sync --no-group dev` |
| `poetry lock` | `uv lock` |
| `poetry run <cmd>` | `uv run <cmd>` |
| `poetry add <pkg>` | `uv add <pkg>` |
| `poetry remove <pkg>` | `uv remove <pkg>` |
| `poetry version` | `uv version` |
| `poetry show <pkg>` | `uv tree --package <pkg>` |

Replace `setup-poetry` with `setup-uv`:

```makefile
setup-uv: ## setup python virtual environment
    @if [ -f $(GENERAL_RESOURCES) ] && grep -q '^setup-uv:' $(GENERAL_RESOURCES); then \
        $(MAKE) --no-print-directory -f $(GENERAL_RESOURCES) setup-uv; \
    else \
        if [[ -d .venv ]]; then \
            uv run python --version >/dev/null 2>&1 || rm -rf .venv; \
        fi; \
        if [[ -f uv.lock ]]; then \
            uv lock $(OPTS_UV_LOCK); \
            uv sync $(OPTS_UV_SYNC); \
        fi; \
    fi
```

Replace `setup-local`:

```makefile
setup-local: FORCE setup-uv ## setup local environment
    @uv tree --package ccp-next-general-resources >/dev/null 2>&1 || { \
        printf "\e[31;1m[ERROR] %s\e[0m\n" "'ccp-next-general-resources' py package not installed."; \
        exit 1; \
    }
    @PROJECT_TYPE=$(PROJECT_TYPE) uv run install-ccp-next-general-resources
```

Update header comments to reference `uv` instead of `poetry`.

### Step 7: Update release.config.js

This step is always required. Open `release.config.js` and check it regardless of what the scan found.

Do not rename this file to `release.config.mjs`. Keep it as `release.config.js`.

```js
// Before
var execSetVersionPoetry = "poetry version $VERSION";
// After
var execSetVersionUv = "uv version $VERSION";
```

Add `uv.lock` to the git assets list. The assets array should look like this after the change:

```js
assets: [
  "package-lock.json",
  "package.json",
  "pyproject.toml",
  "uv.lock",
],
```

Also check the `gitlabConfig` block. If it has `successComment: false`, change it to `successCommentCondition: false`:

```js
// Before
var gitlabConfig = [
  "@semantic-release/gitlab",
  {
    failComment: false,
    failTitle: false,
    gitlabUrl: process.env.CI_SERVER_URL,
    successComment: false,
  },
]
// After
var gitlabConfig = [
  "@semantic-release/gitlab",
  {
    failComment: false,
    failTitle: false,
    gitlabUrl: process.env.CI_SERVER_URL,
    successCommentCondition: false,
  },
]
```

### Step 8: Update .pre-commit-config.yaml

Change `poetry.lock` to `uv.lock` in the exclude block (top-level or inside `toml-sort-fix`).

### Step 9: Update environments.yml

Search for any `poetry run` references in comments inside `environments.yml` and replace with `uv run`. The most common one is the `POST_DEPLOY_CMD` comment:

```yaml
# Before
# # Command to run for post-deploy jobs. Defaults to `poetry run pytest`
# After
# # Command to run for post-deploy jobs. Defaults to `uv run pytest`
```

### Step 10: Update .gitlab-ci.yml

For each `poetry` reference:

- Replace `poetry install` with `uv sync --all-groups`
- Replace `poetry install --with dev` with `uv sync --all-groups`
- Replace `poetry run <cmd>` with `uv run <cmd>`
- Replace `python-poetry` Docker image with `python-build`:

```yaml
# Before
image: ...swa-common/ccp/docker/python-poetry/amazonlinux2023:5.0.2
# After
image: ...swa-common/ccp/docker/python-build/amazonlinux2023:0.1.0
```

Remove any `python-poetry` component includes — UV support is built into `ccp-next-pipeline-fragments >= 2.15.5`.

### Step 11: Update Terraform

For each `.tf` file with `poetry` references:

- Rename `module "lambda_layer_poetry"` to `module "lambda_layer_uv"` and update all references
- Rename `module "lambda_function_poetry"` to `module "lambda_function_uv"` and update all references
- Replace `poetry_install = true` with `uv_install = true`
- Replace `poetry/` with `uv/` in S3 bucket paths, IAM resource ARNs, and `s3:prefix` conditions
- Update the `function_name`, `description`, and layer `description` strings to reference UV instead of Poetry
- Update the top-of-file comments in `main.tf`, `outputs.tf`, and `variables.tf` to use a space after the hash character and reference UV instead of Poetry
- In `outputs.tf`, update all `module.lambda_function_poetry.*` and `module.lambda_layer_poetry.*` references to use the new UV module names

`uv_install` requires `terraform-aws-modules/lambda/aws >= 8.4.0`.

Check any module version pins in the Terraform files. If a module version is pinned to a value that no longer matches what the project's target branch uses, update it to match. Do not assume a specific version — check the target branch or the latest template to confirm the correct value.

After renaming the modules, check whether the project has an IAM policy that grants S3 access for the layer. If the policy has resource ARNs or `s3:prefix` conditions referencing `poetry/`, update them to `uv/`. If no such policy exists yet, add one. The policy should allow `s3:GetObject` and `s3:ListBucket` on the S3 bucket, scoped to the `uv/*` prefix:

```hcl
resource "aws_iam_policy" "lambda_s3_access" {
  name_prefix = "${module.root_labels.id}-lambda-policy"
  path        = "/"
  description = "IAM policy for accessing S3 for Lambda function with specific prefix"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${local.s3_bucket}",
          "arn:aws:s3:::${local.s3_bucket}/uv/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::${local.s3_bucket}"
        Condition = {
          StringLike = {
            "s3:prefix" = ["uv/*"]
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_s3_access.arn
}
```

### Step 12: Remove Poetry files

Find and remove all `poetry.lock` and `poetry.toml` files anywhere in the project tree. This includes the root, `layer/`, and any fixture or example subdirectories that were migrated.

```sh
find . -name "poetry.lock" -not -path "*/node_modules/*" -delete
find . -name "poetry.toml" -not -path "*/node_modules/*" -delete
rm -rf .venv
```

Leave `poetry.lock` files in place only in directories that intentionally keep Poetry content as reference fixtures.

### Step 13: Opt into Kiro tooling

```sh
make setup-kiro
```

### Step 14: Verify the migration

```sh
uv sync --all-groups
make setup
make test-python
make setup-kiro
```

If `make test-python` fails with `No such file or directory: pytest`, run `uv sync --all-groups` first — projects with separate `test` or `deploy` dependency groups need all groups synced.

## Lambda Layer Notes

In Poetry, runtime deps in `[tool.poetry.dependencies]` were installed into the dev environment automatically. In UV, the layer is a separate project — its deps are not in the root dev environment.

If tests import layer packages, add them to the root `[dependency-groups].dev`:

```toml
[dependency-groups]
dev = [
  "ccp-next-general-resources>=2.5.0,<3.0",
  "pytest>=7.1.2",
  # runtime deps also needed for local test execution
  "requests>=2.7,<3",
]
```

## How the Distributed Makefiles Handle UV

The Makefiles from `ccp-next-general-resources` auto-detect the package manager based on which lock file is present. Once `uv.lock` exists, `$(_RUN_PY)` resolves to `uv run` automatically — no changes needed to the distributed Makefile targets.

## Troubleshooting

**Certificate errors:** Ensure `native-tls = true` is set. Check these env vars are not set: `CURL_CA_BUNDLE`, `REQUESTS_CA_BUNDLE`, `SSL_CERT_DIR`, `SSL_CERT_FILE`.

**Lock file issues:** `rm uv.lock && uv lock` or `uv lock --upgrade`

**Dependency conflicts:** `uv cache clean && uv lock`
