---
name: Azure DevOps Project
supportedPlatforms:
  - azuredevops
description: |
  Creates and manages Azure DevOps projects with user entitlements, stakeholder licenses, and role-based group memberships.
---

# Azure DevOps Project Building Block

This building block creates an Azure DevOps project and manages user access with appropriate licenses and group memberships.

## Features

- **Project Creation**: Creates Azure DevOps projects with configurable settings
- **User Management**: Assigns users from authoritative system to project groups
- **Role-Based Access**: Maps user roles to default Azure DevOps project groups
- **No License Management**: Licenses are managed by the authoritative system

## Prerequisites

- Azure DevOps organization
- Users provided by authoritative system with assigned roles
- Personal Access Token with required scopes (managed by backplane)
- User licenses managed externally by authoritative system

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   Backplane     │───▶│  Building Block │───▶│ Azure DevOps Org │
│                 │    │                 │    │                  │
│ • Service       │    │ • Project       │    │ • Project        │
│   Principal     │    │   Creation      │    │ • Users assigned │
│ • Key Vault     │    │ • User Role     │    │   to groups      │
│ • PAT Storage   │    │   Mapping       │    │ • No license     │
│                 │    │ • Group         │    │   management     │
│                 │    │   Memberships   │    │                  │
└─────────────────┘    └─────────────────┘    └──────────────────┘
```

## Usage

```hcl
module "azure_devops_project" {
  source = "path/to/azuredevops/project/buildingblock"

  # Connection settings (from backplane)
  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name               = "kv-azdevops-terraform"
  resource_group_name          = "rg-azdevops-terraform"

  # Project configuration
  project_name        = "my-new-project"
  project_description = "Project for development team"
  project_visibility  = "private"
  work_item_template  = "Agile"

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

  # Optional: Disable certain features
  project_features = {
    testplans = "disabled"
    artifacts = "disabled"
  }
}
```

## Default Project Features

The building block creates projects with the following default features:

- **Boards**: `enabled` - Agile planning and tracking
- **Repositories**: `enabled` - Git repositories
- **Pipelines**: `enabled` - CI/CD pipelines
- **Test Plans**: `disabled` - Manual testing (can be expensive)
- **Artifacts**: `enabled` - Package management

## User Roles

Users are assigned to default Azure DevOps project groups based on their roles list:

- **reader** in roles list: Assigned to "Readers" group - Read-only access to project artifacts
- **user** in roles list: Assigned to "Contributors" group - Can contribute code, work items, and builds
- **admin** in roles list: Assigned to "Project Administrators" group - Full project administration rights

Users can have multiple roles and will be assigned to all corresponding groups.

## Important Notes

- **User Management**: Users are provided by authoritative system with pre-assigned roles.
- **License Management**: User licenses are managed externally by the authoritative system.
- **PAT Requirements**: The Personal Access Token needs specific scopes (managed by backplane).
- **Group Management**: Uses built-in Azure DevOps project groups for access control.
- **Role Mapping**: Users with multiple roles will be assigned to all corresponding groups.

## Troubleshooting

### User Not Found Error
If you get "User not found" errors:
1. Verify the user exists in your Azure AD/identity provider
2. Check the email address format matches the identity provider
3. Ensure the user has been invited to the Azure DevOps organization

### License Assignment Failures
If license assignment fails:
1. Verify your PAT has "Member Entitlement Management" permissions
2. Check you have organization-level permissions to assign licenses
3. Ensure sufficient licenses are available in your organization

### Permission Denied Errors
If you get permission errors:
1. Verify PAT scopes include "Project & Team (Read, Write, & Manage)"
2. Check the service principal has access to the Key Vault
3. Ensure the PAT hasn't expired
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | ~> 1.1.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.51.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuredevops_group_membership.administrators](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/group_membership) | resource |
| [azuredevops_group_membership.contributors](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/group_membership) | resource |
| [azuredevops_group_membership.readers](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/group_membership) | resource |
| [azuredevops_project.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/project) | resource |
| [azuredevops_group.project_administrators](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/data-sources/group) | data source |
| [azuredevops_group.project_contributors](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/data-sources/group) | data source |
| [azuredevops_group.project_readers](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/data-sources/group) | data source |
| [azuredevops_users.all_users](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/data-sources/users) | data source |
| [azurerm_key_vault.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.azure_devops_pat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#input\_azure\_devops\_organization\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault containing the Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_pat_secret_name"></a> [pat\_secret\_name](#input\_pat\_secret\_name) | n/a | `string` | `"Name of the Azure DevOps PAT Token stored in the KeyVault"` | no |
| <a name="input_project_description"></a> [project\_description](#input\_project\_description) | Description of the Azure DevOps project | `string` | `"Managed by Terraform"` | no |
| <a name="input_project_features"></a> [project\_features](#input\_project\_features) | Project features to enable/disable | <pre>object({<br>    boards       = optional(string, "enabled")<br>    repositories = optional(string, "enabled")<br>    pipelines    = optional(string, "enabled")<br>    testplans    = optional(string, "disabled")<br>    artifacts    = optional(string, "enabled")<br>  })</pre> | <pre>{<br>  "artifacts": "enabled",<br>  "boards": "enabled",<br>  "pipelines": "enabled",<br>  "repositories": "enabled",<br>  "testplans": "disabled"<br>}</pre> | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the Azure DevOps project | `string` | n/a | yes |
| <a name="input_project_visibility"></a> [project\_visibility](#input\_project\_visibility) | Visibility of the project (private or public) | `string` | `"private"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group name containing the Key Vault | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from authoritative system | <pre>list(object({<br>    meshIdentifier = string<br>    username       = string<br>    firstName      = string<br>    lastName       = string<br>    email          = string<br>    euid           = string<br>    roles          = list(string)<br>  }))</pre> | n/a | yes |
| <a name="input_version_control"></a> [version\_control](#input\_version\_control) | Version control system for the project | `string` | `"Git"` | no |
| <a name="input_work_item_template"></a> [work\_item\_template](#input\_work\_item\_template) | Work item process template | `string` | `"Agile"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#output\_azure\_devops\_organization\_url) | Azure DevOps organization URL |
| <a name="output_group_memberships"></a> [group\_memberships](#output\_group\_memberships) | Information about group memberships |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Name of the Key Vault containing the Azure DevOps PAT |
| <a name="output_pat_secret_name"></a> [pat\_secret\_name](#output\_pat\_secret\_name) | Name of the Azure DevOps PAT secret in Key Vault |
| <a name="output_project_features"></a> [project\_features](#output\_project\_features) | Enabled/disabled project features |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | ID of the created Azure DevOps project |
| <a name="output_project_name"></a> [project\_name](#output\_project\_name) | Name of the created Azure DevOps project |
| <a name="output_project_url"></a> [project\_url](#output\_project\_url) | URL of the created Azure DevOps project |
| <a name="output_project_visibility"></a> [project\_visibility](#output\_project\_visibility) | Visibility of the project |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group name containing the Key Vault |
| <a name="output_user_assignments"></a> [user\_assignments](#output\_user\_assignments) | Map of users and their assigned roles |
<!-- END_TF_DOCS -->