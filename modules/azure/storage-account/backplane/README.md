# Azure Subscription Azure Storage Account

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

## Permissions

This is a very simple building block, which means we let the service principals have access to the Storage Account
across all subscriptions underneath a management group (typically the top-level management group for landing zones).

The module supports two modes of operation:

1. **Existing Service Principals**: Use `existing_principal_ids` to grant permissions to already existing service principals
2. **Create New Service Principal**: Use `create_service_principal_name` to create a single new service principal and automatically grant it permissions

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
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.5.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 3.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_service_principal.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/3.116.0/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/3.116.0/docs/resources/role_definition) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_service_principal_name"></a> [create\_service\_principal\_name](#input\_create\_service\_principal\_name) | name of a service principal to create and grant permissions to deploy the building block | `string` | `null` | no |
| <a name="input_existing_principal_ids"></a> [existing\_principal\_ids](#input\_existing\_principal\_ids) | set of existing principal ids that will be granted permissions to deploy the building block | `set(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | name of the building block, used for naming resources | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block should be deployable, typically the parent of all Landing Zones. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_created_application"></a> [created\_application](#output\_created\_application) | Information about the created Azure AD application. |
| <a name="output_created_service_principal"></a> [created\_service\_principal](#output\_created\_service\_principal) | Information about the created service principal. |
| <a name="output_documentation_md"></a> [documentation\_md](#output\_documentation\_md) | Markdown documentation with information about the Storage Account Building Block building block backplane |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | The IDs of the role assignments for all service principals. |
| <a name="output_role_assignment_principal_ids"></a> [role\_assignment\_principal\_ids](#output\_role\_assignment\_principal\_ids) | The principal IDs of all service principals that have been assigned the role. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignments are applied. |
<!-- END_TF_DOCS -->
