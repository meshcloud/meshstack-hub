# Azure DevOps Project Backplane

This backplane module provisions the necessary Azure infrastructure and permissions for managing Azure DevOps projects through Terraform.

> **Platform Separation**: Azure DevOps is treated as a dedicated DevOps platform, separate from Azure cloud infrastructure, following the same pattern as GitHub, SAP BTP, and other platforms.

## Architecture

The backplane creates:

1. **Azure AD Service Principal** - For Azure DevOps API authentication
2. **Azure Key Vault** - Secure storage for Azure DevOps Personal Access Token (PAT)
3. **Custom Role Definition** - Minimal permissions for Key Vault access
4. **Role Assignment** - Grants the service principal access to retrieve the PAT

## Prerequisites

- Azure DevOps organization with appropriate permissions
- Personal Access Token (PAT) with the following scopes:
  - **Project & Team**: Read, Write, & Manage
  - **Member Entitlement Management**: Read & Write
  - **Work Items**: Read

## Setup Steps

1. Deploy this backplane module
2. Create a Personal Access Token in your Azure DevOps organization
3. Store the PAT in the created Key Vault as a secret named `azure-devops-pat`

```bash
# Store PAT in Key Vault
az keyvault secret set \
  --vault-name <key-vault-name> \
  --name "azure-devops-pat" \
  --value "<your-pat-token>"
```

## Usage

```hcl
module "azure_devops_backplane" {
  source = "path/to/azuredevops/project/backplane"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  service_principal_name        = "azure-devops-terraform"
  key_vault_name               = "kv-azdevops-terraform"
  resource_group_name          = "rg-azdevops-terraform"
  location                     = "West Europe"
  scope                        = "/subscriptions/12345678-1234-1234-1234-123456789012"
}
```

## Security Considerations

- The service principal has minimal permissions (Key Vault read-only)
- PAT tokens should be rotated regularly
- Key Vault access is restricted to necessary principals only
- All secrets are stored securely in Key Vault

## Required Azure DevOps Permissions

To create the PAT token, you need:
- Organization-level **Project Collection Administrators** permissions
- Or **Project Administrator** permissions for specific projects
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.53.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |

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
| [azurerm_role_definition.azure_devops_manager](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_definition) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#input\_azure\_devops\_organization\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault to store the Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | Azure region for resources | `string` | `"West Europe"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group name for the Key Vault | `string` | n/a | yes |
| <a name="input_scope"></a> [scope](#input\_scope) | Azure scope for role definitions (subscription or management group) | `string` | n/a | yes |
| <a name="input_service_principal_name"></a> [service\_principal\_name](#input\_service\_principal\_name) | Name for the Azure DevOps service principal | `string` | `"azure-devops-terraform"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#output\_azure\_devops\_organization\_url) | Azure DevOps organization URL |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | ID of the Key Vault for storing Azure DevOps PAT |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Name of the Key Vault for storing Azure DevOps PAT |
| <a name="output_key_vault_uri"></a> [key\_vault\_uri](#output\_key\_vault\_uri) | URI of the Key Vault for storing Azure DevOps PAT |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Name of the resource group containing the Key Vault |
| <a name="output_service_principal_client_id"></a> [service\_principal\_client\_id](#output\_service\_principal\_client\_id) | Client ID of the Azure DevOps service principal |
| <a name="output_service_principal_object_id"></a> [service\_principal\_object\_id](#output\_service\_principal\_object\_id) | Object ID of the Azure DevOps service principal |
<!-- END_TF_DOCS -->