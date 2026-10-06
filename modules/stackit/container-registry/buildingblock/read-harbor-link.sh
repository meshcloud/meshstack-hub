#!/usr/bin/env bash
# Harbor answers 401 to a STACKIT service account until a robot is linked to it in the portal, and no
# API reports the link otherwise. The robots are declared only when this says linked, so it runs while
# planning, before the registry's suffixed name is known: it finds the registry by its base name.
set -euo pipefail

api_host="${STACKIT_REGISTRY_API_HOST:-https://registry.api.stackit.cloud}"

query="$(cat)"
project_id="$(printf '%s' "${query}" | jq -r '.project_id')"
region="$(printf '%s' "${query}" | jq -r '.region')"
registry_name="$(printf '%s' "${query}" | jq -r '.registry_name')"
registry_host="$(printf '%s' "${query}" | jq -r '.registry_host')"

# Minted here because an `external` data source's `query` and result are stored in state.
credentials="$(bash "$(dirname "$0")/stackit-access-token.sh")"
access_token="$(printf '%s' "${credentials}" | jq -r '.access_token')"
service_account_email="$(printf '%s' "${credentials}" | jq -r '.service_account_email')"

report() {
  jq -n --arg linked "$1" '{linked: $linked}'
  exit 0
}

fail() {
  echo "$1" >&2
  exit 1
}

list_url="${api_host}/v1/projects/${project_id}/regions/${region}/artifactories"
response="$(curl --silent --output - --write-out '\n%{http_code}' \
  --retry 3 --retry-connrefused \
  --header "Authorization: Bearer ${access_token}" \
  "${list_url}")"
status="${response##*$'\n'}"
body="${response%$'\n'*}"

case "${status}" in
200) ;;
403)
  # The first apply enables the service. Before that the project has no registry to link.
  if [[ "$(printf '%s' "${body}" | jq -r '.message // ""')" == "Service not enabled" ]]; then
    report false
  fi
  fail "unexpected status 403 listing ${list_url}: ${body}"
  ;;
*)
  fail "unexpected status ${status} listing ${list_url}: ${body}"
  ;;
esac

mapfile -t registries < <(printf '%s' "${body}" | jq -r --arg base "${registry_name}" \
  '.artifactories[] | select(.state == "Active" and (.name | test("^" + $base + "-[a-z0-9]{4}$"))) | .name')

case "${#registries[@]}" in
0) report false ;;
1) ;;
*) fail "several active registries match ${registry_name}: ${registries[*]}" ;;
esac

probe_url="https://${registry_host}/api/v2.0/projects/${registries[0]}"
# The credentials go through stdin so they do not show up in the process list.
status="$(printf 'user = "%s:%s"\n' "${service_account_email}" "${access_token}" |
  curl --silent --output /dev/null --write-out '%{http_code}' \
    --retry 3 --retry-connrefused \
    --config - \
    --header 'X-Is-Resource-Name: true' \
    "${probe_url}")"

case "${status}" in
401) report false ;;
# 403 still means Harbor knows the identity: a robot that may only manage robots cannot read the project.
200 | 403) report true ;;
*) fail "unexpected status ${status} probing ${probe_url}" ;;
esac
