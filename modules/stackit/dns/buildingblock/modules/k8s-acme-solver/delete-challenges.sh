#!/usr/bin/env bash
# Deletes the open cert-manager Challenges that GROUP_NAME solves and waits until cert-manager has
# cleaned them up, for at most TIMEOUT_SECONDS. Never fails.
set -uo pipefail

deadline=$((SECONDS + ${TIMEOUT_SECONDS:-300}))

open_challenges() {
  kubectl get challenges.acme.cert-manager.io --all-namespaces --output json |
    jq --raw-output --arg group "$GROUP_NAME" \
      '.items[] | select(.spec.solver.dns01.webhook.groupName == $group) | "\(.metadata.namespace) \(.metadata.name)"'
}

if ! challenges=$(open_challenges); then
  echo "No Challenges to delete: cert-manager or the cluster is not there."
  exit 0
fi
if [[ -z "$challenges" ]]; then
  echo "No open Challenges for $GROUP_NAME."
  exit 0
fi

# A pending Order recreates a deleted Challenge right away, so delete the Certificates that ordered them.
certificates=$(
  jq --null-input --raw-output --arg group "$GROUP_NAME" \
    --argjson challenges "$(kubectl get challenges.acme.cert-manager.io --all-namespaces --output json)" \
    --argjson orders "$(kubectl get orders.acme.cert-manager.io --all-namespaces --output json)" \
    --argjson requests "$(kubectl get certificaterequests.cert-manager.io --all-namespaces --output json)" '
    def index_by_name: map({key: "\(.metadata.namespace)/\(.metadata.name)", value: .}) | from_entries;
    def owner($kind): .metadata.ownerReferences[]? | select(.kind == $kind) | .name;
    ($orders.items | index_by_name) as $orders
    | ($requests.items | index_by_name) as $requests
    | $challenges.items[]
    | select(.spec.solver.dns01.webhook.groupName == $group)
    | .metadata.namespace as $ns
    | $orders["\($ns)/\(owner("Order"))"] // empty
    | $requests["\($ns)/\(owner("CertificateRequest"))"] // empty
    | "\($ns) \(owner("Certificate"))"' | sort -u
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
