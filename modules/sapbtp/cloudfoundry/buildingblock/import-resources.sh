#!/usr/bin/env bash

set -e

echo "=== SAP BTP Cloud Foundry Import Script ==="
echo ""
echo "This script will import the Cloud Foundry environment and service instances."
echo ""

if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in current directory"
    exit 1
fi

echo "Reading configuration from terraform.tfvars..."

SUBACCOUNT_ID=$(tofu console <<< 'var.subaccount_id' 2>/dev/null | tr -d '"')
PROJECT_ID=$(tofu console <<< 'var.project_identifier' 2>/dev/null | tr -d '"')
CF_SERVICES=$(tofu console <<< 'var.cf_services' 2>/dev/null | tr -d '"')

echo "  Subaccount ID: $SUBACCOUNT_ID"
echo "  Project Identifier: $PROJECT_ID"
echo "  CF Services: $CF_SERVICES"
echo ""

if [ -z "$SUBACCOUNT_ID" ]; then
    echo "Error: subaccount_id is required"
    exit 1
fi

CF_ENV_ID=$(tofu show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type == "btp_subaccount_environment_instance" and .name == "cloudfoundry") | .values.id' 2>/dev/null || echo "")

if [ -z "$CF_ENV_ID" ]; then
    echo ""
    echo "Cloud Foundry Environment ID not found in state."
    echo "You can find it with: btp list accounts/environment-instance --subaccount $SUBACCOUNT_ID"
    read -p "Enter CF Environment ID: " CF_ENV_ID
fi

echo "  CF Environment ID: $CF_ENV_ID"
echo ""

CF_SERVICE_IDS_JSON=$(tofu show -json 2>/dev/null | jq -c 'reduce (.values.root_module.resources[] | select(.type == "btp_subaccount_service_instance" and .name == "cf_service")) as $item ({}; .[$item.index] = $item.values.id)' 2>/dev/null || echo "{}")

CF_SERVICES_IN_STATE=$(echo "$CF_SERVICE_IDS_JSON" | jq -r 'keys | length' 2>/dev/null || echo "0")

if [ "$CF_SERVICES_IN_STATE" = "0" ] && [ -n "$CF_SERVICES" ] && [ "$CF_SERVICES" != '""' ]; then
    echo ""
    echo "No CF service instances found in state."
    echo "You can find them with: btp list services/instance --subaccount $SUBACCOUNT_ID"
    echo ""
    echo "Please enter service instance IDs for each service:"

    IFS=',' read -ra SERVICE_ARRAY <<< "$CF_SERVICES"
    CF_SERVICE_IDS_MANUAL="{}"

    for service_entry in "${SERVICE_ARRAY[@]}"; do
        service_entry=$(echo "$service_entry" | xargs)
        if [ -n "$service_entry" ]; then
            service_name=$(echo "$service_entry" | cut -d'.' -f1)
            plan_name=$(echo "$service_entry" | cut -d'.' -f2)
            instance_name="${service_name}-${plan_name}"
            resource_key="${instance_name}-${plan_name}"

            read -p "  Enter ID for $service_name.$plan_name (name: $instance_name): " service_id
            CF_SERVICE_IDS_MANUAL=$(echo "$CF_SERVICE_IDS_MANUAL" | jq --arg key "$resource_key" --arg val "$service_id" '.[$key] = $val')
        fi
    done

    CF_SERVICE_IDS_JSON="$CF_SERVICE_IDS_MANUAL"
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
    "btp_subaccount_environment_instance.cloudfoundry" \
    "$SUBACCOUNT_ID,$CF_ENV_ID" \
    "Cloud Foundry Environment Instance"

if [ -n "$CF_SERVICES" ] && [ "$CF_SERVICES" != '""' ] && [ "$CF_SERVICES" != "" ]; then
    echo "Importing CF service instances..."

    IFS=',' read -ra SERVICE_ARRAY <<< "$CF_SERVICES"

    for service_entry in "${SERVICE_ARRAY[@]}"; do
        service_entry=$(echo "$service_entry" | xargs)
        if [ -n "$service_entry" ]; then
            service_name=$(echo "$service_entry" | cut -d'.' -f1)
            plan_name=$(echo "$service_entry" | cut -d'.' -f2)
            instance_name="${service_name}-${plan_name}"
            resource_key="${instance_name}-${plan_name}"

            instance_id=$(echo "$CF_SERVICE_IDS_JSON" | jq -r --arg key "$resource_key" '.[$key] // empty')

            if [ -n "$instance_id" ]; then
                import_resource \
                    "btp_subaccount_service_instance.cf_service[\"$resource_key\"]" \
                    "$SUBACCOUNT_ID,$instance_id" \
                    "CF Service: $service_name.$plan_name"
            else
                echo "  ⚠ CF Service instance $resource_key not found (may need to be created)"
            fi
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
