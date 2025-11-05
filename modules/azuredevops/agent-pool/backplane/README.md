# Azure DevOps Agent Pool Backplane

This backplane provides the necessary Azure infrastructure and permissions for managing Azure DevOps agent pools with elastic scaling.

## Components

- **Service Principal**: Azure AD application for Azure DevOps management
- **Key Vault**: Secure storage for Azure DevOps Personal Access Token (PAT)
- **Custom Role**: Role definition with permissions to read VMSS and Key Vault secrets
- **Role Assignment**: Assigns the custom role to the service principal

## Prerequisites

Before deploying this backplane:

1. Azure subscription with permissions to create:
   - Service principals
   - Key Vaults
   - Custom role definitions
   - Role assignments

2. Azure DevOps Personal Access Token with scopes:
   - Agent Pools (Read & Manage)
   - Project & Team (Read, optional for project authorization)

## Usage

```hcl
module "agent_pool_backplane" {
  source = "path/to/azuredevops/agent-pool/backplane"

  service_principal_name = "sp-azure-devops-agent-pool"
  key_vault_name        = "kv-azdevops-terraform"
  resource_group_name   = "rg-azdevops-terraform"
  location              = "westeurope"
  scope                 = "/subscriptions/12345678-1234-1234-1234-123456789012"
}
```

## Manual Steps After Deployment

After the backplane is deployed, you must manually:

1. **Store the PAT in Key Vault**:
```bash
az keyvault secret set \
  --vault-name kv-azdevops-terraform \
  --name azure-devops-pat \
  --value "YOUR_PAT_TOKEN_HERE"
```

2. **Create Service Principal Secret** (if using client credentials):
```bash
az ad app credential reset \
  --id <service-principal-client-id> \
  --append
```

## Permissions Granted

The custom role grants the service principal:

- `Microsoft.KeyVault/vaults/secrets/read` - Read PAT from Key Vault
- `Microsoft.Resources/subscriptions/resourceGroups/read` - List resource groups
- `Microsoft.Compute/virtualMachineScaleSets/read` - Read VMSS information

## Security Considerations

- **PAT Rotation**: Rotate the PAT every 90 days minimum
- **Least Privilege**: Service principal only has read access to VMSS
- **Key Vault Access**: Limited to specific service principal and admin
- **Scope**: Apply role at subscription or resource group level

## Outputs

- `service_principal_id`: Client ID for authentication
- `service_principal_object_id`: Object ID for role assignments
- `key_vault_name`: Key Vault name for PAT storage
- `resource_group_name`: Resource group containing Key Vault
- `role_definition_id`: Custom role definition ID

## Troubleshooting

### Service Principal Creation Failed

**Cause**: Insufficient Azure AD permissions

**Solution**: Ensure you have Application Administrator or Global Administrator role in Azure AD

### Key Vault Access Denied

**Cause**: Service principal lacks access policy

**Solution**: Verify access policy in Key Vault grants Get and List permissions on secrets

### Role Assignment Failed

**Cause**: Insufficient permissions at target scope

**Solution**: Ensure you have Owner or User Access Administrator role at the specified scope

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.51.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.azure_devops](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_service_principal.azure_devops](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_key_vault.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_resource_group.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.azure_devops_manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.azure_devops_agent_pool_manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault to store Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region for resources | `string` | `"westeurope"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group for Key Vault | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Scope for the custom role definition (e.g., subscription ID) | `string` | n/a | yes |
| <a name="input_service_principal_name"></a> [service\_principal\_name](#input\_service\_principal\_name) | Name of the service principal for Azure DevOps agent pool management | `string` | `"sp-azure-devops-agent-pool"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | ID of the Key Vault |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Name of the Key Vault |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the resource group |
| <a name="output_role_definition_id"></a> [role\_definition\_id](#output\_role\_definition\_id) | ID of the custom role definition |
| <a name="output_service_principal_id"></a> [service\_principal\_id](#output\_service\_principal\_id) | Application (client) ID of the service principal |
| <a name="output_service_principal_object_id"></a> [service\_principal\_object\_id](#output\_service\_principal\_object\_id) | Object ID of the service principal |
<!-- END_TF_DOCS -->