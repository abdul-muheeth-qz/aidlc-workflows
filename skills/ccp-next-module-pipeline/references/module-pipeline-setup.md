# Module Pipeline Setup

## How to include

Module projects include the pipeline in their `.gitlab-ci.yml`:

```yaml
include:
  - project: swa-common/devplat/ccp-next/ccp-next-pipeline-fragments
    ref: <latest-version>
    file: pipelines/build-module.gitlab-ci.yml
```

This single include pulls in everything: linting, testing, scanning, publishing, semantic release, pre-commit, spellcheck, and version checking. The pipeline is composed of layered includes internally — the consumer project doesn't need to know about them.

## Pipeline Inputs

These are passed via the `inputs:` block when including the pipeline:

| Input | Default | What it controls |
| --- | --- | --- |
| `aws-account-checkout-disabled` | `null` | Set to `'true'` to use mocked AWS providers in terraform test instead of real accounts |
| `aws-account-number` | `null` | Override which AWS account terraform test runs against |
| `node-version` | `${NODE_VERSION}` | Node.js version. Use format `"24"` or `"lts/jod"`. Must exist on the runner image |
| `python-versions` | `['3.12']` | Python versions for linting and testing |
| `semantic-release_dependency-management` | `self-managed` | `self-managed` means you manage your own release config and plugins. `provided` means the pipeline provides defaults |
| `test-terraform_rules` | (default chain) | Override when terraform test runs. Default: skip if disabled, run on MR/push/tag when `.tf` files exist |
| `publish-module_dependencies` | `[get-next-version]` | What `publish:module` waits for. Add `build:js` or `build:python` here if your module includes built artifacts |

## Stages

Jobs run in this order:

```text
.pre → setup → lint → build → post_build → test → security_scans → publish → release → deploy
```

The `publish` stage is for staging releases (MR). The `deploy` stage is for the real `publish:module` (tag pipeline). This naming is a GitLab convention — nothing is actually "deployed" in a module pipeline.

## Workflow Rules

These determine whether a pipeline runs at all:

**Pipeline runs for:**

- MR pipelines (`merge_request_event`)
- Push to protected or default branches
- Semver tags (e.g., `v1.2.0`) from `chore(release)` commits

**Pipeline does NOT run for:**

- Renovate onboarding commits (`chore(deps): configure renovate`)
- `chore(release)` commits on branches — only on the tag they create
- Non-semver tags
- Branch pipelines when an MR is already open (prevents duplicate pipelines)

## Variables

### Module Identity

| Variable | Default | Purpose |
| --- | --- | --- |
| `MODULE_NAME` | `${CI_PROJECT_NAME}` | Name used in the registry. Spaces and underscores auto-convert to hyphens |
| `MODULE_SYSTEM` | `aws` | Provider system (appears in registry path) |
| `MODULE_VERSION` | `${CI_COMMIT_TAG}` | Set automatically from the semver tag |
| `MODULE_STAGING_ENABLED` | (not set) | Set to `'true'` to enable publishing from MR pipelines |
| `TARBALL_EXCLUDE_FILE` | `.tarball-exclusions` | File listing paths to exclude from the published tarball |

### Job Toggles

CCP Next toggle variables follow this pattern: **empty string `''` = enabled, `'true'` = disabled**. This is worth noting since it trips people up.

Jobs that are disabled by default (you opt IN):

| Variable | Controls |
| --- | --- |
| `PYTHON_BUILD_DISABLED: 'true'` | Python package build |
| `NODEJS_BUILD_DISABLED: 'true'` | Node.js build |
| `NODEJS_PACKAGE_DISABLED: 'true'` | Node.js packaging |
| `PYTHON_PUBLISH_DISABLED: 'true'` | Python publish |
| `PYTHON_PUBLISH_DEV_DISABLED: 'true'` | Python dev publish |

Jobs that are enabled by default (you opt OUT):

| Variable | Controls |
| --- | --- |
| `CHECKOV_STATIC_SCAN_DISABLED` | Checkov static scan |
| `ATTEST_CHECKOV_STATIC_SCAN_DISABLED` | Checkov attestation |
| `TERRAFORM_TEST_DISABLED` | Terraform test |
| `TERRA_LINT_DISABLED` | tflint |
| `PYTHON_LINT_DISABLED` | Python linting (black + ruff) |
| `PYTHON_TEST_DISABLED` | Python testing (pytest) |
| `NODEJS_LINT_DISABLED` | Node.js linting (ESLint) |
| `NODEJS_TEST_DISABLED` | Node.js testing |
| `GRADLE_BUILD_DISABLED` | Gradle build |
| `GRADLE_TEST_DISABLED` | Gradle testing |
| `SEMANTIC_RELEASE_DISABLED` | Semantic release |
| `CCP_NEXT_VERSION_CHECKER_DISABLED` | Version checker |

To disable an enabled-by-default job, set its variable to `'true'` in your `.gitlab-ci.yml`:

```yaml
variables:
  TERRAFORM_TEST_DISABLED: 'true'
```

To enable a disabled-by-default job, unset or clear the variable:

```yaml
variables:
  NODEJS_BUILD_DISABLED: ''
```

### Python Package Manager

The pipeline auto-detects your package manager:

- `poetry.lock` exists → Poetry
- `uv.lock` exists → UV
- Both can coexist. Disable one with `POETRY_DISABLED: 'true'` or `UV_DISABLED: 'true'`

### Language Detection

Jobs only run when the relevant files exist in the project. This is checked via GitLab's `exists:` rule against the project at `$CI_COMMIT_SHA`:

| Language | Files checked |
| --- | --- |
| Terraform | `**/**.tf`, `**/**.tftest.hcl` |
| Python | `**/**.py` |
| Node.js | `{src,test,tests}/**/*.{js,jsx,ts,tsx}` |
| Gradle | `**/gradlew`, `**/build.gradle`, `**/settings.gradle` |

If a job you expect isn't running, the most likely cause is that the file detection didn't match.

## Semantic Versioning

The pipeline uses `semantic-release` to automatically version and tag:

| Commit prefix | Version bump | Example |
| --- | --- | --- |
| `fix: ...` | Patch | 1.0.0 → 1.0.1 |
| `feat: ...` | Minor | 1.0.0 → 1.1.0 |
| `BREAKING CHANGE:` in footer | Major | 1.0.0 → 2.0.0 |

**Important details:**

- `perf:` commits do NOT trigger version bumps
- Prefixes like `chore:`, `docs:`, `style:`, `refactor:`, `ci:`, `test:` do NOT trigger releases — they're valid conventional commits but semantic-release skips them
- `BREAKING CHANGE:` must appear in the **commit footer**, not the subject line. The subject still needs a prefix like `feat:` or `fix:`
- If every commit since the last tag uses non-releasing prefixes (e.g., all `chore:` or `docs:`), no new version is created — this is expected behavior, not a bug
- Squash merges combine all MR commits into one — only the squashed commit message matters for versioning. If the squash message doesn't have `fix:` or `feat:`, no release happens

Requirements:

- `release.config.{cjs,js,mjs}` must exist in the project root
- Pipeline must be on a protected or default branch push
- Commit message must match the conventional format

The release job creates a `chore(release): X.Y.Z` commit and a `vX.Y.Z` tag. That tag triggers a new pipeline where `publish:module` runs.
