#!/usr/bin/env bash
# Role assignments apply asynchronously and the provider does not retry the 403. `editor` can list
# federations and the backplane's `iam.service-account-admin` cannot, so a 200 means the role landed.
set -euo pipefail

token_endpoint="${STACKIT_IDP_TOKEN_ENDPOINT:-https://accounts.stackit.cloud/oauth/v2/token}"
federated_token_file="${STACKIT_FEDERATED_TOKEN_FILE:-/var/run/secrets/stackit.cloud/serviceaccount/token}"
api_host="${STACKIT_SERVICE_ACCOUNT_API_HOST:-https://service-account.api.stackit.cloud}"

deadline_seconds="${FEDERATION_ACCESS_TIMEOUT_SECONDS:-300}"
interval_seconds="${FEDERATION_ACCESS_INTERVAL_SECONDS:-5}"

for required in STACKIT_SERVICE_ACCOUNT_EMAIL PROJECT_ID TARGET_SERVICE_ACCOUNT_EMAIL; do
  if [[ -z "${!required:-}" ]]; then
    echo "${required} is not set" >&2
    exit 1
  fi
done

if [[ ! -r "${federated_token_file}" ]]; then
  echo "federated token file ${federated_token_file} is not readable" >&2
  exit 1
fi

response="$(curl --silent --show-error --fail-with-body \
  --request POST "${token_endpoint}" \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode 'client_assertion_type=urn:schwarz:params:oauth:client-assertion-type:workload-jwt' \
  --data-urlencode "client_assertion=$(cat "${federated_token_file}")" \
  --data-urlencode "client_id=${STACKIT_SERVICE_ACCOUNT_EMAIL}")"

# One token for all probes proves an already-issued token sees the new role.
# `set -e` does not catch a failing `jq -e` inside an assignment.
if ! access_token="$(printf '%s' "${response}" | jq -er '.access_token')"; then
  echo "token endpoint returned no access_token" >&2
  exit 1
fi

probe_url="${api_host}/v2/projects/${PROJECT_ID}/service-accounts/${TARGET_SERVICE_ACCOUNT_EMAIL}/federations"

started_at="${SECONDS}"
attempt=0

while true; do
  attempt=$((attempt + 1))

  # No --fail: a 403 is the answer being polled for; --retry only covers connection blips.
  body="$(curl --silent --output - --write-out '\n%{http_code}' \
    --retry 3 --retry-connrefused \
    --header "Authorization: Bearer ${access_token}" \
    "${probe_url}")"
  status="${body##*$'\n'}"

  if [[ "${status}" == "200" ]]; then
    echo "federation access effective after ${attempt} attempt(s), $((SECONDS - started_at))s" >&2
    exit 0
  fi

  if [[ "${status}" != "403" ]]; then
    echo "unexpected status ${status} probing ${probe_url}:" >&2
    echo "${body%$'\n'*}" >&2
    exit 1
  fi

  if (( SECONDS - started_at >= deadline_seconds )); then
    echo "role assignment still not effective after ${deadline_seconds}s (${attempt} attempts)." >&2
    echo "Re-running this building block is safe and usually succeeds." >&2
    exit 1
  fi

  sleep "${interval_seconds}"
done
