#!/usr/bin/env bash

set -e

echo "=== SAP BTP Subscriptions Import Script ==="
echo ""
echo "This script will import existing application subscriptions for a subaccount."
echo ""

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in current directory"
    exit 1
fi

echo "Reading configuration from terraform.tfvars..."

SUBACCOUNT_ID=$(tofu console <<< 'var.subaccount_id' 2>/dev/null | tr -d '"')
SUBSCRIPTIONS=$(tofu console <<< 'var.subscriptions' 2>/dev/null | tr -d '"')

echo "  Subaccount ID: $SUBACCOUNT_ID"
echo "  Subscriptions: $SUBSCRIPTIONS"
echo ""

if [ -z "$SUBACCOUNT_ID" ]; then
    echo "Error: subaccount_id is required"
    exit 1
fi

FAILED_IMPORTS=()
SUCCESSFUL_IMPORTS=()

import_resource() {
    local resource_address="$1"
    local resource_id="$2"
    local description="$3"

    echo "Importing: $description"
    echo "  Resource: $resource_address"
    echo "  ID: $resource_id"

    if tofu state show "$resource_address" >/dev/null 2>&1; then
        echo "  ⊙ ALREADY IMPORTED (skipping)"
        SUCCESSFUL_IMPORTS+=("$description (already imported)")
        echo ""
        return 0
    fi

    if tofu import "$resource_address" "$resource_id" >/dev/null 2>&1; then
        SUCCESSFUL_IMPORTS+=("$description")
        echo "  ✓ SUCCESS"
    else
        FAILED_IMPORTS+=("$description")
        echo "  ✗ FAILED"
    fi
    echo ""
}

echo "Starting imports..."
echo ""

if [ -n "$SUBSCRIPTIONS" ] && [ "$SUBSCRIPTIONS" != '""' ] && [ "$SUBSCRIPTIONS" != "" ]; then
    echo "Importing subscriptions..."

    IFS=',' read -ra SUBSCRIPTION_ARRAY <<< "$SUBSCRIPTIONS"

    for subscription_entry in "${SUBSCRIPTION_ARRAY[@]}"; do
        subscription_entry=$(echo "$subscription_entry" | xargs)
        if [ -n "$subscription_entry" ]; then
            app_name=$(echo "$subscription_entry" | cut -d'.' -f1)
            plan_name=$(echo "$subscription_entry" | cut -d'.' -f2)
            resource_key="${app_name}-${plan_name}"

            import_resource \
                "btp_subaccount_subscription.subscription[\"$resource_key\"]" \
                "$SUBACCOUNT_ID,$app_name,$plan_name" \
                "Subscription: $app_name.$plan_name"
        fi
    done
fi

echo ""
echo "=== Import Summary ==="
echo ""
echo "Successful imports (${#SUCCESSFUL_IMPORTS[@]}):"
for item in "${SUCCESSFUL_IMPORTS[@]}"; do
    echo "  ✓ $item"
done
echo ""

if [ ${#FAILED_IMPORTS[@]} -gt 0 ]; then
    echo "Failed imports (${#FAILED_IMPORTS[@]}):"
    for item in "${FAILED_IMPORTS[@]}"; do
        echo "  ✗ $item"
    done
    echo ""
fi

echo "Next steps:"
echo "  1. Run 'tofu plan' to verify the state"
echo "  2. Run 'tofu apply' if any changes are needed"
echo ""

if [ ${#FAILED_IMPORTS[@]} -gt 0 ]; then
    exit 1
fi
