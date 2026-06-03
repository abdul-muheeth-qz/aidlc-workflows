#!/usr/bin/env bash
#
# Posts review findings as inline diff comments on a GitLab merge request.
#
# Usage:
#   ./post-review-comments.sh <gitlab_host> <project_path> <mr_iid> <findings_json>
#
# Environment:
#   GITLAB_TOKEN — GitLab personal access token with api scope (required)
#
# Arguments:
#   gitlab_host   — GitLab hostname (e.g., southwest.gitlab-dedicated.com)
#   project_path  — URL-encoded project path (e.g., swa-common%2Fdevplat%2Fmy-project)
#   mr_iid        — Merge request internal ID
#   findings_json — Path to a JSON file containing review findings
#
# Findings JSON format:
#   {
#     "summary": "Overall review summary text",
#     "findings": [
#       {
#         "file": "main.tf",
#         "line": 12,
#         "category": "CCP Next",
#         "title": "Brief title",
#         "body": "Description of the issue and suggested fix"
#       }
#     ]
#   }
#
# The script:
#   1. Fetches the MR diff_refs (base_sha, start_sha, head_sha) needed for positioning
#   2. Posts each finding as an inline discussion thread on the specific file and line
#   3. Falls back to a general MR note if inline positioning fails
#   4. Posts the summary as a general MR note

set -euo pipefail

if [ $# -ne 4 ]; then
  echo "Usage: $0 <gitlab_host> <project_path> <mr_iid> <findings_json>"
  exit 1
fi

GITLAB_HOST="$1"
PROJECT_PATH="$2"
MR_IID="$3"
FINDINGS_JSON="$4"
API_BASE="https://${GITLAB_HOST}/api/v4/projects/${PROJECT_PATH}/merge_requests/${MR_IID}"

if [ -z "${GITLAB_TOKEN:-}" ]; then
  echo "Error: GITLAB_TOKEN environment variable is not set."
  echo "Set it to a GitLab personal access token with 'api' scope."
  exit 1
fi

if [ ! -f "$FINDINGS_JSON" ]; then
  echo "Error: Findings file not found: $FINDINGS_JSON"
  exit 1
fi

# Validate required tools
for cmd in curl jq; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: $cmd is required but not installed."
    exit 1
  fi
done

# --- Step 1: Fetch MR diff refs for inline positioning ---
echo "Fetching MR diff refs..."
MR_DATA=$(curl -sf \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  "${API_BASE}")

BASE_SHA=$(echo "$MR_DATA" | jq -r '.diff_refs.base_sha')
START_SHA=$(echo "$MR_DATA" | jq -r '.diff_refs.start_sha')
HEAD_SHA=$(echo "$MR_DATA" | jq -r '.diff_refs.head_sha')

if [ "$BASE_SHA" = "null" ] || [ "$START_SHA" = "null" ] || [ "$HEAD_SHA" = "null" ]; then
  echo "Error: Could not retrieve diff_refs from MR. Check MR IID and permissions."
  exit 1
fi

echo "  base_sha:  $BASE_SHA"
echo "  start_sha: $START_SHA"
echo "  head_sha:  $HEAD_SHA"

# --- Step 2: Post inline findings as discussion threads ---
FINDING_COUNT=$(jq '.findings | length' < "$FINDINGS_JSON")
POSTED=0
FAILED=0

echo "Posting $FINDING_COUNT inline finding(s)..."

if [ "$FINDING_COUNT" -eq 0 ]; then
  echo "  No findings to post."
fi

for i in $(seq 0 $((FINDING_COUNT - 1))); do
  # Skip if no findings (macOS seq 0 -1 still iterates once)
  [ "$FINDING_COUNT" -eq 0 ] && break
  FILE=$(jq -r ".findings[$i].file" < "$FINDINGS_JSON")
  LINE=$(jq -r ".findings[$i].line" < "$FINDINGS_JSON")
  CATEGORY=$(jq -r ".findings[$i].category" < "$FINDINGS_JSON")
  TITLE=$(jq -r ".findings[$i].title" < "$FINDINGS_JSON")
  BODY=$(jq -r ".findings[$i].body" < "$FINDINGS_JSON")

  COMMENT_BODY="$(printf '%s — %s\n\n%s' "$CATEGORY" "$TITLE" "$BODY")"

  # Build the discussion payload with position for inline comment
  PAYLOAD=$(jq -n \
    --arg body "$COMMENT_BODY" \
    --arg base_sha "$BASE_SHA" \
    --arg start_sha "$START_SHA" \
    --arg head_sha "$HEAD_SHA" \
    --arg new_path "$FILE" \
    --arg old_path "$FILE" \
    --argjson new_line "$LINE" \
    '{
      body: $body,
      position: {
        position_type: "text",
        base_sha: $base_sha,
        start_sha: $start_sha,
        head_sha: $head_sha,
        new_path: $new_path,
        old_path: $old_path,
        new_line: $new_line
      }
    }')

  HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --request POST \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "$PAYLOAD" \
    "${API_BASE}/discussions")

  if [ "$HTTP_STATUS" -ge 200 ] && [ "$HTTP_STATUS" -lt 300 ]; then
    echo "  ✓ $FILE:$LINE — $TITLE"
    POSTED=$((POSTED + 1))
  else
    echo "  ✗ $FILE:$LINE — $TITLE (HTTP $HTTP_STATUS)"
    # Fall back to a general note if inline positioning fails
    FALLBACK_BODY="$(printf '%s — %s\n**File:** `%s` (line %s)\n\n%s' "$CATEGORY" "$TITLE" "$FILE" "$LINE" "$BODY")"
    FALLBACK_PAYLOAD=$(jq -n --arg body "$FALLBACK_BODY" '{ body: $body }')

    FALLBACK_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
      --request POST \
      --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
      --header "Content-Type: application/json" \
      --data "$FALLBACK_PAYLOAD" \
      "${API_BASE}/notes")

    if [ "$FALLBACK_STATUS" -ge 200 ] && [ "$FALLBACK_STATUS" -lt 300 ]; then
      echo "    ↳ Posted as general comment instead (HTTP $FALLBACK_STATUS)"
      POSTED=$((POSTED + 1))
    else
      echo "    ↳ Fallback also failed (HTTP $FALLBACK_STATUS)"
      FAILED=$((FAILED + 1))
    fi
  fi

  # Rate limit: avoid hitting GitLab API limits on MRs with many findings
  sleep 0.5
done

# --- Step 3: Post summary as a general MR note ---
SUMMARY=$(jq -r '.summary // empty' < "$FINDINGS_JSON")

if [ -n "$SUMMARY" ]; then
  echo "Posting review summary..."
  SUMMARY_PAYLOAD=$(jq -n --arg body "$SUMMARY" '{ body: $body }')

  SUMMARY_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    --request POST \
    --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
    --header "Content-Type: application/json" \
    --data "$SUMMARY_PAYLOAD" \
    "${API_BASE}/notes")

  if [ "$SUMMARY_STATUS" -ge 200 ] && [ "$SUMMARY_STATUS" -lt 300 ]; then
    echo "  ✓ Summary posted (HTTP $SUMMARY_STATUS)"
  else
    echo "  ✗ Summary failed (HTTP $SUMMARY_STATUS)"
    FAILED=$((FAILED + 1))
  fi
fi

echo ""
echo "Done. Posted: $POSTED, Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
