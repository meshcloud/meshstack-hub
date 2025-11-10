#!/usr/bin/env bash
# Use bash 4+ if available for associative arrays, otherwise fallback to bash 3 compatible approach

set -e

echo "=== SAP BTP Dynamic Resource Import Script ==="
echo ""
echo "This script will automatically discover and import ALL existing SAP BTP resources."
echo ""

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo "Error: terraform.tfvars not found in current directory"
    exit 1
fi

# Extract values from terraform.tfvars using tofu console
echo "Reading configuration from terraform.tfvars..."

PROJECT_ID=$(tofu console <<< 'var.project_identifier' 2>/dev/null | tr -d '"')
ENABLE_CF=$(tofu console <<< 'var.enable_cloudfoundry' 2>/dev/null | tr -d '"')
CF_SERVICES=$(tofu console <<< 'var.cf_services' 2>/dev/null | tr -d '"')
ENTITLEMENTS=$(tofu console <<< 'var.entitlements' 2>/dev/null | tr -d '"')
USERS=$(tofu console <<< 'var.users' 2>/dev/null)

echo "  Project Identifier: $PROJECT_ID"
echo "  Cloud Foundry Enabled: $ENABLE_CF"
echo "  CF Services: $CF_SERVICES"
echo "  Entitlements: $ENTITLEMENTS"
echo ""

# Get resource IDs - try state first, then prompt for manual input
echo "Discovering resource IDs..."

# Get subaccount ID
SUBACCOUNT_ID=$(tofu show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type == "btp_subaccount" and .name == "subaccount") | .values.id' 2>/dev/null || echo "")

if [ -z "$SUBACCOUNT_ID" ]; then
    echo ""
    echo "Subaccount ID not found in state."
    read -p "Enter Subaccount ID: " SUBACCOUNT_ID
fi

echo "  Subaccount ID: $SUBACCOUNT_ID"

# Get CF environment ID if enabled
CF_ENV_ID=""
if [ "$ENABLE_CF" = "true" ]; then
    CF_ENV_ID=$(tofu show -json 2>/dev/null | jq -r '.values.root_module.resources[] | select(.type == "btp_subaccount_environment_instance" and .name == "cloudfoundry") | .values.id' 2>/dev/null || echo "")
    
    if [ -z "$CF_ENV_ID" ]; then
        echo ""
        echo "Cloud Foundry Environment ID not found in state."
        echo "You can find it with: btp list accounts/environment-instance --subaccount $SUBACCOUNT_ID"
        read -p "Enter CF Environment ID: " CF_ENV_ID
    fi
    
    echo "  CF Environment ID: $CF_ENV_ID"
fi

# Get CF service instance IDs - build JSON map for lookup
echo "  Discovering CF service instances..."
CF_SERVICE_IDS_JSON=$(tofu show -json 2>/dev/null | jq -c 'reduce (.values.root_module.resources[] | select(.type == "btp_subaccount_service_instance" and .name == "cf_service")) as $item ({}; .[$item.index] = $item.values.id)' 2>/dev/null || echo "{}")

# Check if we found any in state
CF_SERVICES_IN_STATE=$(echo "$CF_SERVICE_IDS_JSON" | jq -r 'keys | length' 2>/dev/null || echo "0")

if [ "$CF_SERVICES_IN_STATE" = "0" ] && [ -n "$CF_SERVICES" ] && [ "$CF_SERVICES" != '""' ]; then
    echo ""
    echo "No CF service instances found in state."
    echo "You can find them with: btp list services/instance --subaccount $SUBACCOUNT_ID"
    echo ""
    echo "Please enter service instance IDs for each service:"
    
    # Parse services and prompt for each ID
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
    
    # Check if already imported
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

# Import subaccount
import_resource \
    "btp_subaccount.subaccount" \
    "$SUBACCOUNT_ID" \
    "BTP Subaccount"

# Import entitlements
if [ -n "$ENTITLEMENTS" ] && [ "$ENTITLEMENTS" != '""' ] && [ "$ENTITLEMENTS" != "" ]; then
    echo "Importing entitlements..."
    
    # Parse entitlements (format: service.plan,service.plan)
    IFS=',' read -ra ENTITLEMENT_ARRAY <<< "$ENTITLEMENTS"
    
    for entitlement_entry in "${ENTITLEMENT_ARRAY[@]}"; do
        entitlement_entry=$(echo "$entitlement_entry" | xargs) # trim whitespace
        if [ -n "$entitlement_entry" ]; then
            service_name=$(echo "$entitlement_entry" | cut -d'.' -f1)
            plan_name=$(echo "$entitlement_entry" | cut -d'.' -f2)
            resource_key="${service_name}-${plan_name}"
            
            # Entitlement import ID format: subaccount_id,service_name,plan_name
            import_resource \
                "btp_subaccount_entitlement.entitlement_without_quota[\"$resource_key\"]" \
                "$SUBACCOUNT_ID,$service_name,$plan_name" \
                "Entitlement: $service_name.$plan_name"
        fi
    done
fi

# Import Cloud Foundry environment if enabled
if [ "$ENABLE_CF" = "true" ] && [ -n "$CF_ENV_ID" ]; then
    import_resource \
        "btp_subaccount_environment_instance.cloudfoundry[0]" \
        "$SUBACCOUNT_ID,$CF_ENV_ID" \
        "Cloud Foundry Environment Instance"
fi

# Import CF service instances
if [ -n "$CF_SERVICES" ] && [ "$CF_SERVICES" != '""' ] && [ "$CF_SERVICES" != "" ]; then
    echo "Importing CF service instances..."
    
    # Parse services from cf_services variable (format: service.plan,service.plan)
    IFS=',' read -ra SERVICE_ARRAY <<< "$CF_SERVICES"
    
    for service_entry in "${SERVICE_ARRAY[@]}"; do
        service_entry=$(echo "$service_entry" | xargs) # trim whitespace
        if [ -n "$service_entry" ]; then
            # service.plan -> name-plan format (e.g., destination.lite -> destination-lite)
            service_name=$(echo "$service_entry" | cut -d'.' -f1)
            plan_name=$(echo "$service_entry" | cut -d'.' -f2)
            instance_name="${service_name}-${plan_name}"
            
            # The resource key is name-plan-plan (e.g., destination-lite-lite)
            resource_key="${instance_name}-${plan_name}"
            
            # Get instance ID from state JSON
            instance_id=$(echo "$CF_SERVICE_IDS_JSON" | jq -r --arg key "$resource_key" '.[$key] // empty')
            
            if [ -n "$instance_id" ]; then
                import_resource \
                    "btp_subaccount_service_instance.cf_service[\"$resource_key\"]" \
                    "$SUBACCOUNT_ID,$instance_id" \
                    "CF Service: $service_name.$plan_name"
            else
                echo "  ⚠ CF Service instance $resource_key not found in state (may need to be created)"
            fi
        fi
    done
fi

# Note about resources that cannot be imported
echo "=== Resources that cannot be imported ==="
echo ""
echo "The following resources cannot be imported per SAP BTP provider design:"
echo "  • Role collection assignments (will be managed on next apply)"
echo ""

# Show which role assignments will be created
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
