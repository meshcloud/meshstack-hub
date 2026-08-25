# Azure Spoke Network — Backplane

This documentation is intended as reference documentation for platform engineers deploying this backplane.

## What this backplane provisions

The spoke network building block is special: it peers a newly created spoke vnet into a central
network hub, and a vnet peering must be created on **both** sides of the connection. The automation
identity therefore needs permissions in two places:

- the **landing zone scope** (`var.scope`), where the spoke resource group, vnet and the spoke side
  of the peering are created, and
- the **hub scope** (`var.hub_scope`), where the hub vnet lives and the hub side of the peering is created.

This backplane creates a single **User-Assigned Managed Identity (UAMI)** as the automation principal
and grants it two custom role definitions:

| Role definition        | Scope           | Purpose                                                                 |
| ---------------------- | --------------- | ---------------------------------------------------------------------- |
| `<name>-deploy`        | `var.scope`     | Manage the spoke resource group + vnet, hand ownership to the tenant, create the spoke side of the peering. |
| `<name>-deploy-hub`    | `var.hub_scope` | Read the hub vnet/resource group and create the hub side of the peering. |

Because a single identity holds `Microsoft.Network/virtualNetworks/peer/action` at **both** scopes,
the cross-scope `LinkedAuthorizationFailed` error that a split spoke/hub identity would hit when
creating the linked peering is avoided.

The UAMI authenticates via **workload identity federation** (no secrets to rotate), federated against
the meshStack replicator subject(s) passed in `var.workload_identity_federation`.

## Operational notes

- `var.scope` is typically the management group that parents all landing zones; `var.hub_scope` is
  typically the hub subscription (or a management group containing it).
- The identity is granted `Microsoft.Authorization/roleAssignments/*` at the spoke scope because the
  building block hands ownership of the spoke resource group to the tenant. Consider confining the
  identity to the connectivity resource group with an Azure Policy if you need a tighter boundary.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential) | resource |
| [azurerm_resource_group.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.backplane_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_role_definition.backplane_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_user_assigned_identity.backplane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_hub_scope"></a> [hub\_scope](#input\_hub\_scope) | Scope where the hub vnet lives (management group or subscription ID). The identity is granted vnet peering permissions here so it can peer the spoke into the hub. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the UAMI resource group. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name for the building block identity, resource group and role definitions. | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope where the spoke network can be deployed (management group or subscription ID), typically the parent of all landing zones. | `string` | n/a | yes |
| <a name="input_workload_identity_federation"></a> [workload\_identity\_federation](#input\_workload\_identity\_federation) | WIF issuer and subjects for federated authentication of the automation identity. | <pre>object({<br/>    issuer   = string<br/>    subjects = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_hub_role_definition_id"></a> [hub\_role\_definition\_id](#output\_hub\_role\_definition\_id) | The ID of the role definition that enables peering the spoke into the hub vnet. |
| <a name="output_hub_role_definition_name"></a> [hub\_role\_definition\_name](#output\_hub\_role\_definition\_name) | The name of the role definition that enables peering the spoke into the hub vnet. |
| <a name="output_hub_scope"></a> [hub\_scope](#output\_hub\_scope) | The scope where the hub peering role definition and role assignment are applied. |
| <a name="output_identity"></a> [identity](#output\_identity) | The managed identity used as the automation principal for this building block. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the spoke network to landing zone subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the spoke network to landing zone subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the spoke deploy role definition and role assignment are applied. |
<!-- END_TF_DOCS -->
