#!/usr/bin/env bash
# Prints the instance's users as `{"<lowercase email>": "<username>"}` for an `external` data source.
set -euo pipefail

query="$(cat)"
access_token="$(jq -r '.access_token' <<<"${query}")"
users_url="https://git.api.stackit.cloud/v1beta/projects/$(jq -r '.project_id' <<<"${query}")/instances/$(jq -r '.instance_id' <<<"${query}")/users"

users='{}'
page=1
total_pages=1
while ((page <= total_pages)); do
  body="$(curl --silent --show-error --fail-with-body --retry 5 --retry-all-errors \
    --header "Authorization: Bearer ${access_token}" "${users_url}?page=${page}")"
  users="$(jq -c --argjson acc "${users}" '$acc + ([.users[] | {key: (.email | ascii_downcase), value: .username}] | from_entries)' <<<"${body}")"
  total_pages="$(jq -r '.totalPages // 1' <<<"${body}")"
  page=$((page + 1))
done

printf '%s' "${users}"
