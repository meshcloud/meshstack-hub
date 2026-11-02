#!/usr/bin/env bash
# Prints, as an `external` data source, `{"<email>": "unknown" | "<role>,<role>"}` for the
# comma-separated `emails`. STACKIT refuses a role assignment for a subject without a STACKIT
# account, and only the user memberships API tells such a subject apart; an account that does not
# exist yet but holds a role (an invitation) counts as known. The caller needs `iam.member.get` on
# the resource.
set -euo pipefail

query="$(cat)"
resource_type="$(jq -r '.resource_type' <<<"${query}")"
resource_id="$(jq -r '.resource_id' <<<"${query}")"
mapfile -t emails < <(jq -r '.emails | split(",")[] | select(. != "")' <<<"${query}")

# Minted here because an `external` data source's `query` and result are stored in state.
access_token="$(bash "$(dirname "$0")/stackit-access-token.sh" | jq -r '.access_token')"

api_get() {
  curl --silent --output - --write-out '\n%{http_code}' \
    --retry 3 --retry-connrefused \
    --header "Authorization: Bearer ${access_token}" \
    "$1"
}

result='{}'

for email in "${emails[@]}"; do
  response="$(api_get "https://authorization.api.stackit.cloud/v2/users/$(jq -rn --arg e "${email}" '$e | @uri')/memberships?resourceType=${resource_type}&resourceId=${resource_id}")"
  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  if [[ "${status}" == 200 ]]; then
    state="$(jq -r '[.items[].role] | unique | join(",")' <<<"${body}")"
  elif [[ "${status}" == 400 && "$(jq -r '.message // ""' <<<"${body}" 2>/dev/null)" == *"subject is not found"* ]]; then
    state=unknown
  else
    echo "unexpected status ${status} looking up ${email}: ${body}" >&2
    exit 1
  fi
  result="$(jq -c --arg email "${email}" --arg state "${state}" '. + {($email): $state}' <<<"${result}")"
done

printf '%s' "${result}"
