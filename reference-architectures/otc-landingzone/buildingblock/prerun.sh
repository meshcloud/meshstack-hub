#!/usr/bin/env bash
# EXPERIMENT: exchanges the run's workload identity token for temporary credentials, which
# provider.tf prefers over the admin access key. See workload_identity.tf. Any failure falls back
# to the admin access key, so the run itself never depends on the experiment.
set -uo pipefail

token_path=/var/run/secrets/workload-identity/gcp/token
credentials_file=otc_wif_credentials.json

run_json=$(cat)
input() { echo "$run_json" | jq -r --arg k "$1" '.spec.buildingBlock.spec.inputs[] | select(.key == $k) | .value'; }

fall_back() {
  echo "Workload identity: $1 This run uses the admin access key." | tee -a "$MESHSTACK_USER_MESSAGE"
  rm -f "$credentials_file"
  exit 0
}

[ -f "$token_path" ] || fall_back "no run token at $token_path."
command -v curl >/dev/null || nix profile add nixpkgs#curl

# The identity provider is created by a run that still used the admin access key.
idp=$(tofu output -raw workload_identity_provider 2>/dev/null) || idp=""
[ -n "$idp" ] || fall_back "no identity provider in the previous run's state yet."

iam="https://iam.$(input otc_region).otc.t-systems.com"
work=$(mktemp -d)

# 1. The run token for a federated IAM token, scoped to the domain.
jq -n --arg t "$(tr -d '\n' <"$token_path")" --arg d "$(input otc_domain_name)" \
  '{auth: {id_token: {id: $t}, scope: {domain: {name: $d}}}}' >"$work/token_request.json"
status=$(curl -sS -o "$work/token_response.json" -D "$work/token_headers" -w '%{http_code}' \
  -X POST "$iam/v3.0/OS-AUTH/id-token/tokens" \
  -H 'Content-Type: application/json' -H "X-Idp-Id: $idp" -d @"$work/token_request.json")
[ "$status" = 201 ] || fall_back "IAM answered the token exchange with HTTP $status: $(cat "$work/token_response.json")"
iam_token=$(grep -i '^x-subject-token:' "$work/token_headers" | cut -d' ' -f2 | tr -d '\r')

# 2. The IAM token for a temporary access key, which every service including OBS accepts.
jq -n --arg t "$iam_token" '{auth: {identity: {methods: ["token"], token: {id: $t, duration_seconds: 3600}}}}' \
  >"$work/credential_request.json"
status=$(curl -sS -o "$work/credential_response.json" -w '%{http_code}' \
  -X POST "$iam/v3.0/OS-CREDENTIAL/securitytokens" \
  -H 'Content-Type: application/json' -H "X-Auth-Token: $iam_token" -d @"$work/credential_request.json")
[ "$status" = 201 ] || fall_back "IAM answered the temporary access key request with HTTP $status: $(cat "$work/credential_response.json")"

umask 077
jq '.credential' "$work/credential_response.json" >"$credentials_file"
rm -rf "$work"
echo "Workload identity: signed in through identity provider $idp, no admin access key used." | tee -a "$MESHSTACK_USER_MESSAGE"
