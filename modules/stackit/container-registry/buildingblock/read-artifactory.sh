#!/usr/bin/env bash
# The create response carries placeholder Harbor project id 0; only a later read of the artifactory
# returns the real id the browser link needs.
set -euo pipefail

api_host="${STACKIT_REGISTRY_API_HOST:-https://registry.api.stackit.cloud}"
registry_host="${STACKIT_REGISTRY_HOST:-https://registry.onstackit.cloud}"

deadline_seconds="${ARTIFACTORY_TIMEOUT_SECONDS:-600}"
interval_seconds="${ARTIFACTORY_INTERVAL_SECONDS:-10}"

query="$(cat)"
project_id="$(printf '%s' "${query}" | jq -r '.project_id')"
region="$(printf '%s' "${query}" | jq -r '.region')"
artifactory_id="$(printf '%s' "${query}" | jq -r '.artifactory_id')"

# Minted here because an `external` data source's `query` is printed in the plan.
access_token="$(bash "$(dirname "$0")/stackit-access-token.sh" | jq -r '.access_token')"

probe_url="${api_host}/v1/projects/${project_id}/regions/${region}/artifactories/${artifactory_id}"

started_at="${SECONDS}"
attempt=0

while true; do
  attempt=$((attempt + 1))

  # No --fail: a non-200 is the answer being polled for.
  response="$(curl --silent --output - --write-out '\n%{http_code}' \
    --retry 3 --retry-connrefused \
    --header "Authorization: Bearer ${access_token}" \
    "${probe_url}")"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  case "${status}" in
  200)
    state="$(printf '%s' "${body}" | jq -r '.state // "UNKNOWN"')"
    url="$(printf '%s' "${body}" | jq -r '.url // ""')"

    # An Active artifactory can still report the placeholder id for a few seconds.
    if [[ "${state}" == "Active" && -n "${url}" && ! "${url}" =~ /projects/0(/|$) ]]; then
      if [[ ! "${url}" =~ ^https?:// ]]; then
        url="${registry_host}${url}"
      fi
      echo "artifactory ${artifactory_id} is Active after ${attempt} attempt(s), $((SECONDS - started_at))s" >&2
      jq -n --arg url "${url}" '{url: $url}'
      exit 0
    fi
    ;;
  404)
    state="ABSENT"
    ;;
  *)
    echo "unexpected status ${status} reading ${probe_url}:" >&2
    echo "${body}" >&2
    exit 1
    ;;
  esac

  if ((SECONDS - started_at >= deadline_seconds)); then
    echo "artifactory ${artifactory_id} is still ${state} after ${deadline_seconds}s (${attempt} attempts)." >&2
    echo "Re-running this building block is safe and usually succeeds." >&2
    exit 1
  fi

  sleep "${interval_seconds}"
done
