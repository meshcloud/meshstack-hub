#!/usr/bin/env bash
# Mints a STACKIT access token from the Workload Identity Federation credentials meshStack injects,
# and prints it as the JSON object an `external` data source expects.
#
# The STACKIT Terraform provider performs this same exchange internally but exposes no way to read
# the resulting token back, and this module's REST calls need one. The request mirrors
# WorkloadIdentityFederationFlow in stackit-sdk-go (core/clients/workload_identity_flow.go).
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

# `jq -e` exits non-zero when the token is absent or null, which `set -e` would swallow inside the
# assignment, so the failure is handled here instead.
if ! access_token="$(printf '%s' "${response}" | jq -er '.access_token')"; then
  echo "token endpoint returned no access_token" >&2
  exit 1
fi

jq -n --arg access_token "${access_token}" '{access_token: $access_token}'
