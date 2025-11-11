#!/usr/bin/env pwsh
# SAP BTP Dynamic Resource Import Script for PowerShell
# Automatically discovers and imports existing SAP BTP resources into OpenTofu state

$ErrorActionPreference = "Stop"

Write-Host "=== SAP BTP Dynamic Resource Import Script ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script will automatically discover and import ALL existing SAP BTP resources."
Write-Host ""

# Check if terraform.tfvars exists
if (-not (Test-Path "terraform.tfvars")) {
    Write-Host "Error: terraform.tfvars not found in current directory" -ForegroundColor Red
    exit 1
}

# Extract values from terraform.tfvars using tofu console
Write-Host "Reading configuration from terraform.tfvars..."

$PROJECT_ID = (Write-Output 'var.project_identifier' | tofu console 2>$null) -replace '"', ''
$ENABLE_CF = (Write-Output 'var.enable_cloudfoundry' | tofu console 2>$null) -replace '"', ''
$CF_SERVICES = (Write-Output 'var.cf_services' | tofu console 2>$null) -replace '"', ''
$ENTITLEMENTS = (Write-Output 'var.entitlements' | tofu console 2>$null) -replace '"', ''
$USERS = Write-Output 'var.users' | tofu console 2>$null

Write-Host "  Project Identifier: $PROJECT_ID"
Write-Host "  Cloud Foundry Enabled: $ENABLE_CF"
Write-Host "  CF Services: $CF_SERVICES"
Write-Host "  Entitlements: $ENTITLEMENTS"
Write-Host ""

# Get resource IDs - try state first, then prompt for manual input
Write-Host "Discovering resource IDs..."

# Get subaccount ID
$stateJson = tofu show -json 2>$null | ConvertFrom-Json -ErrorAction SilentlyContinue
$SUBACCOUNT_ID = ($stateJson.values.root_module.resources | Where-Object { $_.type -eq "btp_subaccount" -and $_.name -eq "subaccount" } | Select-Object -First 1).values.id

if (-not $SUBACCOUNT_ID) {
    Write-Host ""
    Write-Host "Subaccount ID not found in state."
    $SUBACCOUNT_ID = Read-Host "Enter Subaccount ID"
}

Write-Host "  Subaccount ID: $SUBACCOUNT_ID"

# Get CF environment ID if enabled
$CF_ENV_ID = ""
if ($ENABLE_CF -eq "true") {
    $CF_ENV_ID = ($stateJson.values.root_module.resources | Where-Object { $_.type -eq "btp_subaccount_environment_instance" -and $_.name -eq "cloudfoundry" } | Select-Object -First 1).values.id
    
    if (-not $CF_ENV_ID) {
        Write-Host ""
        Write-Host "Cloud Foundry Environment ID not found in state."
        Write-Host "You can find it with: btp list accounts/environment-instance --subaccount $SUBACCOUNT_ID"
        $CF_ENV_ID = Read-Host "Enter CF Environment ID"
    }
    
    Write-Host "  CF Environment ID: $CF_ENV_ID"
}

# Get CF service instance IDs - build hashtable for lookup
Write-Host "  Discovering CF service instances..."
$CF_SERVICE_IDS = @{}

$cfServiceResources = $stateJson.values.root_module.resources | Where-Object { $_.type -eq "btp_subaccount_service_instance" -and $_.name -eq "cf_service" }
foreach ($resource in $cfServiceResources) {
    if ($resource.index -and $resource.values.id) {
        $CF_SERVICE_IDS[$resource.index] = $resource.values.id
    }
}

# Check if we found any in state
if ($CF_SERVICE_IDS.Count -eq 0 -and $CF_SERVICES -and $CF_SERVICES -ne '""') {
    Write-Host ""
    Write-Host "No CF service instances found in state."
    Write-Host "You can find them with: btp list services/instance --subaccount $SUBACCOUNT_ID"
    Write-Host ""
    Write-Host "Please enter service instance IDs for each service:"
    
    # Parse services and prompt for each ID
    $serviceArray = $CF_SERVICES -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($serviceEntry in $serviceArray) {
        if ($serviceEntry) {
            $serviceName, $planName = $serviceEntry -split '\.'
            $instanceName = "$serviceName-$planName"
            $resourceKey = "$instanceName-$planName"
            
            $serviceId = Read-Host "  Enter ID for $serviceName.$planName (name: $instanceName)"
            $CF_SERVICE_IDS[$resourceKey] = $serviceId
        }
    }
}

Write-Host ""

$FAILED_IMPORTS = @()
$SUCCESSFUL_IMPORTS = @()

