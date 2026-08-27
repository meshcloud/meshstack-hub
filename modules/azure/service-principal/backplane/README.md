# Azure Service Principal Building Block — Backplane

This documentation is intended as a reference for platform engineers deploying the Service Principal Building Block backplane.

## Overview

The backplane provisions the automation identity and permissions required to deploy Azure AD service principals on behalf of application teams.

It creates:
- A resource group and a **User-Assigned Managed Identity** (UAMI) that the building block runs as
- A federated identity credential per meshStack replicator subject, so the identity authenticates by workload identity federation and holds no secret
- A custom Azure RBAC role definition with the minimum permissions required to deploy service principal building blocks, assigned to the UAMI
- A Microsoft Graph app role grant (`Application.ReadWrite.OwnedBy`) on the UAMI — requires admin consent in Azure AD

## Required Permissions

### Azure RBAC Role

The backplane creates a custom role definition and assigns it to the UAMI. The role grants the role-definition and role-assignment permissions the building block needs when it attaches a built-in or custom role to the service principal it creates.

### Microsoft Graph API Permissions

The automation principal requires the following Microsoft Graph API application permission:

| Permission | Description |
|------------|-------------|
| `Application.ReadWrite.OwnedBy` | Allows the identity to create applications and service principals, and to fully manage those it owns (read, update, delete). It cannot update applications it does not own. |

> **Note:** `Application.ReadWrite.OwnedBy` requires admin consent in Azure AD before the backplane can function.

## Application ownership

The building block records this UAMI as the **owner** of every application it creates, because
`Application.ReadWrite.OwnedBy` is ownership-scoped: an application with no owner, or one owned by a
principal that no longer exists, can no longer be read, updated or deleted by the building block —
cleaning it up then needs a Global Administrator walking the directory.

Two consequences follow:

- **The backplane must outlive the building block instances it deployed.** Destroy the instances
  first, then the backplane. The `e2e/` test enforces this ordering with an explicit `depends_on`.
- **Replacing the identity is a migration, not an edit.** Anything that recreates the UAMI (renaming
  it, moving it to another resource group or subscription) orphans every application already
  provisioned through it. If you have to do it, add the new identity as an owner of the existing
  applications *before* switching over.

## Operational Notes

- The backplane must be deployed once per platform team before any building block instances can be created.
- Admin consent for the Graph API permission must be granted manually in the Azure portal or via the Azure CLI.
- The `identity` output is consumed by `meshstack_integration.tf` to wire `ARM_CLIENT_ID` on the building block definition.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | >= 3.6.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_app_role_assignment.msgraph_application_readwrite_ownedby](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/app_role_assignment) | resource |
| [azurerm_federated_identity_credential.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_resource_group.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_user_assigned_identity.buildingblock_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azuread_service_principal.msgraph](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/service_principal) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | Azure region for the backplane resource group and managed identity. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the building block, used for naming the resource group, the managed identity and the role definition. | `string` | `"service-principal"` | no |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the building block should be deployable (management group or subscription), typically the parent of all Landing Zones. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer and subjects for federated authentication from the meshStack replicator. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | UAMI identity attributes consumed by meshstack\_integration.tf as static inputs. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignment are applied. |
| <a name="output_tenant_id"></a> [tenant\_id](#output\_tenant\_id) | The tenant ID of the Azure subscription. |
<!-- END_TF_DOCS -->
