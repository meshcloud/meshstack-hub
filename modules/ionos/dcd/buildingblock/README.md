---
name: IONOS DCD (Data Center Designer)
supportedPlatforms:
  - ionos
description: Creates and manages IONOS Data Center Designer environments with user onboarding, role-based access control, and datacenter provisioning.
category: infrastructure
---

# IONOS DCD Building Block

This building block creates an IONOS Data Center Designer (DCD) environment and manages user access with appropriate permissions and group memberships.

## Features

- **Datacenter Creation**: Creates IONOS DCD environments with configurable settings
- **User Management**: Creates users from authoritative system and assigns to appropriate groups
- **Role-Based Access**: Maps user roles to IONOS DCD permissions and groups
- **Resource Sharing**: Manages datacenter access permissions for different user groups

## Prerequisites

- IONOS Cloud account with appropriate permissions
- IONOS API credentials (username/password or API token)
- Users provided by authoritative system with assigned roles

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   Backplane     │───▶│  Building Block │───▶│   IONOS Cloud    │
│                 │    │                 │    │                  │
│ • Service User  │    │ • Datacenter    │    │ • DCD Environment│
│ • Group Setup   │    │   Creation      │    │ • Users created  │
│ • Permissions   │    │ • User Role     │    │ • Groups assigned│
│                 │    │   Mapping       │    │ • Permissions    │
│                 │    │ • Group         │    │   configured     │
│                 │    │   Memberships   │    │                  │
└─────────────────┘    └─────────────────┘    └──────────────────┘
```

## Usage

```hcl
module "ionos_dcd" {
  source = "path/to/ionos/dcd/buildingblock"

  # Datacenter configuration
  datacenter_name        = "my-development-dc"
  datacenter_location    = "de/fra"
  datacenter_description = "Development environment for team"

  # Authentication (from backplane)
  ionos_username = var.ionos_username
  ionos_password = var.ionos_password
  # OR use token instead:
  # ionos_token = var.ionos_token

  # User management
  default_user_password = var.user_password
  force_sec_auth       = true

  # Users provided by authoritative system
  users = [
    {
      meshIdentifier = "user-001"
      username       = "developer1"
      firstName      = "John"
      lastName       = "Doe"
      email          = "developer1@company.com"
      euid           = "john.doe"
      roles          = ["user"]
    },
    {
      meshIdentifier = "user-002"
      username       = "manager1"
      firstName      = "Jane"
      lastName       = "Smith"
      email          = "manager@company.com"
      euid           = "jane.smith"
      roles          = ["admin", "reader"]
    }
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `datacenter_name` | Name of the IONOS DCD datacenter | `string` | - | yes |
| `datacenter_location` | Location for the datacenter | `string` | `"de/fra"` | no |
| `datacenter_description` | Description of the datacenter | `string` | `"Managed by Terraform"` | no |
| `ionos_username` | IONOS username for authentication | `string` | - | yes |
| `ionos_password` | IONOS password for authentication | `string` | - | yes* |
| `ionos_token` | IONOS API token (alternative to username/password) | `string` | `null` | yes* |
| `default_user_password` | Default password for created users | `string` | - | yes |
| `force_sec_auth` | Force two-factor authentication | `bool` | `true` | no |
| `users` | List of users from authoritative system | `list(object)` | - | yes |

*Either `ionos_password` or `ionos_token` is required.

## Supported Datacenter Locations

- `us/las` - Las Vegas, USA
- `us/ewr` - Newark, USA  
- `de/fra` - Frankfurt, Germany
- `de/fkb` - Karlsruhe, Germany
- `de/txl` - Berlin, Germany
- `gb/lhr` - London, UK
- `es/vit` - Vitoria, Spain
- `fr/par` - Paris, France

## User Roles

Users are assigned to IONOS groups based on their roles list:

- **reader** in roles list: Read-only access group with monitoring permissions
- **user** in roles list: Standard user group with VM/network management permissions  
- **admin** in roles list: Administrator group with full datacenter management permissions

Users can have multiple roles and will be assigned to all corresponding groups.

## Group Permissions

### Readers Group
- Access activity log: ✅
- Access monitoring: ✅
- All other permissions: ❌

### Users Group  
- Create snapshots: ✅
- Reserve IP addresses: ✅
- Access activity log: ✅
- S3 privilege: ✅
- Create backup units: ✅
- Create internet access: ✅
- Create flow logs: ✅
- Access monitoring: ✅

### Administrators Group
- All permissions: ✅
- Create datacenters: ✅
- Create K8s clusters: ✅
- Create private cross-connects: ✅
- Manage certificates: ✅

## Outputs

| Name | Description |
|------|-------------|
| `datacenter_id` | ID of the created datacenter |
| `datacenter_name` | Name of the created datacenter |
| `datacenter_location` | Location of the datacenter |
| `user_assignments` | Map of users and their assigned roles |
| `group_memberships` | Information about group memberships |

## Important Notes

- **User Creation**: Users are created in IONOS Cloud with the provided information
- **Password Management**: All users get the same initial password (should be changed on first login)
- **Two-Factor Auth**: Can be enforced for enhanced security
- **Resource Sharing**: Groups are automatically granted appropriate access to the datacenter
- **Role Mapping**: Users with multiple roles will be assigned to all corresponding groups

## Troubleshooting

### Authentication Failures
If you get authentication errors:
1. Verify IONOS credentials are correct
2. Check if API token has sufficient permissions
3. Ensure account has DCD access enabled

### User Creation Errors
If user creation fails:
1. Verify email addresses are unique
2. Check password meets IONOS requirements
3. Ensure sufficient user licenses are available

### Permission Denied Errors
If you get permission errors:
1. Verify authenticating user has admin privileges
2. Check datacenter access permissions
3. Ensure group permissions are correctly configured