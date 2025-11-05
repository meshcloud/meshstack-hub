# Azure Subscription Azure Key Vault

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

## Permissions

This is a very simple building block, which means we let the SPN have access to Key Vault
across all subscriptions underneath a management group (typically the top-level management group for landing zones).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.6.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application.buildingblock_deploy_hub](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_federated_identity_credential.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) | resource |
| [azuread_application_federated_identity_credential.buildingblock_deploy_hub](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) | resource |
| [azuread_application_password.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_application_password.buildingblock_deploy_hub](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_directory_role.directory_readers](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role) | resource |
| [azuread_directory_role_assignment.directory_readers_created](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role_assignment) | resource |
| [azuread_directory_role_assignment.directory_readers_existing](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/directory_role_assignment) | resource |
| [azuread_service_principal.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azuread_service_principal.buildingblock_deploy_hub](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.created_principal](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.created_principal_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.created_principal_hub_to_landingzone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.created_principal_landingzone_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.existing_principals](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.existing_principals_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.existing_principals_hub_to_landingzone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.existing_principals_landingzone_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.buildingblock_deploy_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.buildingblock_hub_to_landingzone](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.buildingblock_landingzone_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_hub_service_principal_name"></a> [create\_hub\_service\_principal\_name](#input\_create\_hub\_service\_principal\_name) | name of a separate service principal to create for hub VNet peering (least privilege) | `string` | `null` | no |
| <a name="input_create_service_principal_name"></a> [create\_service\_principal\_name](#input\_create\_service\_principal\_name) | name of a service principal to create and grant permissions to deploy the building block | `string` | `null` | no |
| <a name="input_existing_hub_principal_ids"></a> [existing\_hub\_principal\_ids](#input\_existing\_hub\_principal\_ids) | set of existing principal ids that will be granted permissions to peer with the hub VNet | `set(string)` | `[]` | no |
| <a name="input_existing_principal_ids"></a> [existing\_principal\_ids](#input\_existing\_principal\_ids) | set of existing principal ids that will be granted permissions to deploy the building block | `set(string)` | `[]` | no |
| <a name="input_hub_scope"></a> [hub\_scope](#input\_hub\_scope) | Scope for hub VNet peering permissions (management group or subscription). Typically a hub subscription, but can be a management group containing hub resources. | `string` | n/a | yes |
| <a name="input_hub_workload_identity_federation"></a> [hub\_workload\_identity\_federation](#input\_hub\_workload\_identity\_federation) | Configuration for workload identity federation for hub service principal. If not provided, an application password will be created instead. | <pre>object({<br>    issuer  = string<br>    subject = string<br>  })</pre> | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | name of the building block, used for naming resources | `string` | `"key-vault"` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block should be deployable (management group or subscription), typically the parent of all Landing Zones. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Configuration for workload identity federation. If not provided, an application password will be created instead. | <pre>object({<br>    issuer  = string<br>    subject = string<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_password"></a> [application\_password](#output\_application\_password) | Information about the created application password (excludes the actual password value for security). |
| <a name="output_created_application"></a> [created\_application](#output\_created\_application) | Information about the created Azure AD application. |
| <a name="output_created_hub_application"></a> [created\_hub\_application](#output\_created\_hub\_application) | Information about the created hub Azure AD application. |
| <a name="output_created_hub_service_principal"></a> [created\_hub\_service\_principal](#output\_created\_hub\_service\_principal) | Information about the created hub service principal. |
| <a name="output_created_service_principal"></a> [created\_service\_principal](#output\_created\_service\_principal) | Information about the created service principal. |
| <a name="output_documentation_md"></a> [documentation\_md](#output\_documentation\_md) | Markdown documentation with information about the Key Vault Building Block building block backplane |
| <a name="output_hub_application_password"></a> [hub\_application\_password](#output\_hub\_application\_password) | Information about the created hub application password (excludes the actual password value for security). |
| <a name="output_hub_role_assignment_ids"></a> [hub\_role\_assignment\_ids](#output\_hub\_role\_assignment\_ids) | The IDs of the hub role assignments for all service principals. |
| <a name="output_hub_role_assignment_principal_ids"></a> [hub\_role\_assignment\_principal\_ids](#output\_hub\_role\_assignment\_principal\_ids) | The principal IDs of all service principals that have been assigned the hub role. |
| <a name="output_hub_role_definition_id"></a> [hub\_role\_definition\_id](#output\_hub\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to the hub. |
| <a name="output_hub_role_definition_name"></a> [hub\_role\_definition\_name](#output\_hub\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to the hub. |
| <a name="output_hub_scope"></a> [hub\_scope](#output\_hub\_scope) | The scope (management group or subscription) where VNet peering role is applied. |
| <a name="output_hub_workload_identity_federation"></a> [hub\_workload\_identity\_federation](#output\_hub\_workload\_identity\_federation) | Information about the created hub workload identity federation credential. |
| <a name="output_provider_tf"></a> [provider\_tf](#output\_provider\_tf) | Ready-to-use provider.tf configuration for buildingblock deployment |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | The IDs of the role assignments for all service principals. |
| <a name="output_role_assignment_principal_ids"></a> [role\_assignment\_principal\_ids](#output\_role\_assignment\_principal\_ids) | The principal IDs of all service principals that have been assigned the role. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignments are applied. |
| <a name="output_workload_identity_federation"></a> [workload\_identity\_federation](#output\_workload\_identity\_federation) | Information about the created workload identity federation credential. |
<!-- END_TF_DOCS -->
