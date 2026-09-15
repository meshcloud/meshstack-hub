#!/usr/bin/env bash
# meshStack pre-run script for the AWS DynamoDB Account Metadata building block.
#
# Runs after 'tofu init', before 'tofu apply'/'tofu destroy'. meshStack passes the
# run mode (APPLY | DESTROY) as the first positional argument.
#
# A DESTROY run means the tenant/account is being deleted. The item must NOT be deleted —
# instead it is kept and marked as retired. We reuse the module's own aws provider (no aws cli):
#   1. re-apply the item with account_status = "retired" (in-place update)
#   2. remove the item from tofu state, so the subsequent 'tofu destroy' has nothing
#      to delete and no DeleteItem is ever issued.
# -no-color keeps the run log clean; no -target is used (the module has a single managed
# resource, so a full apply is equivalent and avoids the noisy "-target in effect" warnings).
set -euo pipefail

RUN_MODE="${1:-}"
echo "=== Pre-run: mode=${RUN_MODE} ==="

if [ "$RUN_MODE" != "DESTROY" ]; then
  echo "Nothing to do on ${RUN_MODE}."
  exit 0
fi

# Nothing to retire if the item was never created.
if ! tofu state list | grep -qx 'aws_dynamodb_table_item.this'; then
  echo "No item in state — nothing to retire, letting destroy proceed."
  exit 0
fi

echo "Retiring account: re-applying item with account_status=retired..."
tofu apply -auto-approve -no-color -var 'account_status=retired'

# Drop the item from state so 'tofu destroy' does not delete it.
tofu state rm -no-color aws_dynamodb_table_item.this

echo "Account retired and removed from state. 'tofu destroy' will not delete it."
