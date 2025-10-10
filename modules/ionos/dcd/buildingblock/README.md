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

  # Authentication is handled via IONOS_TOKEN environment variable

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

| `users` | List of users from authoritative system | `list(object)` | - | yes |



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
| `dcd_url` | Direct URL to access the IONOS DCD datacenter |
| `user_assignments` | Map of users and their assigned roles |
| `group_memberships` | Information about group memberships |

## Important Notes

- **User Prerequisites**: Users must exist in IONOS Cloud (created by user-management module)
- **Datacenter Isolation**: Each DCD environment has its own groups and permissions
- **Administrator Access**: Administrators get global access and don't need group memberships
- **Resource Sharing**: Groups are automatically granted appropriate access to the datacenter
- **Role Mapping**: Users are assigned to datacenter-specific groups based on their roles

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
| [ionoscloud_datacenter.main](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/datacenter) | resource |
| [ionoscloud_group.administrators](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/group) | resource |
| [ionoscloud_group.readers](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/group) | resource |
| [ionoscloud_group.users](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/group) | resource |
| [ionoscloud_share.administrators](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/share) | resource |
| [ionoscloud_share.readers](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/share) | resource |
| [ionoscloud_share.users](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/resources/share) | resource |
| [ionoscloud_user.administrators](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/data-sources/user) | data source |
| [ionoscloud_user.readers](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/data-sources/user) | data source |
| [ionoscloud_user.users](https://registry.terraform.io/providers/ionos-cloud/ionoscloud/latest/docs/data-sources/user) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_datacenter_description"></a> [datacenter\_description](#input\_datacenter\_description) | Description of the datacenter | `string` | `"Managed by Terraform"` | no |
| <a name="input_datacenter_location"></a> [datacenter\_location](#input\_datacenter\_location) | Location for the IONOS datacenter | `string` | `"de/fra"` | no |
| <a name="input_datacenter_name"></a> [datacenter\_name](#input\_datacenter\_name) | Name of the IONOS DCD datacenter | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from authoritative system | <pre>list(object({<br>    meshIdentifier = string<br>    username       = string<br>    firstName      = string<br>    lastName       = string<br>    email          = string<br>    euid           = string<br>    roles          = list(string)<br>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_datacenter_id"></a> [datacenter\_id](#output\_datacenter\_id) | ID of the created IONOS datacenter |
| <a name="output_datacenter_location"></a> [datacenter\_location](#output\_datacenter\_location) | Location of the created IONOS datacenter |
| <a name="output_datacenter_name"></a> [datacenter\_name](#output\_datacenter\_name) | Name of the created IONOS datacenter |
| <a name="output_dcd_url"></a> [dcd\_url](#output\_dcd\_url) | Direct URL to access the IONOS DCD datacenter |
| <a name="output_group_memberships"></a> [group\_memberships](#output\_group\_memberships) | Information about group memberships |
| <a name="output_user_assignments"></a> [user\_assignments](#output\_user\_assignments) | Map of users and their assigned roles |
<!-- END_TF_DOCS -->