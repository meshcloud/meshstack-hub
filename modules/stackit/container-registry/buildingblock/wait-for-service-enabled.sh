#!/usr/bin/env bash
# Enabling a service answers 202 and reconciles later; until then dependent APIs answer
# `403 Service not enabled`, which the restapi provider does not retry.
set -euo pipefail

api_host="${STACKIT_SERVICE_ENABLEMENT_API_HOST:-https://service-enablement.api.stackit.cloud}"

deadline_seconds="${SERVICE_ENABLEMENT_TIMEOUT_SECONDS:-600}"
interval_seconds="${SERVICE_ENABLEMENT_INTERVAL_SECONDS:-10}"

for required in ACCESS_TOKEN PROJECT_ID REGION SERVICE_ID; do
  if [[ -z "${!required:-}" ]]; then
    echo "${required} is not set" >&2
    exit 1
  fi
done

probe_url="${api_host}/v2/projects/${PROJECT_ID}/regions/${REGION}/services/${SERVICE_ID}"

started_at="${SECONDS}"
attempt=0

while true; do
  attempt=$((attempt + 1))

  # No --fail: a non-200 is the answer being polled for; --retry only covers connection blips.
  response="$(curl --silent --output - --write-out '\n%{http_code}' \
    --retry 3 --retry-connrefused \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${probe_url}")"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  case "${status}" in
    200)
      # A never-requested service has no state rather than DISABLED.
      state="$(printf '%s' "${body}" | jq -r '.state // "UNKNOWN"')"
      if [[ "${state}" == "ENABLED" ]]; then
        echo "${SERVICE_ID} is ENABLED after ${attempt} attempt(s), $((SECONDS - started_at))s" >&2
        exit 0
      fi
      ;;
    404)
      state="ABSENT"
      ;;
    *)
      echo "unexpected status ${status} probing ${probe_url}:" >&2
      echo "${body}" >&2
      exit 1
      ;;
  esac

  if (( SECONDS - started_at >= deadline_seconds )); then
    echo "${SERVICE_ID} is still ${state} after ${deadline_seconds}s (${attempt} attempts)." >&2
    echo "Re-running this building block is safe and usually succeeds." >&2
    exit 1
  fi

  sleep "${interval_seconds}"
done
