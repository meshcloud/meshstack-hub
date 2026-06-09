# Azure Subscription Azure Storage Account

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

## Permissions

This is a very simple building block, which means we let the service principals have access to the Storage Account
across all subscriptions underneath a management group (typically the top-level management group for landing zones).

The module supports two modes of operation:

1. **Existing Service Principals**: Use `existing_principal_ids` to grant permissions to already existing service principals
2. **Create New Service Principal**: Use `create_service_principal_name` to create a single new service principal and automatically grant it permissions

## Authentication Methods

When creating a new service principal, you can choose between two authentication methods:

- **Application Password** (default): A traditional client secret will be created
- **Workload Identity Federation**: Configure federated identity credentials for passwordless authentication (e.g., from GitHub Actions, Azure DevOps, or other OIDC providers)

## Usage Examples

### Using Existing Service Principals

```hcl
module "storage_account_backplane" {
  source = "./modules/azure/storage-account/backplane"

  name  = "my-storage-account"
  scope = "/providers/Microsoft.Management/managementGroups/my-mg"

  existing_principal_ids = [
    "12345678-1234-1234-1234-123456789012",
    "87654321-4321-4321-4321-210987654321"
  ]
}
```

### Creating a New Service Principal

```hcl
module "storage_account_backplane" {
  source = "./modules/azure/storage-account/backplane"

  name  = "my-storage-account"
  scope = "/providers/Microsoft.Management/managementGroups/my-mg"

  create_service_principal_name = "deployment-sp"
}
```

### Creating a New Service Principal with Workload Identity Federation

```hcl
module "storage_account_backplane" {
  source = "./modules/azure/storage-account/backplane"

  name  = "my-storage-account"
  scope = "/providers/Microsoft.Management/managementGroups/my-mg"

  create_service_principal_name = "deployment-sp"
  workload_identity_federation = {
    issuer = "https://token.actions.githubusercontent.com"
    subjects = [
      "repo:my-org/my-repo:ref:refs/heads/main",
      "repo:my-org/my-repo:environment:production",
    ]
  }
}
```

### Subject Matching

**Only exact matching is supported for subjects.** Each subject in the `subjects` list will create a separate federated identity credential.

When using Kubernetes service accounts, provide the full subject identifier:
```hcl
workload_identity_federation = {
  issuer = "https://your-oidc-issuer"
  subjects = [
    "system:serviceaccount:namespace1:service-account-1",
    "system:serviceaccount:namespace1:service-account-2",
  ]
}
```

### Mixed Usage (Both Existing and New)

```hcl
module "storage_account_backplane" {
  source = "./modules/azure/storage-account/backplane"

  name  = "my-storage-account"
  scope = "/providers/Microsoft.Management/managementGroups/my-mg"

  existing_principal_ids = [
    "12345678-1234-1234-1234-123456789012"
  ]

  create_service_principal_name = "new-deployment-sp"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.64 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_resource_group.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_user_assigned_identity.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | Azure region for the UAMI resource. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the building block identity and role definition. | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope for role assignment (management group or subscription ID). | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer and subjects for federated authentication. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | The managed identity used as the automation principal for this building block. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignment are applied. |
<!-- END_TF_DOCS -->
