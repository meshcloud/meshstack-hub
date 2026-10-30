#!/usr/bin/env bash
# The STACKIT provider can report a new instance ready while its users endpoint still answers 404
# ("failed to fetch admin PAT") or 500, so three answers in a row have to succeed.
set -euo pipefail

: "${PROJECT_ID:?}" "${INSTANCE_ID:?}"
users_url="https://git.api.stackit.cloud/v1beta/projects/${PROJECT_ID}/instances/${INSTANCE_ID}/users"
deadline=$((SECONDS + 600))
successes=0

while true; do
  access_token="$(bash "$(dirname "$0")/stackit-access-token.sh" | jq -r '.access_token')"
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' \
    --header "Authorization: Bearer ${access_token}" "${users_url}" || true)"
  if [[ "${status}" == 200 ]]; then
    successes=$((successes + 1))
  else
    successes=0
  fi
  if ((successes == 3)); then
    echo "instance ${INSTANCE_ID} serves its API"
    exit 0
  fi
  if ((SECONDS >= deadline)); then
    echo "instance ${INSTANCE_ID} still answers HTTP ${status} after 10 minutes" >&2
    exit 1
  fi
  echo "instance ${INSTANCE_ID} answers HTTP ${status}, waiting"
  sleep 10
done
