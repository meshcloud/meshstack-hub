#!/usr/bin/env bash
# Prints the instance's users as `{"<lowercase email>": "<username>"}` for an `external` data source,
# or `{}` while no instance of that name exists or it has never served users.
set -euo pipefail

query="$(cat)"
access_token="$(jq -r '.access_token' <<<"${query}")"
instances_url="https://git.api.stackit.cloud/v1beta/projects/$(jq -r '.project_id' <<<"${query}")/instances"

get() {
  local url="$1" body
  body="$(curl --silent --show-error --fail-with-body --retry 5 --retry-all-errors \
    --header "Authorization: Bearer ${access_token}" "${url}")" || {
    printf 'GET %s answered: %s\n' "${url}" "${body}" >&2
    return 1
  }
  printf '%s' "${body}"
}

instance="$(get "${instances_url}" | jq -c --arg name "$(jq -r '.instance_name' <<<"${query}")" \
  '[.instances[] | select(.name == $name)][0] // empty')"
# Any other state, Ready included, can briefly answer 404 on its users; reporting no users would
# remove every team member.
case "$(jq -r '.state // "Missing"' <<<"${instance:-null}")" in
Missing | Creating | WaitingForResources | Error | Deleting)
  printf '{}'
  exit 0
  ;;
*) ;;
esac
instance_id="$(jq -r '.id' <<<"${instance}")"

users='{}'
page=1
total_pages=1
while ((page <= total_pages)); do
  body="$(get "${instances_url}/${instance_id}/users?page=${page}")"
  users="$(jq -c --argjson acc "${users}" '$acc + ([(.users // [])[] | {key: (.email | ascii_downcase), value: .username}] | from_entries)' <<<"${body}")"
  total_pages="$(jq -r '.totalPages // 1' <<<"${body}")"
  page=$((page + 1))
done

printf '%s' "${users}"
