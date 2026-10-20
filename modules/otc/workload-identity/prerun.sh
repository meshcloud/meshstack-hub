#!/usr/bin/env bash
# The opentelekomcloud provider cannot sign in with an OIDC token, so this exchanges the run's
# workload identity token for temporary credentials. The building block's provider reads them
# from the file written here.
set -euo pipefail

token_path=/var/run/secrets/workload-identity/gcp/token
credentials_file=otc_credentials.json

run_json=$(cat)
input() { echo "$run_json" | jq -r --arg k "$1" '.spec.buildingBlock.spec.inputs[] | select(.key == $k) | .value'; }

fail() {
  echo "Signing in through workload identity federation failed: $1" | tee -a "$MESHSTACK_USER_MESSAGE" >&2
  exit 1
}

[ -f "$token_path" ] || fail "meshStack mounted no run token at $token_path."
command -v curl >/dev/null || nix profile add nixpkgs#curl

iam=${OS_AUTH_URL:-$(input OS_AUTH_URL)}
iam=${iam%/v3}
idp=${OTC_IDENTITY_PROVIDER:-$(input OTC_IDENTITY_PROVIDER)}
domain=${OS_DOMAIN_NAME:-$(input OS_DOMAIN_NAME)}
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# 1. The run token for a federated IAM token, scoped to the domain.
jq -n --arg t "$(tr -d '\n' <"$token_path")" --arg d "$domain" \
  '{auth: {id_token: {id: $t}, scope: {domain: {name: $d}}}}' >"$work/token_request.json"
status=$(curl -sS -o "$work/token_response.json" -D "$work/token_headers" -w '%{http_code}' \
  -X POST "$iam/v3.0/OS-AUTH/id-token/tokens" \
  -H 'Content-Type: application/json' -H "X-Idp-Id: $idp" -d @"$work/token_request.json")
[ "$status" = 201 ] || fail "IAM answered the token exchange at identity provider $idp with HTTP $status: $(cat "$work/token_response.json")"
iam_token=$(grep -i '^x-subject-token:' "$work/token_headers" | cut -d' ' -f2 | tr -d '\r')

# 2. The IAM token for a temporary access key, which OBS accepts as well as every other service.
jq -n --arg t "$iam_token" '{auth: {identity: {methods: ["token"], token: {id: $t, duration_seconds: 3600}}}}' \
  >"$work/credential_request.json"
status=$(curl -sS -o "$work/credential_response.json" -w '%{http_code}' \
  -X POST "$iam/v3.0/OS-CREDENTIAL/securitytokens" \
  -H 'Content-Type: application/json' -H "X-Auth-Token: $iam_token" -d @"$work/credential_request.json")
[ "$status" = 201 ] || fail "IAM answered the temporary access key request with HTTP $status: $(cat "$work/credential_response.json")"

umask 077
jq '.credential' "$work/credential_response.json" >"$credentials_file"
echo "Signed in through workload identity federation at identity provider $idp."
