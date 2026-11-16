#!/usr/bin/env bash
# Deletes one building block through the meshStack API. The meshstack provider can list building
# blocks but cannot delete one it does not manage, hence the plain API calls.
set -euo pipefail

: "${MESHSTACK_ENDPOINT:?}" "${MESHSTACK_API_KEY:?}" "${MESHSTACK_API_SECRET:?}" "${BUILDING_BLOCK_UUID:?}"

endpoint="${MESHSTACK_ENDPOINT%/}"

# The credentials go through stdin, so they never show up in the process list.
token=$(
  jq -n --arg id "$MESHSTACK_API_KEY" --arg secret "$MESHSTACK_API_SECRET" '{clientId: $id, clientSecret: $secret}' |
    curl --silent --show-error --fail-with-body \
      --header 'Content-Type: application/json' \
      --data @- \
      "$endpoint/api/login" |
    jq -er '.access_token'
)

response=$(mktemp)
trap 'rm -f "$response"' EXIT

status=$(
  echo "Authorization: Bearer $token" |
    curl --silent --show-error \
      --request DELETE \
      --header @- \
      --output "$response" \
      --write-out '%{http_code}' \
      "$endpoint/api/meshobjects/meshbuildingblocks/$BUILDING_BLOCK_UUID"
)

case "$status" in
  202) echo "Requested deletion of building block $BUILDING_BLOCK_UUID." ;;
  404) echo "Building block $BUILDING_BLOCK_UUID is already gone." ;;
  *)
    echo "Deleting building block $BUILDING_BLOCK_UUID failed with HTTP $status:" >&2
    cat "$response" >&2
    exit 1
    ;;
esac
