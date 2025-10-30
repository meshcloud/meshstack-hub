# Azure DevOps Service Connection (Subscription) Backplane

This module provisions the infrastructure required to support the Azure DevOps Service Connection (Subscription) building block.

## What It Provisions

- **Azure AD Service Principal**: For service connection management automation
- **Azure Key Vault**: Stores Azure DevOps Personal Access Token (PAT)
- **Custom Role Definition**: Minimal permissions for reading Key Vault secrets
- **Role Assignment**: Grants the service principal access to Key Vault
- **Federated Identity Credential** (optional): For workload identity federation (OIDC) authentication

## Prerequisites

- Azure subscription with permissions to create:
  - Azure AD applications and service principals
  - Key Vault instances
  - Custom role definitions and assignments
- Azure DevOps organization with Administrator access
- Azure DevOps PAT with `Service Connections (Read, Query & Manage)` scope

## Usage

### Basic Backplane (Service Principal Authentication)

```hcl
module "azuredevops_service_connection_backplane" {
  source = "./backplane"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  service_principal_name        = "azuredevops-serviceconn-terraform"
  key_vault_name                = "kv-azdo-sc-prod"
  resource_group_name           = "rg-azdo-sc-prod"
  location                      = "West Europe"
  scope                         = "/subscriptions/00000000-0000-0000-0000-000000000000"
}
```

### Backplane with Workload Identity Federation

```hcl
module "azuredevops_service_connection_backplane" {
  source = "./backplane"

  azure_devops_organization_url      = "https://dev.azure.com/myorg"
  service_principal_name             = "azuredevops-serviceconn-terraform"
  key_vault_name                     = "kv-azdo-sc-prod"
  resource_group_name                = "rg-azdo-sc-prod"
  location                           = "West Europe"
  scope                              = "/subscriptions/00000000-0000-0000-0000-000000000000"
  enable_workload_identity_federation = true
  azure_devops_organization_id       = "33333333-3333-3333-3333-333333333333"
  azure_devops_project_name          = "MyProject"
  service_connection_name            = "Azure-Production-Federated"
}
```

## Post-Deployment Steps

1. Create an Azure DevOps PAT with `Service Connections (Read, Query & Manage)` scope
2. Store the PAT in the provisioned Key Vault:
   ```bash
   az keyvault secret set --vault-name <key_vault_name> --name azdo-pat --value <your_pat>
   ```

## Workload Identity Federation

When `enable_workload_identity_federation = true`, this module configures:
- **Issuer**: `https://vstoken.dev.azure.com/{organization_id}`
- **Subject**: `sc://{org_url}/{project}/{connection_name}`
- **Audience**: `api://AzureADTokenExchange`

This eliminates the need for client secrets by using OIDC token exchange.

## Outputs

- `service_principal_client_id` - For authentication
- `key_vault_name` - Where to store the PAT
- `key_vault_uri` - For programmatic access
- `azure_devops_organization_url` - Organization URL passed through
- `workload_identity_federation_enabled` - Whether federation is enabled
- `federated_credential_issuer` - Issuer URL for federation
- `federated_credential_subject` - Subject identifier for federation

## Security Considerations

- Service principal has read-only access to Key Vault secrets
- PAT should be rotated regularly (recommended: every 90 days)
- Use separate backplane instances for different environments
- Service connections will create their own service principals for Azure access

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