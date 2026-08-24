# Azure Service Principal Building Block — Backplane

This documentation is intended as a reference for platform engineers deploying the Service Principal Building Block backplane.

## Overview

The backplane provisions the automation identity and permissions required to deploy Azure AD service principals on behalf of application teams.

It creates:
- A custom Azure RBAC role definition with the minimum permissions required to deploy service principal building blocks
- Role assignments for the automation identity (service principal or existing principals)
- Microsoft Graph API application permission grant (`Application.ReadWrite.OwnedBy`) — requires admin consent in Azure AD

## Required Permissions

### Azure RBAC Role

The backplane creates a custom role definition and assigns it to the automation principal. The role grants permissions to manage Azure resources (e.g. resource group and role assignment operations) needed during building block deployment.

### Microsoft Graph API Permissions

The automation principal requires the following Microsoft Graph API application permission:

| Permission | Description |
|------------|-------------|
| `Application.ReadWrite.OwnedBy` | Allows the app to create other applications and service principals, and fully manage those applications (read, update, delete). It cannot update applications it does not own. |

> **Note:** `Application.ReadWrite.OwnedBy` requires admin consent in Azure AD before the backplane can function.

## Why this backplane is not yet a UAMI

[Azure backplane conventions](../../../../.agents/references/azure-backplane.md) require a
User-Assigned Managed Identity. This backplane still uses an app registration, and the scorecard's
Azure Backplane category reports that. The migration is understood but deliberately not done,
because for *this* building block it is not a drop-in replacement:

- The building block creates an Entra application per tenant and records the deploying identity as
  its **owner**. `Application.ReadWrite.OwnedBy` is scoped to owned applications, so replacing the
  deploy identity leaves every previously provisioned application owned by a principal that no
  longer exists. The new UAMI could neither read, update nor delete them: existing building block
  instances would become permanently stuck, and cleaning them up needs a Global Administrator
  walking the directory. Groups (as in `azure/entra-id-groups`) do not have this problem, because
  `Group.ReadWrite.All` is tenant-wide rather than ownership-scoped — which is why the UAMI
  convention transfers cleanly there but not here.
- A migration therefore needs an out-of-band, privileged step that adds the new UAMI as an owner of
  every existing application *before* the identity is switched over.
- It is also a breaking change to this module's inputs and outputs (`create_service_principal_name`,
  `existing_principal_ids`, the shape of `workload_identity_federation`, a new required `location`,
  and the `created_*` / `application_password*` / `provider_tf` outputs).
- One point is unverified and must be settled by an e2e run rather than by review: the building
  block resolves its own object ID via `data.azurerm_client_config.current.object_id` to set the
  application owner. Whether that resolves under a UAMI federated-credential login without an
  additional Microsoft Graph read grant is untested. If it does not, new applications would be
  created ownerless — the same failure mode, on new instances instead of old ones.

Until that migration is planned, `output "identity"` provides the normalised
`{ client_id, principal_id, tenant_id }` shape so consumers are not coupled to the principal type.

## Operational Notes

- The backplane must be deployed once per platform team before any building block instances can be created.
- Admin consent for the Graph API permission must be granted manually in the Azure portal or via the Azure CLI.
- The automation principal identity output (`identity`) is consumed by `meshstack_integration.tf` to wire the building block definition.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.6.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_app_role_assignment.msgraph_application_readwrite_ownedby](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/app_role_assignment) | resource |
| [azuread_app_role_assignment.msgraph_application_readwrite_ownedby_existing](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/app_role_assignment) | resource |
| [azuread_application.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_federated_identity_credential.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) | resource |
| [azuread_application_password.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_service_principal.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.created_principal](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.existing_principals](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azuread_service_principal.msgraph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) | data source |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_create_service_principal_name"></a> [create\_service\_principal\_name](#input\_create\_service\_principal\_name) | Name of a service principal to create and grant permissions to deploy the building block | `string` | `null` | no |
| <a name="input_existing_principal_ids"></a> [existing\_principal\_ids](#input\_existing\_principal\_ids) | Set of existing principal IDs that will be granted permissions to deploy the building block | `set(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the building block, used for naming resources | `string` | `"service-principal"` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block should be deployable (management group or subscription), typically the parent of all Landing Zones. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | Configuration for workload identity federation. If not provided, an application password will be created instead. | <pre>object({<br/>    issuer  = string<br/>    subject = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_application_password"></a> [application\_password](#output\_application\_password) | Information about the created application password (excludes the actual password value for security). |
| <a name="output_application_password_value"></a> [application\_password\_value](#output\_application\_password\_value) | The actual password value for the created application password. |
| <a name="output_created_application"></a> [created\_application](#output\_created\_application) | Information about the created Azure AD application. |
| <a name="output_created_service_principal"></a> [created\_service\_principal](#output\_created\_service\_principal) | Information about the created service principal. |
| <a name="output_identity"></a> [identity](#output\_identity) | Client, principal and tenant ID of the automation principal that deploys the building block. |
| <a name="output_provider_tf"></a> [provider\_tf](#output\_provider\_tf) | Ready-to-use provider.tf configuration for buildingblock deployment |
| <a name="output_role_assignment_ids"></a> [role\_assignment\_ids](#output\_role\_assignment\_ids) | The IDs of the role assignments for all service principals. |
| <a name="output_role_assignment_principal_ids"></a> [role\_assignment\_principal\_ids](#output\_role\_assignment\_principal\_ids) | The principal IDs of all service principals that have been assigned the role. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignments are applied. |
| <a name="output_tenant_id"></a> [tenant\_id](#output\_tenant\_id) | The tenant ID of the Azure subscription. |
| <a name="output_workload_identity_federation"></a> [workload\_identity\_federation](#output\_workload\_identity\_federation) | Information about the created workload identity federation credential. |
<!-- END_TF_DOCS -->
