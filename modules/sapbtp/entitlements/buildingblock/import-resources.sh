#!/usr/bin/env bash

set -e

echo "=== SAP BTP Entitlements Import Script ==="
echo ""
echo "This script will import existing entitlements for a subaccount."
echo ""

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in current directory"
    exit 1
fi

QUOTA_BASED_SERVICES=("postgresql-db" "redis-cache" "hana-cloud" "auditlog-viewer" "APPLICATION_RUNTIME" "cloudfoundry" "sapappstudio" "sap-build-apps")

is_quota_based() {
    local service="$1"
    for quota_service in "${QUOTA_BASED_SERVICES[@]}"; do
        if [ "$service" = "$quota_service" ]; then
            return 0
        fi
    done
    return 1
}

echo "Reading configuration from terraform.tfvars..."

SUBACCOUNT_ID=$(tofu console <<< 'var.subaccount_id' 2>/dev/null | tr -d '"')
ENTITLEMENTS=$(tofu console <<< 'var.entitlements' 2>/dev/null | tr -d '"')

echo "  Subaccount ID: $SUBACCOUNT_ID"
echo "  Entitlements: $ENTITLEMENTS"
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

if [ -n "$ENTITLEMENTS" ] && [ "$ENTITLEMENTS" != '""' ] && [ "$ENTITLEMENTS" != "" ]; then
    echo "Importing entitlements..."

    IFS=',' read -ra ENTITLEMENT_ARRAY <<< "$ENTITLEMENTS"

    for entitlement_entry in "${ENTITLEMENT_ARRAY[@]}"; do
        entitlement_entry=$(echo "$entitlement_entry" | xargs)
        if [ -n "$entitlement_entry" ]; then
            service_name=$(echo "$entitlement_entry" | cut -d'.' -f1)
            plan_name=$(echo "$entitlement_entry" | cut -d'.' -f2)
            resource_key="${service_name}-${plan_name}"

            if is_quota_based "$service_name"; then
                resource_type="entitlement_with_quota"
                description="Entitlement (with quota): $service_name.$plan_name"
            else
                resource_type="entitlement_without_quota"
                description="Entitlement (without quota): $service_name.$plan_name"
            fi

            import_resource \
                "btp_subaccount_entitlement.${resource_type}[\"$resource_key\"]" \
                "$SUBACCOUNT_ID,$service_name,$plan_name" \
                "$description"
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
