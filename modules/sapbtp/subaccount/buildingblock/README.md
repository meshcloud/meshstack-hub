---
name: SAP BTP Subaccount
supportedPlatforms:
  - sapbtp
description: |
  Provisions SAP BTP subaccounts with user role assignments. Core foundation for all other BTP building blocks.
category: platform
---

# SAP BTP Subaccount

This Terraform module provisions a subaccount in SAP Business Technology Platform (BTP) with user role collection assignments.

## Features

This building block provides:

- **Subaccount Creation**: Basic subaccount provisioning with region and folder placement
- **User Role Assignments**: Automatic assignment of users to standard role collections
  - **Subaccount Administrator**: Full administrative access (for users with `admin` role)
  - **Subaccount Service Administrator**: Service management capabilities (for users with `user` role)
  - **Subaccount Viewer**: Read-only access (for users with `reader` role)

## Architecture

This is the **foundational module** in the SAP BTP module hierarchy. Other building blocks depend on this module:

```
subaccount (this module)
    ↓
    ├── entitlements (service quota assignments)
    ├── subscriptions (application subscriptions)
    ├── cloudfoundry (CF environment + services)
    └── trust-configuration (custom IdP integration)
```

## Usage Example

### Creating a New Subaccount (meshStack Pattern)

Use the `subfolder` parameter to specify the parent directory by name:

```hcl
globalaccount       = "my-global-account"
project_identifier  = "my-project-dev"
region              = "eu10"
subfolder           = "Development"

users = [
  {
    meshIdentifier = "alice-user"
    username       = "alice@company.com"
    firstName      = "Alice"
    lastName       = "Smith"
    email          = "alice@company.com"
    euid           = "alice@company.com"
    roles          = ["admin"]
  },
  {
    meshIdentifier = "bob-user"
    username       = "bob@company.com"
    firstName      = "Bob"
    lastName       = "Jones"
    email          = "bob@company.com"
    euid           = "bob@company.com"
    roles          = ["user"]
  }
]
```

### Importing an Existing Subaccount

Use the `parent_id` parameter to specify the parent directory by UUID (useful when importing):

```hcl
globalaccount       = "my-global-account"
project_identifier  = "existing-subaccount"
region              = "eu30"
parent_id           = "9b8960a6-b80a-4096-80e5-a61bea98ac48"

users = []
```

**Note:** `subfolder` and `parent_id` are mutually exclusive. Use `subfolder` (name) for new deployments and `parent_id` (UUID) when importing existing subaccounts.

## Role Mapping

| meshStack Role | BTP Role Collection | Permissions |
|----------------|---------------------|-------------|
| `admin` | Subaccount Administrator | Full subaccount management |
| `user` | Subaccount Service Administrator | Service instance management |
| `reader` | Subaccount Viewer | Read-only access |

## Importing Existing Subaccounts

Use the provided import script to import existing subaccounts:

```bash
./import-resources.sh
```

The script will:
1. Discover the subaccount ID from state or prompt for manual entry
2. Import the subaccount resource
3. Note that role assignments must be created on next `tofu apply`

## Providers

```hcl
terraform {
  required_providers {
    btp = {
      source  = "SAP/btp"
      version = "~> 1.8.0"
    }
  }
}
```

## Next Steps

After provisioning a subaccount, you can add:
- **Entitlements**: Use the `entitlements` building block to assign service quotas
- **Subscriptions**: Use the `subscriptions` building block to subscribe to SaaS applications
- **Cloud Foundry**: Use the `cloudfoundry` building block to provision CF environment and services
- **Custom IdP**: Use the `trust-configuration` building block to integrate external identity providers
