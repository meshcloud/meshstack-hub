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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_btp"></a> [btp](#requirement\_btp) | ~> 1.8.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [btp_subaccount.subaccount](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_admin](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_service_admininstrator](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_subaccount_role_collection_assignment.subaccount_viewer](https://registry.terraform.io/providers/SAP/btp/latest/docs/resources/subaccount_role_collection_assignment) | resource |
| [btp_directories.all](https://registry.terraform.io/providers/SAP/btp/latest/docs/data-sources/directories) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_globalaccount"></a> [globalaccount](#input\_globalaccount) | The subdomain of the global account in which you want to manage resources. | `string` | n/a | yes |
| <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id) | The parent directory ID for the subaccount. Use this when importing existing subaccounts. Mutually exclusive with subfolder. | `string` | `""` | no |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | The meshStack project identifier. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The region of the subaccount. | `string` | `"eu10"` | no |
| <a name="input_subfolder"></a> [subfolder](#input\_subfolder) | The subfolder name to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit. Mutually exclusive with parent\_id. | `string` | `""` | no |
| <a name="input_users"></a> [users](#input\_users) | Users and their roles provided by meshStack | <pre>list(object(<br>    {<br>      meshIdentifier = string<br>      username       = string<br>      firstName      = string<br>      lastName       = string<br>      email          = string<br>      euid           = string<br>      roles          = list(string)<br>    }<br>  ))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_subaccount_id"></a> [subaccount\_id](#output\_subaccount\_id) | The ID of the created subaccount |
| <a name="output_subaccount_login_link"></a> [subaccount\_login\_link](#output\_subaccount\_login\_link) | Link to the subaccount in the SAP BTP cockpit |
| <a name="output_subaccount_name"></a> [subaccount\_name](#output\_subaccount\_name) | The name of the subaccount |
| <a name="output_subaccount_region"></a> [subaccount\_region](#output\_subaccount\_region) | The region of the subaccount |
| <a name="output_subaccount_subdomain"></a> [subaccount\_subdomain](#output\_subaccount\_subdomain) | The subdomain of the subaccount |
<!-- END_TF_DOCS -->