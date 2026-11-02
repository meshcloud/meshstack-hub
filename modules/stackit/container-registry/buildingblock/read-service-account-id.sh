#!/usr/bin/env bash
# Prints, as an `external` data source, `{"id": "<uuid>"}` of the service account `email` when it
# belongs to `project_id`, else `{"id": ""}`. Harbor's robot link asks for both email and id.
set -euo pipefail

query="$(cat)"
project_id="$(jq -r '.project_id' <<<"${query}")"
email="$(jq -r '.email' <<<"${query}")"

# Minted here because an `external` data source's `query` and result are stored in state.
access_token="$(bash "$(dirname "$0")/stackit-access-token.sh" | jq -r '.access_token')"

curl --silent --show-error --fail-with-body \
  --retry 3 --retry-connrefused \
  --header "Authorization: Bearer ${access_token}" \
  "https://service-account.api.stackit.cloud/v2/projects/${project_id}/service-accounts" |
  jq -c --arg email "${email}" '{id: ([.items[] | select(.email == $email) | .id] | first // "")}'
