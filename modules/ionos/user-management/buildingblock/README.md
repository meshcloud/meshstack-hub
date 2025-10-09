---
name: IONOS User Management
supportedPlatforms:
  - ionos
description: Creates and manages IONOS Cloud users with role-based access. This is a foundational module that should be deployed before DCD environments.
category: identity
---

# IONOS User Management Building Block

This building block creates and manages IONOS Cloud users from the authoritative system. It handles user creation, role assignment, and provides user information for other IONOS modules.

## Features

- **User Creation**: Creates IONOS users that don't already exist
- **Role-Based Management**: Organizes users by their assigned roles
- **Lifecycle Protection**: Prevents accidental user deletion
- **Existing User Detection**: Automatically detects and incorporates existing users

## Prerequisites

- IONOS Cloud account with user management permissions
- IONOS API token with sufficient privileges
- Users provided by authoritative system with assigned roles

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│  Authoritative  │───▶│ User Management │───▶│   IONOS Cloud    │
│     System      │    │ Building Block  │    │                  │
│                 │    │                 │    │ • Users created  │
│ • User Data     │    │ • User Creation │    │ • Roles assigned │
│ • Role Info     │    │ • Role Mapping  │    │ • Lifecycle      │
│ • Email Lists   │    │ • Existing User │    │   protected      │
│                 │    │   Detection     │    │                  │
└─────────────────┘    └─────────────────┘    └──────────────────┘
```

## Usage

```hcl
module "ionos_users" {
  source = "path/to/ionos/user-management/buildingblock"

  # Authentication
  ionos_token = var.ionos_token

  # User configuration
  default_user_password = var.user_password
  force_sec_auth       = true

  # Users from authoritative system
  users = [
    {
      meshIdentifier = "user-001"
      username       = "developer1"
      firstName      = "John"
      lastName       = "Doe"
      email          = "john.doe@company.com"
      euid           = "john.doe"
      roles          = ["user"]
    },
    {
      meshIdentifier = "user-002"
      username       = "admin1"
      firstName      = "Jane"
      lastName       = "Smith"
      email          = "jane.smith@company.com"
      euid           = "jane.smith"
      roles          = ["admin"]
    }
  ]
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `ionos_token` | IONOS API token for authentication | `string` | - | yes |
| `default_user_password` | Default password for created users | `string` | - | yes |
| `force_sec_auth` | Force two-factor authentication | `bool` | `true` | no |
| `users` | List of users from authoritative system | `list(object)` | - | yes |

## User Roles

Users are organized into three categories based on their roles:

- **reader**: Users with read-only access requirements
- **user**: Standard users with operational permissions
- **admin**: Administrators with full access rights

## Outputs

| Name | Description |
|------|-------------|
| `all_users` | All users organized by role with complete information |
| `user_summary` | Summary statistics of user management |

## Important Notes

- **Lifecycle Protection**: Users are protected from accidental deletion with `prevent_destroy = true`
- **Password Management**: Initial passwords are set but ignored on subsequent runs
- **Existing Users**: Automatically detects and incorporates existing IONOS users
- **No User Deletion**: This module does not delete users - only creates them
- **Role Organization**: Users are categorized by their primary role for use by other modules

## Integration with DCD Module

This module is designed to work with the IONOS DCD module:

1. **Deploy User Management first**: Create all users
2. **Deploy DCD environments**: Reference existing users for permissions
3. **Destroy DCD safely**: Users persist even when DCD environments are destroyed

## Best Practices

- **Deploy Once**: Typically deployed once per IONOS account/contract
- **Central Management**: All IONOS users should be managed through this module
- **Password Security**: Change default passwords on first login
- **Role Accuracy**: Ensure user roles match their intended access levels