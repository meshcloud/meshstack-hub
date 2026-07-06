#!/usr/bin/env bash

# Best-effort STACKIT organization membership onboarding.
# Runs after OpenTofu init and before apply/destroy. This script must never block
# the building block run: all errors are logged as warnings and the script exits 0.

RUN_INPUT_FILE=""

info() {
  echo "[stackit-org-membership] $*"
}

warn() {
  echo "[stackit-org-membership] WARN: $*" >&2
  if [[ -n "${MESHSTACK_USER_MESSAGE:-}" ]]; then
    echo "STACKIT organization membership warning: $*" >> "$MESHSTACK_USER_MESSAGE" 2>/dev/null || true
  fi
}

cleanup() {
  if [[ -n "$RUN_INPUT_FILE" && -f "$RUN_INPUT_FILE" ]]; then
    rm -f "$RUN_INPUT_FILE"
  fi
}

is_destroy_run() {
  local mode
  mode=$(printf '%s' "${1:-APPLY}" | tr '[:lower:]' '[:upper:]')
  [[ "$mode" == "DESTROY" ]]
}

capture_run_input() {
  RUN_INPUT_FILE=$(mktemp)
  cat > "$RUN_INPUT_FILE" 2>/dev/null || true
}

extract_users_json() {
  if [[ ! -s "$RUN_INPUT_FILE" ]]; then
    printf '[]\n'
    return 0
  fi

  jq -c '[.spec.buildingBlock.spec.inputs[]? | select(.key == "users") | .value | fromjson][0] // []' "$RUN_INPUT_FILE" 2>/dev/null \
    || printf '[]\n'
}

extract_emails_json() {
  local users_json="$1"

  printf '%s' "$users_json" \
    | jq -c '[.[]? | .email? // empty | strings | ascii_downcase | select(length > 0)] | unique' 2>/dev/null \
    || printf '[]'
}

get_access_token() {
  local service_account_email="$1"

  if [[ -n "${STACKIT_ACCESS_TOKEN:-}" ]]; then
    printf '%s' "$STACKIT_ACCESS_TOKEN"
    return 0
  fi

  if [[ -z "$service_account_email" ]]; then
    warn "STACKIT_SERVICE_ACCOUNT_EMAIL is not set; cannot exchange WIF token"
    return 1
  fi

  local token_file="${STACKIT_FEDERATED_TOKEN_FILE:-/var/run/secrets/stackit.cloud/serviceaccount/token}"
  if [[ ! -r "$token_file" ]]; then
    warn "STACKIT federated token file '$token_file' is not readable"
    return 1
  fi

  local assertion
  assertion=$(cat "$token_file" 2>/dev/null || true)
  if [[ -z "$assertion" ]]; then
    warn "STACKIT federated token file '$token_file' is empty"
    return 1
  fi

  local token_endpoint="${STACKIT_IDP_TOKEN_ENDPOINT:-https://accounts.stackit.cloud/oauth/v2/token}"
  local response_file error_file http_code rc access_token
  response_file=$(mktemp)
  error_file=$(mktemp)

  http_code=$(curl -sS -o "$response_file" -w '%{http_code}' \
    -X POST "$token_endpoint" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=client_credentials' \
    --data-urlencode 'client_assertion_type=urn:schwarz:params:oauth:client-assertion-type:workload-jwt' \
    --data-urlencode "client_assertion=$assertion" \
    --data-urlencode "client_id=$service_account_email" \
    2>"$error_file")
  rc=$?

  if [[ "$rc" -ne 0 ]]; then
    warn "token exchange request failed: $(cat "$error_file" 2>/dev/null)"
    return 1
  fi

  case "$http_code" in
    2*) ;;
    *)
      warn "token exchange returned HTTP $http_code: $(cat "$response_file" 2>/dev/null | cut -c1-500)"
      return 1
      ;;
  esac

  access_token=$(jq -r '.access_token // empty' "$response_file" 2>/dev/null || true)
  if [[ -z "$access_token" ]]; then
    warn "token exchange response did not contain an access_token"
    return 1
  fi

  printf '%s' "$access_token"
}

build_membership_payload() {
  local organization_role="$1"
  local emails_json="$2"

  jq -n \
    --arg role "$organization_role" \
    --argjson emails "$emails_json" \
    '{resourceType: "organization", members: [$emails[] | {subject: ., role: $role}]}'
}

call_membership_api_with_curl() {
  local url="$1"
  local payload="$2"
  local access_token="$3"
  local response_file error_file http_code rc

  response_file=$(mktemp)
  error_file=$(mktemp)
  http_code=$(curl -sS -o "$response_file" -w '%{http_code}' \
    -X PATCH "$url" \
    -H "Authorization: Bearer $access_token" \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    2>"$error_file")
  rc=$?

  if [[ "$rc" -ne 0 ]]; then
    warn "Membership API request failed: $(cat "$error_file" 2>/dev/null)"
    return 0
  fi

  case "$http_code" in
    2*)
      info "organization membership onboarding request completed"
      ;;
    *)
      warn "Membership API returned HTTP $http_code: $(cat "$response_file" 2>/dev/null | cut -c1-500)"
      ;;
  esac

  return 0
}

onboard_organization_members() {
  local emails_json="$1"
  local email_count="$2"
  local organization_id="${STACKIT_ORGANIZATION_ID:-}"
  local organization_role="${STACKIT_ORGANIZATION_MEMBER_ROLE:-organization.viewer}"
  local service_account_email="${STACKIT_SERVICE_ACCOUNT_EMAIL:-}"
  local encoded_organization_id url payload access_token

  if [[ -z "$organization_id" ]]; then
    warn "STACKIT_ORGANIZATION_ID is not set; cannot add organization memberships"
    return 0
  fi

  if [[ -z "$organization_role" ]]; then
    warn "STACKIT_ORGANIZATION_MEMBER_ROLE is empty; cannot add organization memberships"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    warn "curl is not available; cannot call STACKIT Membership API"
    return 0
  fi

  payload=$(build_membership_payload "$organization_role" "$emails_json")
  encoded_organization_id=$(printf '%s' "$organization_id" | jq -sRr @uri)
  url="https://authorization.api.stackit.cloud/v2/${encoded_organization_id}/members"

  info "ensuring $email_count user(s) have organization role '$organization_role' on '$organization_id'"

  access_token=$(get_access_token "$service_account_email" || true)
  if [[ -z "$access_token" ]]; then
    warn "could not obtain STACKIT access token; skipping organization membership onboarding"
    return 0
  fi

  call_membership_api_with_curl "$url" "$payload" "$access_token"
}

main() {
  local users_json emails_json email_count

  trap cleanup EXIT

  if is_destroy_run "${1:-APPLY}"; then
    info "destroy run detected; skipping organization membership onboarding"
    return 0
  fi

  capture_run_input

  users_json=$(extract_users_json)
  emails_json=$(extract_emails_json "$users_json")
  email_count=$(printf '%s' "$emails_json" | jq -r 'length' 2>/dev/null || printf '0')

  if [[ "$email_count" == "0" ]]; then
    info "no users found; skipping organization membership onboarding"
    return 0
  fi

  onboard_organization_members "$emails_json" "$email_count"
  return 0
}

main "$@" || true
