#!/usr/bin/env bash
# shellcheck disable=SC2016 # $names in single quotes are jq variables.
# Deletes the open cert-manager Challenges this solver serves (webhook GROUP_NAME/SOLVER_NAME, a name
# in ZONE_NAME) and waits until cert-manager has cleaned them up, for at most TIMEOUT_SECONDS.
# Never fails.
set -uo pipefail

deadline=$((SECONDS + ${TIMEOUT_SECONDS:-300}))

get() {
  kubectl get "$1" --all-namespaces --output json
}

# For a wildcard, cert-manager sets dnsName to the name without "*.".
served='
  def served:
    .spec.solver.dns01.webhook.groupName == $group
    and .spec.solver.dns01.webhook.solverName == $solver
    and ((.spec.dnsName | rtrimstr(".")) as $name | $name == $zone or ($name | endswith("." + $zone)));'

jq_served() {
  jq "$@" --arg group "$GROUP_NAME" --arg solver "$SOLVER_NAME" --arg zone "${ZONE_NAME%.}"
}

open_challenges() {
  get challenges.acme.cert-manager.io |
    jq_served --raw-output "$served"'.items[] | select(served) | "\(.metadata.namespace) \(.metadata.name)"'
}

if ! challenges=$(open_challenges); then
  echo "No Challenges to delete: cert-manager or the cluster is not there."
  exit 0
fi
if [[ -z "$challenges" ]]; then
  echo "No open Challenges for $SOLVER_NAME in $ZONE_NAME."
  exit 0
fi

# A pending Order recreates a deleted Challenge right away, so delete the Certificates that ordered
# them. A Ready one keeps serving and is left alone.
certificates=$(
  jq_served --null-input --raw-output \
    --argjson challenges "$(get challenges.acme.cert-manager.io)" \
    --argjson orders "$(get orders.acme.cert-manager.io)" \
    --argjson requests "$(get certificaterequests.cert-manager.io)" \
    --argjson certificates "$(get certificates.cert-manager.io)" "$served"'
    def index_by_name: map({key: "\(.metadata.namespace)/\(.metadata.name)", value: .}) | from_entries;
    def owner($kind): .metadata.ownerReferences[]? | select(.kind == $kind) | .name;
    ($orders.items | index_by_name) as $orders
    | ($requests.items | index_by_name) as $requests
    | ($certificates.items | index_by_name) as $certificates
    | $challenges.items[]
    | select(served)
    | .metadata.namespace as $ns
    | $orders["\($ns)/\(owner("Order"))"] // empty
    | $requests["\($ns)/\(owner("CertificateRequest"))"] // empty
    | $certificates["\($ns)/\(owner("Certificate"))"] // empty
    | select(any(.status.conditions[]?; .type == "Ready" and .status == "True") | not)
    | "\($ns) \(.metadata.name)"' | sort -u
)

while read -r namespace name; do
  [[ -n "$name" ]] && kubectl delete certificates.cert-manager.io --namespace "$namespace" "$name" --wait=false
done <<<"$certificates"

while [[ -n "$challenges" ]] && ((SECONDS < deadline)); do
  while read -r namespace name; do
    kubectl delete challenges.acme.cert-manager.io --namespace "$namespace" "$name" --wait=false --ignore-not-found
  done <<<"$challenges"
  sleep 5
  challenges=$(open_challenges) || break
done

if [[ -n "$challenges" ]]; then
  echo "These Challenges are still open, so their namespace may not finish deleting:" >&2
  echo "$challenges" >&2
fi
exit 0
