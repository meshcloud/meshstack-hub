#!/usr/bin/env bash

set -e

echo "=== SAP BTP Trust Configuration Import Script ==="
echo ""
echo "This script will import an existing custom identity provider trust configuration."
echo ""

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in current directory"
    exit 1
fi

echo "Reading configuration from terraform.tfvars..."

SUBACCOUNT_ID=$(tofu console <<< 'var.subaccount_id' 2>/dev/null | tr -d '"')
IDENTITY_PROVIDER=$(tofu console <<< 'var.identity_provider' 2>/dev/null | tr -d '"')

echo "  Subaccount ID: $SUBACCOUNT_ID"
echo "  Identity Provider: $IDENTITY_PROVIDER"
echo ""

if [ -z "$SUBACCOUNT_ID" ]; then
    echo "Error: subaccount_id is required"
    exit 1
fi

if [ -z "$IDENTITY_PROVIDER" ] || [ "$IDENTITY_PROVIDER" = '""' ]; then
    echo "No custom identity provider configured. Nothing to import."
    exit 0
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

import_resource \
    "btp_subaccount_trust_configuration.custom_idp[0]" \
    "$SUBACCOUNT_ID,$IDENTITY_PROVIDER" \
    "Trust Configuration: $IDENTITY_PROVIDER"

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
