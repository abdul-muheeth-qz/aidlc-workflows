# Shared MR Review Workflow

This document contains the common workflow steps shared by all CCP Next MR review skills (deployment, lambda, module). Each skill's SKILL.md supplies skill-specific values for the angle-bracket placeholders used throughout this document.

## Placeholders

Each skill MUST supply values for these placeholders when following this workflow:

- `<skill-name>` — the skill type (e.g., `Deployment`, `Lambda`, `Module`)
- `<skill-findings-filename>` — the findings JSON filename (e.g., `deployment-mr-review-findings.json`, `lambda-mr-review-findings.json`, `mr-review-findings.json`)
- `<skill-specific-categories>` — the category list for findings (varies per skill; see each skill's SKILL.md for the full list)

---

## Step 1: Identify the MR

Parse the user's input to extract:

- `project_id`: The project path or ID (e.g., `my-group/my-project`)
- `merge_request_iid`: The internal MR number

If the user provides a URL, extract these from the URL pattern:
`https://<host>/<project_path>/-/merge_requests/<iid>`

---

## Step 2: Gather MR context

Use the GitLab MCP tools to collect information:

1. **Get MR details** — call `get_merge_request` with the project ID and MR IID to understand the MR title, description, source/target branches, and author.

2. **Get MR diffs** — call `get_merge_request_diffs` with the project ID and MR IID to retrieve all changed files and their diffs. Paginate through all pages if the MR has many changed files (use `page` and `per_page` params). Do not stop at the first page — collect all diffs.

3. **Get MR commits** — call `get_merge_request_commits` to understand the commit history and messages.

4. **Get pipeline status** — call `get_merge_request_pipelines` to check CI status. If there are failures, call `get_pipeline_jobs` with the pipeline ID to identify which jobs failed and retrieve failure details.

---

## Findings JSON Structure

After completing all review checks (shared + skill-specific), collect all findings and post them as inline comments on the MR. ALL findings MUST be posted as inline MR comments. Additionally, any positive observations, general thoughts, or contextual notes that are not tied to a specific finding should be included in the summary note posted to the MR.

### Individual Finding Structure

Structure every finding as a JSON object with these required fields:

```json
{
  "file": "terraform/main.tf",
  "line": 12,
  "category": "CCP Next",
  "title": "Brief description of the issue",
  "body": "Detailed explanation.\n\n**Suggested fix:** ..."
}
```

Field requirements:

- `file` — string, relative path from repo root (e.g., `terraform/main.tf`, `src/handler.py`, `main.tf`)
- `line` — integer, 1-based line number in the new version of the file
- `category` — one of the skill-specific categories defined in `<skill-specific-categories>`
- `title` — string, concise (under 100 characters)
- `body` — string, markdown-formatted, MUST include a `**Suggested fix:**` section

Every finding MUST include a suggested fix in the body. Do not produce findings without actionable guidance.

### Top-Level Findings JSON Assembly

Wrap all findings into a top-level JSON structure with a `summary` and a `findings` array:

```json
{
  "summary": "## <skill-name> MR Review: <MR title>\n\n**Recommendation:** Approve | Request Changes\n\n| Category | Findings |\n|----------|----------|\n| <category> | <n> |",
  "findings": []
}
```

Summary rules:

- **Recommendation**: Use `Request Changes` if there is at least one finding. Use `Approve` if there are no findings.
- **Category counts**: Show the actual count for each category. Omit categories with zero findings from the table if you prefer a shorter summary, but always include Security, CCP Next, and any skill-specific categories that have findings.
- **General Notes**: Include a section for any positive observations, contextual thoughts, or non-finding commentary about the MR (e.g., "Good use of least-privilege IAM scoping", "Clean tier separation", "Test coverage is solid"). If there are no general notes, omit this section.
- **Finding order**: Order findings by priority — security first, then CCP Next conventions, then OPA Policy, then skill-specific issues, then Checkov, SWA Module, code quality, performance, architecture, commit/branch, README.

Write the findings JSON to a file inside the skill directory: `<skill-directory>/<skill-findings-filename>`.

---

## Reliable JSON Writing Instructions

Do NOT use `fsWrite` or `python3 -c` inline to create the findings JSON file. Large JSON with markdown content (newlines, backticks, asterisks, quotes, backslashes) causes failures:

- `fsWrite` silently produces empty/corrupt files with large payloads
- `python3 -c "..."` hits shell escaping issues that mangle the content
- `python3 << 'HEREDOC'` also fails due to bash tool processing

Instead, **write a temporary Python script file** using `fsWrite`/`fsAppend`, then execute it:

1. Use `fsWrite` to create `<skill-directory>/write_findings.py` with the Python code that builds the findings dict and calls `json.dump`. Use Python parenthesized string concatenation for long strings (this avoids shell escaping entirely).
2. If the script is large, use `fsAppend` to add remaining findings.
3. Run `python3 <skill-directory>/write_findings.py` to generate the JSON file.
4. Validate with `python3 -c "import json; json.load(open('<skill-directory>/<skill-findings-filename>'))"`.
5. After the posting script completes, delete both `write_findings.py` and `<skill-findings-filename>`.

Example `write_findings.py` structure:

```python
import json, os

data = {
    "summary": (
        "## <skill-name> MR Review: <title>\n\n"
        "**Recommendation:** Approve | Request Changes\n\n"
        "| Category | Findings |\n"
        "|----------|----------|\n"
        "| Security | 0 |"
    ),
    "findings": [
        {
            "file": "terraform/main.tf",
            "line": 12,
            "category": "Security",
            "title": "Brief title",
            "body": (
                "Description of the issue.\n\n"
                "**Suggested fix:** Do this instead."
            )
        }
    ]
}

script_dir = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(script_dir, "<skill-findings-filename>")
with open(out, "w") as f:
    json.dump(data, f, indent=2)
print(f"JSON written to {out}")
```

---

## URL-Encoding the Project Path

Before invoking the posting script, URL-encode the project path. Replace `/` with `%2F` in the project path.

Examples:

- `my-group/my-project` → `my-group%2Fmy-project`
- `swa-common/devplat/my-deployment` → `swa-common%2Fdevplat%2Fmy-deployment`

---

## Posting Script Invocation

### Check prerequisites

Before invoking the posting script, check whether the `GITLAB_TOKEN` environment variable is set.

**If GITLAB_TOKEN is NOT set:**

1. Inform the user: "GITLAB_TOKEN is not set — skipping MR comment posting. Findings will be shown in chat only."
2. Skip the posting step entirely and proceed to the Chat Summary step.
3. Do NOT attempt to post comments without a valid token.
4. Do NOT treat this as a review failure — the review itself is complete, only posting was skipped.

**If GITLAB_TOKEN is set**, invoke the posting script:

```bash
bash scripts/post-review-comments.sh "<gitlab_host>" "<url_encoded_project_path>" "<mr_iid>" "<skill-directory>/<skill-findings-filename>"
```

Arguments:

1. `gitlab_host` — the GitLab hostname extracted from the MR URL (e.g., `southwest.gitlab-dedicated.com`)
2. `url_encoded_project_path` — the project path with `/` replaced by `%2F`
3. `mr_iid` — the merge request internal ID
4. findings JSON file path — the path to the findings JSON file written in the previous step

The script will:

1. Fetch the MR `diff_refs` (base_sha, start_sha, head_sha) for inline comment positioning
2. Post each finding as an inline discussion thread at the exact file and line in the MR diff
3. Fall back to posting a general MR note if inline positioning fails for a finding (e.g., the line is not part of the diff)
4. Post the summary as a general MR note after all findings are posted

The script requires the `GITLAB_TOKEN` environment variable set to a GitLab personal access token with `api` scope.

### Handle posting failures

**API failures**: If the posting script reports HTTP errors:

- Report the HTTP status code to the user (e.g., "Failed to post finding — HTTP 403. Check that your GITLAB_TOKEN has `api` scope and the project allows MR comments.")
- The script handles inline-to-fallback logic automatically: if an inline discussion thread fails (e.g., line not in diff), it falls back to posting a general MR note with the file and line in the body.
- If both inline and fallback posting fail for a finding, the script continues with remaining findings and reports the failure count at the end.
- Continue to the Chat Summary step regardless of posting outcome — the user should always receive the chat summary even if posting partially failed.

**Missing dependencies**: If `curl` or `jq` are not installed, the script will fail with an error message. Inform the user which tool is missing.

---

## Chat Summary

After posting (or skipping posting), display a brief summary in chat so the user has a quick overview without opening the MR.

The summary MUST include all of the following:

1. **Posting status**: Whether findings were posted as MR comments, or why posting was skipped (e.g., "GITLAB_TOKEN not set", "posting failed for N findings", "API error with HTTP 403"). Examples:
   - "✅ Findings posted as inline comments on the MR."
   - "⚠️ Posting skipped — GITLAB_TOKEN is not set. Findings shown in chat only."
   - "⚠️ Some comments failed to post (HTTP 422). Check the MR for partial results."

2. **Files reviewed**: The total number of files in the MR diff that were analyzed.

3. **Findings by category**: A count of findings grouped by category. Include all categories that have at least one finding. Use this format:

   ```text
   Findings:
     Security: 1
     CCP Next: 2
     <skill-specific-category>: 1
   ```

   If there are no findings, state: "No findings — the MR is clean."

4. **Overall assessment**: One of:
   - **Approve** — no findings
   - **Request Changes** — at least one finding exists

5. **MR link**: A clickable link to the MR (e.g., `https://gitlab.example.com/group/project/-/merge_requests/123`).

### Example summary for a clean MR

```text
✅ <skill-name> MR Review Complete

Findings posted as inline MR comments.
Files reviewed: 8
No findings — the MR is clean.

Assessment: Approve
MR: https://southwest.gitlab-dedicated.com/my-group/my-project/-/merge_requests/42
```

### Example summary with findings

```text
⚠️ <skill-name> MR Review Complete

Findings posted as inline MR comments.
Files reviewed: 12

Findings:
  Security: 1
  CCP Next: 3
  <skill-specific-category>: 2
  Code Quality: 1

Assessment: Request Changes (7 findings found)
MR: https://southwest.gitlab-dedicated.com/my-group/my-project/-/merge_requests/42
```

### Example summary when posting was skipped

```text
⚠️ <skill-name> MR Review Complete

Findings were NOT posted — GITLAB_TOKEN is not set.
Files reviewed: 12

Findings:
  CCP Next: 2
  <skill-specific-category>: 1

Assessment: Request Changes (3 findings found)
MR: https://southwest.gitlab-dedicated.com/my-group/my-project/-/merge_requests/42

Set GITLAB_TOKEN to a GitLab personal access token with 'api' scope to enable posting findings as MR comments.
```

---

## Review Guidelines

Follow these principles when producing findings:

**Be constructive, not nitpicky.** Focus on issues that matter — security risks, convention violations, real code quality problems, and skill-specific misconfigurations. Do NOT flag style issues that `terraform fmt` or linters handle automatically (indentation, spacing, quote style, trailing whitespace). If a formatting issue is the only problem in a file, skip it. Your job is to catch real problems, not duplicate automated tooling.

**Clean MR = say so.** If the MR has no findings after running all shared and skill-specific checks, report that the MR is clean. Do not invent findings to justify the review. A clean MR is a good outcome and deserves a clear "Approve."

**Reference CCP Next docs.** When flagging convention violations (CCP Next naming, tagging, OPA policies, module sources), include a reference to the relevant CCP Next documentation or policy file so the developer can learn more. For example: "See `ccp-next-opa-policies/policies/ccp/providers_policy/providers_policy.rego` for the approved providers list" or "See `references/ccp-next-conventions.md` for naming conventions."

**Priority order.** When presenting findings, follow this priority order from highest to lowest:

1. **Security** — hardcoded secrets, overly permissive IAM, missing encryption, broad security groups, sensitive outputs, unapproved providers/modules
2. **CCP Next conventions** — naming, tagging, Labels_Module, default_tags, OPA policy violations
3. **OPA Policy** — tagging policy, providers policy, module source policy violations
4. **Skill-specific issues** — apply the skill's own category priorities (e.g., Lambda runtime/packaging/IAM, Module structure/interface, Deployment terraform/terragrunt patterns)
5. **Checkov compliance** — S3, encryption, inline IAM, security groups
6. **SWA Module enforcement** — raw VPC/WAF/API GW resources that should use SWA modules
7. **Code quality** — naming clarity, duplication, dead code, complexity, missing descriptions, for_each vs count
8. **Performance** — unnecessary depends_on, missing lifecycle blocks, redundant data lookups, modularization candidates
9. **Architecture** — multi-repo violations, tight coupling, environment drift, lifecycle mixing
10. **Commit/Branch** — commit message and branch name convention violations
11. **README** — missing, template, or irrelevant README

Security findings always come first.
