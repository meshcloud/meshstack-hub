# Azure Subscription Budget Alert

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

## Permissions

This is a very simple building block, which means we let the SPN have access to deploy budget alerts
across all subscriptions underneath a management group (typically the top-level management group for landing zones).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_federated_identity_credential.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) | resource |
| [azuread_application_password.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_directory_role.directory_readers](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role) | resource |
| [azuread_directory_role_assignment.directory_readers_created](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role_assignment) | resource |
| [azuread_directory_role_assignment.directory_readers_existing](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role_assignment) | resource |
| [azuread_service_principal.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.created_principal](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.existing_principals](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_service_principal_name"></a> [create\_service\_principal\_name](#input\_create\_service\_principal\_name) | if set, creates a new service principal with the given name for deploying the building block | `string` | `null` | no |
| <a name="input_existing_principal_ids"></a> [existing\_principal\_ids](#input\_existing\_principal\_ids) | set of existing principal ids that will be granted permissions to deploy the building block | `set(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | name of the building block, used for naming resources | `string` | `"budget-alert"` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block should be deployable, typically the parent of all Landing Zones. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | if set, configures workload identity federation for the created service principal | <pre>object({<br>    issuer  = string<br>    subject = string<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_password"></a> [application\_password](#output\_application\_password) | Information about the created application password (excludes the actual password value for security). |
| <a name="output_created_application"></a> [created\_application](#output\_created\_application) | Information about the created Azure AD application. |
| <a name="output_created_service_principal"></a> [created\_service\_principal](#output\_created\_service\_principal) | Information about the created service principal. |
| <a name="output_documentation_md"></a> [documentation\_md](#output\_documentation\_md) | Markdown documentation with information about the Budget Alert building block backplane |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | The IDs of the role assignments for all service principals. |
| <a name="output_role_assignment_principal_ids"></a> [role\_assignment\_principal\_ids](#output\_role\_assignment\_principal\_ids) | The principal IDs of all service principals that have been assigned the role. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignments are applied. |
| <a name="output_workload_identity_federation"></a> [workload\_identity\_federation](#output\_workload\_identity\_federation) | Information about the created workload identity federation credential. |
<!-- END_TF_DOCS -->
