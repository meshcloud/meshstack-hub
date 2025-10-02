---
name: Azure DevOps Project
supportedPlatforms:
  - azuredevops
description: Creates and manages Azure DevOps projects with user entitlements, stakeholder licenses, and role-based group memberships.
category: devops
---

# Azure DevOps Project Building Block

This building block creates an Azure DevOps project and manages user access with appropriate licenses and group memberships.

## Features

- **Project Creation**: Creates Azure DevOps projects with configurable settings
- **User Management**: Assigns licenses (including Stakeholder) to existing users
- **Role-Based Access**: Organizes users into project groups based on their roles
- **Custom Groups**: Optional creation of custom project groups
- **Feature Control**: Configure enabled/disabled project features

## Prerequisites

- Azure DevOps organization
- Users must already exist in your identity provider (Azure AD, MSA, etc.)
- Personal Access Token with required scopes (managed by backplane)

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌──────────────────┐
│   Backplane     │───▶│  Building Block │───▶│ Azure DevOps Org │
│                 │    │                 │    │                  │
│ • Service       │    │ • Project       │    │ • Project        │
│   Principal     │    │   Creation      │    │ • Users with     │
│ • Key Vault     │    │ • User          │    │   Stakeholder    │
│ • PAT Storage   │    │   Entitlements  │    │   licenses       │
│                 │    │ • Group         │    │ • Group          │
│                 │    │   Memberships   │    │   memberships    │
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
  
  # User management
  users = [
    {
      principal_name = "developer1@company.com"
      role          = "contributor"
      license_type  = "stakeholder"
    },
    {
      principal_name = "manager@company.com"  
      role          = "administrator"
      license_type  = "basic"
    },
    {
      principal_name = "viewer@company.com"
      role          = "reader"
      license_type  = "stakeholder"
    }
  ]
  
  # Optional: Disable certain features
  project_features = {
    testplans = "disabled"
    artifacts = "disabled"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `azure_devops_organization_url` | Azure DevOps organization URL | `string` | - | yes |
| `key_vault_name` | Key Vault name containing PAT | `string` | - | yes |
| `resource_group_name` | Resource group containing Key Vault | `string` | - | yes |
| `project_name` | Name of the Azure DevOps project | `string` | - | yes |
| `project_description` | Project description | `string` | `"Managed by Terraform"` | no |
| `project_visibility` | Project visibility (private/public) | `string` | `"private"` | no |
| `work_item_template` | Work item template | `string` | `"Agile"` | no |
| `version_control` | Version control system | `string` | `"Git"` | no |
| `users` | List of users with roles and licenses | `list(object)` | `[]` | no |
| `create_custom_groups` | Create custom project groups | `bool` | `true` | no |

## User Roles

- **reader**: Read-only access to project artifacts
- **contributor**: Can contribute code, work items, and builds
- **administrator**: Full project administration rights

## License Types

- **stakeholder**: Free license with limited access (recommended for most users)
- **basic**: Standard license with full development features
- **advanced**: Premium license with advanced testing and analytics

## Outputs

| Name | Description |
|------|-------------|
| `project_id` | ID of the created project |
| `project_url` | URL of the project |
| `user_entitlements` | Map of created user entitlements |
| `group_memberships` | Information about group memberships |
| `custom_groups` | Information about custom groups |

## Important Notes

- **User Creation**: This module cannot create new users. Users must exist in your identity provider.
- **License Assignment**: Requires appropriate organizational permissions.
- **PAT Requirements**: The Personal Access Token needs specific scopes (managed by backplane).
- **Group Management**: Uses built-in project groups plus optional custom groups.

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