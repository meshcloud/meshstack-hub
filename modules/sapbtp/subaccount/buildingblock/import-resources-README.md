# Dynamic SAP BTP Resource Importer

## Overview

Automatically imports existing SAP BTP resources into OpenTofu state by reading configuration from `terraform.tfvars` and discovering resource IDs from state.

Available for both **Bash** (Linux/macOS) and **PowerShell** (Windows).

## Features

✅ **Fully Automatic** - No manual resource ID lookup required
✅ **Idempotent** - Safe to run multiple times
✅ **Smart Discovery** - Reads `terraform.tfvars` to know what to import
✅ **Error Handling** - Tracks successful and failed imports
✅ **Skip Already Imported** - Detects and skips resources already in state

## Usage

**Bash (Linux/macOS):**
```bash
./import-resources.sh
```

**PowerShell (Windows):**
```powershell
./import-resources.ps1
```

That's it! The script does everything automatically.

## What It Does

### 1. Reads Configuration
From `terraform.tfvars`:
- `project_identifier` - Subaccount name
- `enable_cloudfoundry` - Whether CF environment exists
- `cf_services` - Comma-separated list of CF service instances (e.g., "destination.lite,xsuaa.application")

### 2. Discovers Resource IDs
From OpenTofu state (or manual input if empty):
- `btp_subaccount_id` - Subaccount ID
- `cloudfoundry_instance_id` - CF environment ID
- `cloudfoundry_services` - All CF service instance IDs

### 3. Imports Resources
- Subaccount
- Cloud Foundry environment (if enabled)
- All CF service instances (from `cf_services` variable)

### 4. Skips Non-Importable Resources
- Role assignments (not supported by provider)
- Entitlements (managed declaratively)

## Example Output

```
=== SAP BTP Dynamic Resource Import Script ===

Reading configuration from terraform.tfvars...
  Project Identifier: testsubaccount
  Cloud Foundry Enabled: true
  CF Services: destination.lite,xsuaa.application

Discovering resource IDs...
  Subaccount ID: af3b4e1c-b28d-4c6d-9e4a-3e7ffa725ed3
  CF Environment ID: 8EE92B2C-120D-4988-931A-598EC72E5273

Starting imports...

Importing: BTP Subaccount
  Resource: btp_subaccount.subaccount
  ID: af3b4e1c-b28d-4c6d-9e4a-3e7ffa725ed3
  ✓ SUCCESS

Importing: Cloud Foundry Environment Instance
  Resource: btp_subaccount_environment_instance.cloudfoundry[0]
  ID: af3b4e1c-b28d-4c6d-9e4a-3e7ffa725ed3,8EE92B2C-120D-4988-931A-598EC72E5273
  ✓ SUCCESS

Importing: CF Service: destination.lite
  Resource: btp_subaccount_service_instance.cf_service["destination-lite-lite"]
  ID: af3b4e1c-b28d-4c6d-9e4a-3e7ffa725ed3,040e5544-2923-4ef5-a00b-99afdb7b4005
  ✓ SUCCESS

=== Import Summary ===

Successful imports (4):
  ✓ BTP Subaccount
  ✓ Cloud Foundry Environment Instance
  ✓ CF Service: destination.lite
  ✓ CF Service: xsuaa.application

Next steps:
  1. Run 'tofu plan' to verify the state
  2. Run 'tofu apply' to create any remaining resources
```

## Requirements

**Common (All Platforms):**
- `tofu` (OpenTofu) installed and configured
- Valid BTP provider credentials (set via environment variables)
- Existing `terraform.tfvars` with configuration
- BTP CLI (`btp`) for manual ID lookup (if starting from empty state)
- Cloud Foundry CLI (`cf`) for service instance GUIDs (if importing CF services)

**Bash Script (Linux/macOS):**
- Bash 3.2+ (macOS default) or higher
- `jq` for JSON parsing (version 1.6+)

**PowerShell Script (Windows):**
- PowerShell 5.1+ or PowerShell Core 7+

## Workflow

### Initial Import (No State)

