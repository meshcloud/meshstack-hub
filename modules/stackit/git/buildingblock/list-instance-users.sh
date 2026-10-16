#!/usr/bin/env bash
# Prints the instance's users as `{"<lowercase email>": "<username>"}` for an `external` data source,
# or `{}` while no instance of that name exists.
set -euo pipefail

query="$(cat)"
access_token="$(jq -r '.access_token' <<<"${query}")"
instances_url="https://git.api.stackit.cloud/v1beta/projects/$(jq -r '.project_id' <<<"${query}")/instances"

get() {
  curl --silent --show-error --fail-with-body --retry 5 --retry-all-errors \
    --header "Authorization: Bearer ${access_token}" "$1"
}

instance_id="$(get "${instances_url}" | jq -r --arg name "$(jq -r '.instance_name' <<<"${query}")" \
  '[.instances[] | select(.name == $name) | .id][0] // empty')"
if [[ -z "${instance_id}" ]]; then
  printf '{}'
  exit 0
fi

users='{}'
page=1
total_pages=1
while ((page <= total_pages)); do
  body="$(get "${instances_url}/${instance_id}/users?page=${page}")"
  users="$(jq -c --argjson acc "${users}" '$acc + ([.users[] | {key: (.email | ascii_downcase), value: .username}] | from_entries)' <<<"${body}")"
  total_pages="$(jq -r '.totalPages // 1' <<<"${body}")"
  page=$((page + 1))
done

printf '%s' "${users}"
