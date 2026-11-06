# Azure Subscription Azure Storage Account

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

## Permissions

This backplane creates a user-assigned managed identity and gives it a role that manages storage
accounts at `scope`, typically the top-level management group for landing zones. The identity has
one federated identity credential per entry in `workload_identity_federations`, so it holds no
secret.

## Usage

```hcl
module "storage_account_backplane" {
  source = "git::https://github.com/meshcloud/meshstack-hub.git//modules/azure/storage-account/backplane"

  name     = "my-storage-account"
  scope    = "/providers/Microsoft.Management/managementGroups/my-mg"
  location = "westeurope"

  # See .agents/references/meshstack-integration.md#runner-identity for how the integration wires this.
  workload_identity_federations = [{
    issuer   = "https://your-oidc-issuer"
    audience = "api://AzureADTokenExchange"
    subject  = "system:serviceaccount:your-namespace:your-service-account-name"
  }]
}
```

## Migrating from `workload_identity_federation`

Earlier revisions took one `workload_identity_federation` object with an `issuer` and a `subjects`
list, and gave every credential the audience `api://AzureADTokenExchange`. Pass one entry per
subject in `workload_identity_federations`, with that subject as `subject` and
`api://AzureADTokenExchange` as `audience`. The credentials keep their names and values, so the
plan is empty.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.65.0, < 5.0.0 |

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
| <a name="input_workload_identity_federations"></a> [workload\_identity\_federations](#input\_workload\_identity\_federations) | meshStack identities the automation identity trusts, one per building block runner. For more<br/>subjects of one issuer, pass one entry per subject. | <pre>list(object({<br/>    issuer   = string<br/>    audience = string<br/>    subject  = string<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_identity"></a> [identity](#output\_identity) | The managed identity used as the automation principal for this building block. |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | The ID of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_role_definition_name"></a> [role\_definition\_name](#output\_role\_definition\_name) | The name of the role definition that enables deployment of the building block to subscriptions. |
| <a name="output_scope"></a> [scope](#output\_scope) | The scope where the role definition and role assignment are applied. |
<!-- END_TF_DOCS -->