function Import-Resource {
    param(
        [string]$ResourceAddress,
        [string]$ResourceId,
        [string]$Description
    )
    
    Write-Host "Importing: $Description"
    Write-Host "  Resource: $ResourceAddress"
    Write-Host "  ID: $ResourceId"
    
    # Check if already imported
    $stateCheck = tofu state show $ResourceAddress 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ⊙ ALREADY IMPORTED (skipping)" -ForegroundColor Yellow
        $script:SUCCESSFUL_IMPORTS += "$Description (already imported)"
        Write-Host ""
        return $true
    }
    
    $importResult = tofu import $ResourceAddress $ResourceId 2>$null
    if ($LASTEXITCODE -eq 0) {
        $script:SUCCESSFUL_IMPORTS += $Description
        Write-Host "  ✓ SUCCESS" -ForegroundColor Green
    } else {
        $script:FAILED_IMPORTS += $Description
        Write-Host "  ✗ FAILED" -ForegroundColor Red
    }
    Write-Host ""
    return ($LASTEXITCODE -eq 0)
}

Write-Host "Starting imports..."
Write-Host ""

# Import subaccount
Import-Resource -ResourceAddress "btp_subaccount.subaccount" -ResourceId $SUBACCOUNT_ID -Description "BTP Subaccount"

# Import entitlements
if ($ENTITLEMENTS -and $ENTITLEMENTS -ne '""' -and $ENTITLEMENTS -ne "") {
    Write-Host "Importing entitlements..."
    
    # Parse entitlements (format: service.plan,service.plan)
    $entitlementArray = $ENTITLEMENTS -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($entitlementEntry in $entitlementArray) {
        if ($entitlementEntry) {
            $serviceName, $planName = $entitlementEntry -split '\.'
            $resourceKey = "$serviceName-$planName"
            
            # Entitlement import ID format: subaccount_id,service_name,plan_name
            Import-Resource `
                -ResourceAddress "btp_subaccount_entitlement.entitlement_without_quota[`"$resourceKey`"]" `
                -ResourceId "$SUBACCOUNT_ID,$serviceName,$planName" `
                -Description "Entitlement: $serviceName.$planName"
        }
    }
}

# Import Cloud Foundry environment if enabled
if ($ENABLE_CF -eq "true" -and $CF_ENV_ID) {
    Import-Resource `
        -ResourceAddress "btp_subaccount_environment_instance.cloudfoundry[0]" `
        -ResourceId "$SUBACCOUNT_ID,$CF_ENV_ID" `
        -Description "Cloud Foundry Environment Instance"
}

# Import CF service instances
if ($CF_SERVICES -and $CF_SERVICES -ne '""' -and $CF_SERVICES -ne "") {
    Write-Host "Importing CF service instances..."
    
    # Parse services from cf_services variable (format: service.plan,service.plan)
    $serviceArray = $CF_SERVICES -split ',' | ForEach-Object { $_.Trim() }
    
    foreach ($serviceEntry in $serviceArray) {
        if ($serviceEntry) {
            # service.plan -> name-plan format (e.g., destination.lite -> destination-lite)
            $serviceName, $planName = $serviceEntry -split '\.'
            $instanceName = "$serviceName-$planName"
            
            # The resource key is name-plan-plan (e.g., destination-lite-lite)
            $resourceKey = "$instanceName-$planName"
            
            # Get instance ID from hashtable
            $instanceId = $CF_SERVICE_IDS[$resourceKey]
            
            if ($instanceId) {
                Import-Resource `
                    -ResourceAddress "btp_subaccount_service_instance.cf_service[`"$resourceKey`"]" `
                    -ResourceId "$SUBACCOUNT_ID,$instanceId" `
                    -Description "CF Service: $serviceName.$planName"
            } else {
                Write-Host "  ⚠ CF Service instance $resourceKey not found in state (may need to be created)" -ForegroundColor Yellow
            }
        }
    }
}

# Note about resources that cannot be imported
Write-Host "=== Resources that cannot be imported ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "The following resources cannot be imported per SAP BTP provider design:"
Write-Host "  • Role collection assignments (will be managed on next apply)"
Write-Host ""

# Show which role assignments will be created
if ($USERS -and $USERS -ne "[]") {
    Write-Host "Role assignments to be created:"
    try {
        $usersObj = $USERS | ConvertFrom-Json
        foreach ($user in $usersObj) {
            $roles = $user.roles -join ", "
            Write-Host "  • $($user.euid) - role: $roles"
        }
    } catch {
        Write-Host "  (Cannot parse users)"
    }
}

Write-Host ""

Write-Host "=== Import Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Successful imports ($($SUCCESSFUL_IMPORTS.Count)):" -ForegroundColor Green
foreach ($item in $SUCCESSFUL_IMPORTS) {
    Write-Host "  ✓ $item"
}
Write-Host ""

if ($FAILED_IMPORTS.Count -gt 0) {
    Write-Host "Failed imports ($($FAILED_IMPORTS.Count)):" -ForegroundColor Red
    foreach ($item in $FAILED_IMPORTS) {
        Write-Host "  ✗ $item"
    }
    Write-Host ""
}

Write-Host "Next steps:"
Write-Host "  1. Run 'tofu plan' to verify the state"
Write-Host "  2. Run 'tofu apply' to create role collection assignments"
Write-Host ""

if ($FAILED_IMPORTS.Count -gt 0) {
    exit 1
}
