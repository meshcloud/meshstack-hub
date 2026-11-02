#!/usr/bin/env bash
# The STACKIT provider does this exchange internally but never exposes the token, so it is repeated
# here as in stackit-sdk-go's WorkloadIdentityFederationFlow.
set -euo pipefail

token_endpoint="${STACKIT_IDP_TOKEN_ENDPOINT:-https://accounts.stackit.cloud/oauth/v2/token}"
federated_token_file="${STACKIT_FEDERATED_TOKEN_FILE:-/var/run/secrets/stackit.cloud/serviceaccount/token}"

if [[ -z "${STACKIT_SERVICE_ACCOUNT_EMAIL:-}" ]]; then
  echo "STACKIT_SERVICE_ACCOUNT_EMAIL is not set" >&2
  exit 1
fi

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

# `set -e` does not catch a failing `jq -e` inside an assignment.
if ! access_token="$(printf '%s' "${response}" | jq -er '.access_token')"; then
  echo "token endpoint returned no access_token" >&2
  exit 1
fi

jq -n --arg access_token "${access_token}" '{access_token: $access_token}'
