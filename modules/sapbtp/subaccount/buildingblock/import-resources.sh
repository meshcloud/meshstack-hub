#!/usr/bin/env bash

set -e

echo "=== SAP BTP Subaccount Import Script ==="
echo ""
echo "This script imports an existing SAP BTP subaccount and user role assignments."
echo ""

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in current directory"
    exit 1
fi

echo "Reading configuration from terraform.tfvars..."

PROJECT_ID=$(tofu console <<< 'var.project_identifier' 2>/dev/null | tr -d '"')
USERS=$(tofu console <<< 'var.users' 2>/dev/null)

echo "  Project Identifier: $PROJECT_ID"
echo ""

echo "Discovering resource IDs..."

SUBACCOUNT_ID=$(tofu show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type == "btp_subaccount" and .name == "subaccount") | .values.id' 2>/dev/null || echo "")

if [ -z "$SUBACCOUNT_ID" ]; then
    echo ""
    echo "Subaccount ID not found in state."
    read -p "Enter Subaccount ID: " SUBACCOUNT_ID
fi

echo "  Subaccount ID: $SUBACCOUNT_ID"
echo ""

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
    "btp_subaccount.subaccount" \
    "$SUBACCOUNT_ID" \
    "BTP Subaccount"

echo "=== Resources that cannot be imported ==="
echo ""
echo "The following resources cannot be imported per SAP BTP provider design:"
echo "  • Role collection assignments (will be managed on next apply)"
echo ""

if [ -n "$USERS" ] && [ "$USERS" != "[]" ]; then
    echo "Role assignments to be created:"
    echo "$USERS" | jq -r '.[] | "  • \(.euid) - role: \(.roles | join(", "))"' 2>/dev/null || echo "  (Cannot parse users)"
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
echo "  2. Run 'tofu apply' to create role collection assignments"
echo ""

if [ ${#FAILED_IMPORTS[@]} -gt 0 ]; then
    exit 1
fi
