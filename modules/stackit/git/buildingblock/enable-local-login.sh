#!/usr/bin/env bash
# Forgejo mints a Personal Access Token only over HTTP Basic auth, so the technical user needs local
# login. `stackit_git` has no `feature_toggle` attribute, hence a script.
set -euo pipefail

api_host="${STACKIT_GIT_API_HOST:-https://git.api.stackit.cloud}"

deadline_seconds="${LOCAL_LOGIN_TIMEOUT_SECONDS:-600}"
interval_seconds="${LOCAL_LOGIN_INTERVAL_SECONDS:-10}"

for required in ACCESS_TOKEN PROJECT_ID INSTANCE_ID; do
  if [[ -z "${!required:-}" ]]; then
    echo "${required} is not set" >&2
    exit 1
  fi
done

instance_url="${api_host}/v1beta/projects/${PROJECT_ID}/instances/${INSTANCE_ID}"

started_at="${SECONDS}"

read_instance() {
  curl --silent --show-error --fail-with-body \
    --header "Authorization: Bearer ${ACCESS_TOKEN}" \
    "${instance_url}"
}

# A PATCH puts the instance back into `Creating`, not `Updating`, for about a minute.
await_instance() {
  local want_local_login=${1:-}

  while true; do
    instance="$(read_instance)"
    state="$(printf '%s' "${instance}" | jq -r '.state')"
    enabled="$(printf '%s' "${instance}" | jq -r '.feature_toggle.enable_local_login')"

    if [[ "${state}" == "Ready" ]] &&
      [[ -z "${want_local_login}" || "${enabled}" == "${want_local_login}" ]]; then
      return 0
    fi

    if ((SECONDS - started_at >= deadline_seconds)); then
      echo "instance ${INSTANCE_ID} is ${state} with local login ${enabled} after ${deadline_seconds}s." >&2
      echo "Re-running this building block is safe and usually succeeds." >&2
      return 1
    fi

    sleep "${interval_seconds}"
  done
}

# A PATCH against an instance that is still coming up is rejected.
await_instance

if [[ "$(printf '%s' "${instance}" | jq -r '.feature_toggle.enable_local_login')" == "true" ]]; then
  echo "local login is already enabled on instance ${INSTANCE_ID}" >&2
  exit 0
fi

# The PATCH replaces `feature_toggle` as a whole, so all current toggles are resent.
patch_body="$(printf '%s' "${instance}" |
  jq -c '{feature_toggle: (.feature_toggle + {enable_local_login: true})}')"

curl --silent --show-error --fail-with-body --output /dev/null \
  --request PATCH "${instance_url}" \
  --header "Authorization: Bearer ${ACCESS_TOKEN}" \
  --header 'Content-Type: application/json' \
  --data "${patch_body}"

# Basic-auth login fails until the instance reports the flag back.
await_instance true

echo "local login enabled on instance ${INSTANCE_ID} after $((SECONDS - started_at))s" >&2