**Bash:**
```bash
# 1. Ensure terraform.tfvars exists with correct configuration
cat terraform.tfvars

# 2. Run the import script
./import-resources.sh

# 3. Verify the imported resources
tofu state list

# 4. Check what still needs to be created
tofu plan

# 5. Apply remaining resources (entitlements, role assignments)
tofu apply
```

**PowerShell:**
```powershell
# 1. Ensure terraform.tfvars exists with correct configuration
Get-Content terraform.tfvars

# 2. Run the import script
./import-resources.ps1

# 3. Verify the imported resources
tofu state list

# 4. Check what still needs to be created
tofu plan

# 5. Apply remaining resources (entitlements, role assignments)
tofu apply
```

### Re-running (State Exists)

**Bash:**
```bash
./import-resources.sh
```

**PowerShell:**
```powershell
./import-resources.ps1
```

Output:
```
⊙ ALREADY IMPORTED (skipping)
```

Both scripts are idempotent and safe to run multiple times.

## Configuration Examples

### Minimal Configuration
```hcl
# terraform.tfvars
globalaccount      = "myaccount"
project_identifier = "myproject"
region             = "eu10"
```

Imports: Subaccount only

### With Cloud Foundry
```hcl
# terraform.tfvars
globalaccount       = "myaccount"
project_identifier  = "myproject"
region              = "eu10"
enable_cloudfoundry = true
cloudfoundry_plan   = "standard"
```

Imports: Subaccount + CF environment

### With CF Services
```hcl
# terraform.tfvars
globalaccount       = "myaccount"
project_identifier  = "myproject"
region              = "eu10"
enable_cloudfoundry = true
cf_services         = "destination.lite,xsuaa.application,postgresql.small"
```

Imports: Subaccount + CF environment + 3 service instances

## Troubleshooting

### "Could not discover subaccount ID"
When state is empty, the script will prompt for manual input.

Find your IDs using the BTP CLI:
```bash
# Subaccount ID
btp list accounts/subaccount

# CF Environment ID (8EE92... format)
btp list accounts/environment-instance --subaccount <subaccount-id>

# CF Service Instance IDs (040e5... format)
cf services
cf service <service-name> --guid
```

### "Service instance not found"
The service instance might not exist yet or the name doesn't match.

Check outputs:
```bash
tofu output -json | jq '.cloudfoundry_services.value'
```

### Import fails with "already managed by Terraform"
Resource is already in state. The script should detect this, but if not:
```bash
tofu state list | grep <resource-name>
```

## Technical Details

### Resource Discovery Logic

**Bash Script:**
1. **State (Primary)**
   ```bash
   tofu show -json | jq -r '.values.root_module.resources[]...'
   ```

2. **Manual Input (If State Empty)**
   ```bash
   read -p "Enter Subaccount ID: "
   ```

**PowerShell Script:**
1. **State (Primary)**
   ```powershell
   tofu show -json | ConvertFrom-Json
   $stateJson.values.root_module.resources | Where-Object {...}
   ```

2. **Manual Input (If State Empty)**
   ```powershell
   Read-Host "Enter Subaccount ID"
   ```

### Resource Naming Pattern

CF services follow this pattern from `locals.tf`:
```
cf_services = "destination.lite,xsuaa.application"
           ↓
Resource key: "destination-lite-lite"
Instance name: "destination-lite"
```

## Limitations

- **Role assignments** cannot be imported (SAP BTP provider limitation)
- **Entitlements** don't need import (managed declaratively)
- Bash script requires **jq** for JSON parsing
- PowerShell script requires **PowerShell 5.1+**

## Exit Codes

- `0` - All imports successful
- `1` - One or more imports failed

## Platform Notes

### macOS/Linux
- Uses bash 3.2+ compatible syntax (macOS default shell)
- Requires `jq` for JSON parsing: `brew install jq`

### Windows
- PowerShell 5.1+ included by default in Windows 10+
- PowerShell Core 7+ recommended for cross-platform consistency
- Native JSON parsing with `ConvertFrom-Json`

## See Also

- [import-resources.sh](./import-resources.sh) - Bash script for Linux/macOS
- [import-resources.ps1](./import-resources.ps1) - PowerShell script for Windows
- [terraform.tfvars](./terraform.tfvars) - Configuration file
- [main.tf](./main.tf) - Resource definitions
