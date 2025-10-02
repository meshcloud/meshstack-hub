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
| `users` | List of users from authoritative system | `list(object)` | `[]` | no |

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



## Outputs

| Name | Description |
|------|-------------|
| `project_id` | ID of the created project |
| `project_url` | URL of the project |
| `user_assignments` | Map of users and their assigned roles |
| `group_memberships` | Information about group memberships |
| `project_features` | Enabled/disabled project features |

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