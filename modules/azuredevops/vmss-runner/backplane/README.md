# Azure DevOps VMSS Runner - Backplane

This backplane module provisions the foundational Azure infrastructure required for managing Azure DevOps VMSS (Virtual Machine Scale Set) runners.

## Resources Created

- **Azure AD Service Principal**: Used for managing VMSS runners and agent pools
- **Azure Key Vault**: Stores sensitive credentials including:
  - Azure DevOps Personal Access Token (PAT)
  - Service Principal client secret

## Prerequisites

- Azure subscription with appropriate permissions to create:
  - Service principals
  - Key Vaults
  - Resource groups
- Azure DevOps Personal Access Token with permissions:
  - Agent Pools (Read & Manage)
  - Deployment Groups (Read & Manage)

## Required Inputs

| Variable | Description | Type | Required |
|----------|-------------|------|----------|
| `service_principal_name` | Name of the service principal | string | Yes |
| `key_vault_name` | Name of the Azure Key Vault | string | Yes |
| `location` | Azure region for resources | string | Yes |
| `resource_group_name` | Resource group name | string | Yes |
| `azuredevops_pat` | Azure DevOps PAT | string (sensitive) | Yes |
| `azuredevops_pat_secret_name` | Secret name in Key Vault | string | No (default: "azuredevops-pat") |

## Outputs

- `service_principal_client_id`: Client ID for authentication
- `service_principal_object_id`: Object ID for role assignments
- `service_principal_client_secret`: Client secret (sensitive)
- `key_vault_id`: Key Vault resource ID
- `key_vault_name`: Key Vault name
- `azuredevops_pat_secret_name`: PAT secret name

## Usage

```hcl
module "vmss_runner_backplane" {
  source = "./backplane"

  service_principal_name = "vmss-runner-sp"
  key_vault_name         = "vmss-runner-kv"
  location               = "eastus"
  resource_group_name    = "vmss-runner-rg"
  azuredevops_pat        = var.azuredevops_pat
}
```

## Security Considerations

- Key Vault has purge protection enabled
- Service principal has minimal permissions (read-only on Key Vault secrets)
- PAT and client secret are stored securely in Key Vault
- All sensitive outputs are marked as sensitive

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.53.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.vmss_runner](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_service_principal.vmss_runner](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azuread_service_principal_password.vmss_runner](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal_password) | resource |
| [azurerm_key_vault.vmss_runner](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_secret.azuredevops_pat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.service_principal_client_secret](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azuredevops_pat"></a> [azuredevops\_pat](#input\_azuredevops\_pat) | Azure DevOps Personal Access Token for agent registration | `string` | n/a | yes |
| <a name="input_azuredevops_pat_secret_name"></a> [azuredevops\_pat\_secret\_name](#input\_azuredevops\_pat\_secret\_name) | Name of the secret in Key Vault for storing the Azure DevOps PAT | `string` | `"azuredevops-pat"` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Azure Key Vault for storing secrets | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region for the Key Vault | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group for the Key Vault | `string` | n/a | yes |
| <a name="input_service_principal_name"></a> [service\_principal\_name](#input\_service\_principal\_name) | Name of the service principal for VMSS runner management | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azuredevops_pat_secret_name"></a> [azuredevops\_pat\_secret\_name](#output\_azuredevops\_pat\_secret\_name) | Name of the Azure DevOps PAT secret in Key Vault |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | ID of the Key Vault storing VMSS runner secrets |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Name of the Key Vault storing VMSS runner secrets |
| <a name="output_service_principal_client_id"></a> [service\_principal\_client\_id](#output\_service\_principal\_client\_id) | Client ID of the service principal for VMSS runner management |
| <a name="output_service_principal_client_secret"></a> [service\_principal\_client\_secret](#output\_service\_principal\_client\_secret) | Client secret of the service principal for VMSS runner management |
| <a name="output_service_principal_object_id"></a> [service\_principal\_object\_id](#output\_service\_principal\_object\_id) | Object ID of the service principal for VMSS runner management |
<!-- END_TF_DOCS -->