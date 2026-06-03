#!/usr/bin/env bash
# Fetches key job info and the last 200 lines of a GitLab job trace.
#
# Usage: bash scripts/fetch-job-logs.sh <gitlab_job_url>
# Requires: GITLAB_TOKEN environment variable (read_api scope)

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "ERROR: Missing job URL." >&2
  echo "Usage: $0 <gitlab_job_url>" >&2
  exit 1
fi

JOB_URL="$1"

if [[ -z "${GITLAB_TOKEN:-}" ]]; then
  echo "ERROR: GITLAB_TOKEN is not set." >&2
  echo "Either set it with: export GITLAB_TOKEN=<your-token>" >&2
  echo "Or paste the job logs directly into chat." >&2
  exit 1
fi

if [[ "$JOB_URL" =~ ^(https?://[^/]+)/(.+)/-/jobs/([0-9]+) ]]; then
  GITLAB_HOST="${BASH_REMATCH[1]}"
  PROJECT_PATH="${BASH_REMATCH[2]}"
  JOB_ID="${BASH_REMATCH[3]}"
else
  echo "ERROR: Could not parse job URL: $JOB_URL" >&2
  exit 1
fi

ENCODED_PATH="${PROJECT_PATH//\//%2F}"
API="${GITLAB_HOST}/api/v4/projects/${ENCODED_PATH}/jobs/${JOB_ID}"

echo "=== JOB INFO ==="
METADATA=$(curl --silent --fail-with-body --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "${API}" 2>&1) || {
  echo "ERROR: Failed to fetch job metadata." >&2; exit 1
}

echo "$METADATA" | jq -r '"Job: \(.name) | Stage: \(.stage) | Status: \(.status) | Failure: \(.failure_reason // "none") | Duration: \(.duration // 0)s | Allow Failure: \(.allow_failure) | Tag: \(.tag) | Ref: \(.ref) | Source: \(.pipeline.source) | Commit: \(.commit.title) | Pipeline: \(.pipeline.web_url)"'

echo ""
echo "=== JOB TRACE (last 200 lines) ==="
curl --silent --fail-with-body --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "${API}/trace" 2>&1 | tail -200 || {
  echo "ERROR: Failed to fetch job trace." >&2; exit 1
}
