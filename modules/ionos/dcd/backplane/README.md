# IONOS DCD Backplane

This backplane module sets up the foundational infrastructure for managing IONOS Data Center Designer (DCD) environments.

## Purpose

The backplane creates and manages:
- IONOS service users for Terraform operations
- Administrative groups with appropriate permissions
- Foundational access controls for DCD management

## Usage

```hcl
module "ionos_dcd_backplane" {
  source = "path/to/ionos/dcd/backplane"

  service_user_email = "terraform-service@company.com"
  initial_password   = var.service_password
  group_name         = "DCD-Terraform-Managers"
  
  # Authentication
  ionos_username = var.ionos_admin_username
  ionos_password = var.ionos_admin_password
}
```

## Outputs

The backplane provides outputs that can be used by building blocks:
- Service user credentials
- Group IDs for permission management
- Administrative user information

## Requirements

- IONOS Cloud account with administrative access
- Permissions to create users and groups
- API access enabled