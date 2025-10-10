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
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_ionoscloud"></a> [ionoscloud](#requirement\_ionoscloud) | ~> 6.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ionoscloud_user.new_administrators](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/user) | resource |
| [ionoscloud_user.new_readers](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/user) | resource |
| [ionoscloud_user.new_users](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/user) | resource |
| [ionoscloud_user.existing_administrators](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/data-sources/user) | data source |
| [ionoscloud_user.existing_readers](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/data-sources/user) | data source |
| [ionoscloud_user.existing_users](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/data-sources/user) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_user_password"></a> [default\_user\_password](#input\_default\_user\_password) | Default password for created users | `string` | n/a | yes |
| <a name="input_force_sec_auth"></a> [force\_sec\_auth](#input\_force\_sec\_auth) | Force two-factor authentication for users | `bool` | `true` | no |
| <a name="input_ionos_token"></a> [ionos\_token](#input\_ionos\_token) | IONOS API token for authentication | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from authoritative system | <pre>list(object({<br>    meshIdentifier = string<br>    username       = string<br>    firstName      = string<br>    lastName       = string<br>    email          = string<br>    euid           = string<br>    roles          = list(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_all_users"></a> [all\_users](#output\_all\_users) | All users (existing and newly created) organized by role |
| <a name="output_user_summary"></a> [user\_summary](#output\_user\_summary) | Summary of user management |
<!-- END_TF_DOCS -->