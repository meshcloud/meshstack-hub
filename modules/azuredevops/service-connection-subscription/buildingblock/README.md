---
name: Azure DevOps Service Connection (Subscription)
supportedPlatforms:
  - azuredevops
description: Provides an Azure subscription service connection in Azure DevOps for pipeline integration with Azure subscriptions
category: devops
---

# Azure DevOps Service Connection (Subscription) Building Block

Creates and manages Azure subscription service connections in Azure DevOps projects, enabling pipelines to deploy and manage resources in Azure subscriptions.

## Prerequisites

- Deployed Azure DevOps Service Connection (Subscription) backplane
- Azure DevOps project ID where the service connection will be created
- Azure subscription ID to connect to
- Azure DevOps PAT stored in Key Vault with `Service Connections (Read, Query & Manage)` scope
- Existing Azure AD service principal with appropriate permissions on the target subscription
- Service principal with federated identity credential configured for Azure DevOps

## Features

- Configures Azure DevOps service connection using workload identity federation (OIDC)
- No client secrets required - uses secure token-based authentication
- Optional automatic authorization for all pipelines
- Enhanced security through short-lived tokens

## Usage

### Basic Service Connection

```hcl
module "azuredevops_service_connection" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-sc-prod"
  resource_group_name           = "rg-azdo-sc-prod"
  pat_secret_name               = "azdo-pat"

  project_id              = "12345678-1234-1234-1234-123456789012"
  service_connection_name = "Azure-Production"
  azure_subscription_id   = "87654321-4321-4321-4321-210987654321"
  service_principal_id    = "11111111-1111-1111-1111-111111111111"
  azure_tenant_id         = "22222222-2222-2222-2222-222222222222"
}
```

### Service Connection with Auto-Authorization

```hcl
module "authorized_service_connection" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-sc-prod"
  resource_group_name           = "rg-azdo-sc-prod"

  project_id              = "12345678-1234-1234-1234-123456789012"
  service_connection_name = "Azure-Dev"
  azure_subscription_id   = "87654321-4321-4321-4321-210987654321"
  service_principal_id    = "11111111-1111-1111-1111-111111111111"
  azure_tenant_id         = "22222222-2222-2222-2222-222222222222"
  authorize_all_pipelines = true
  description             = "Development environment service connection"
}
```

## Authentication Method

This module exclusively uses **Workload Identity Federation (OIDC)** for enhanced security.

### Requirements

The service principal must:
1. Be created and configured outside this module (typically in the backplane)
2. Have appropriate role assignments on the target Azure subscription
3. Have a federated identity credential configured for Azure DevOps with:
   - Issuer: `https://vstoken.dev.azure.com/{organization_id}` (GUID, not name)
   - Subject: `sc://{org_name}/{project_name}/{connection_name}`
   - Audience: `api://AzureADTokenExchange`

### Benefits

- **No client secrets** - eliminates secret management burden
- **Automatic token rotation** - tokens are short-lived and rotated automatically
- **Enhanced security** - no long-lived credentials to compromise
- **Compliance-friendly** - meets security requirements without credential storage

## Pipeline Authorization

**Manual Authorization** (default: `authorize_all_pipelines = false`):
- Each pipeline must be explicitly authorized to use the service connection
- More secure for production environments

**Automatic Authorization** (`authorize_all_pipelines = true`):
- All pipelines in the project can use the service connection
- Convenient for development/testing environments

## Integration with Other Modules

```hcl
module "azuredevops_project" {
  source = "../project/buildingblock"
  # ... project configuration
}

module "ci_pipeline" {
  source = "../pipeline/buildingblock"
  project_id = module.azuredevops_project.project_id
  # ... pipeline configuration
}

module "azure_connection" {
  source = "./buildingblock"

  azure_devops_organization_url = module.azuredevops_project.azure_devops_organization_url
  key_vault_name                = module.azuredevops_project.key_vault_name
  resource_group_name           = module.azuredevops_project.resource_group_name

  project_id              = module.azuredevops_project.project_id
  service_connection_name = "Azure-Prod"
  azure_subscription_id   = "87654321-4321-4321-4321-210987654321"
  service_principal_id    = var.service_principal_id
  azure_tenant_id         = var.azure_tenant_id
}
```

## Using Service Connection in Pipelines

Reference the service connection in your Azure Pipelines YAML:

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'Azure-Production'  # Service connection name
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        az group list
```

## Outputs

- `service_connection_id` - Unique identifier for the service connection
- `service_connection_name` - Name of the service connection
- `service_principal_id` - Client ID of the service principal used
- `azure_subscription_id` - Connected Azure subscription ID
- `azure_subscription_name` - Connected Azure subscription name
- `authentication_method` - Authentication method used (always "workload_identity_federation")
- `authorized_all_pipelines` - Whether all pipelines are authorized to use this connection
- `workload_identity_federation_issuer` - Issuer URL for workload identity federation (read from Azure DevOps)
- `workload_identity_federation_subject` - Subject identifier for workload identity federation (read from Azure DevOps)

## Security Considerations

- Service principal must be created and managed outside this module
- Workload identity federation uses short-lived tokens (no secrets stored)
- Use least privilege principle when assigning roles to the service principal
- Enable manual authorization for production service connections
- Regularly review service principal permissions
- No credential rotation needed (tokens are automatically rotated)

## Limitations

- Service principal must be created and managed separately
- Changing service connection name requires recreation
- Federated identity credential must be configured in the service principal (typically via backplane)
- Only workload identity federation is supported (no client secret authentication)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | ~> 1.1.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuredevops_resource_authorization.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/resource_authorization) | resource |
| [azuredevops_serviceendpoint_azurerm.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/serviceendpoint_azurerm) | resource |
| [azurerm_key_vault.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.azure_devops_pat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_subscription.target](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_authorize_all_pipelines"></a> [authorize\_all\_pipelines](#input\_authorize\_all\_pipelines) | Automatically authorize all pipelines to use this service connection | `bool` | `false` | no |
| <a name="input_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#input\_azure\_devops\_organization\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Azure Subscription ID to connect to | `string` | n/a | yes |
| <a name="input_azure_tenant_id"></a> [azure\_tenant\_id](#input\_azure\_tenant\_id) | Azure AD Tenant ID | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Description for the service connection | `string` | `"Azure subscription service connection managed by Terraform"` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault containing the Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_pat_secret_name"></a> [pat\_secret\_name](#input\_pat\_secret\_name) | Name of the secret in Key Vault that contains the Azure DevOps PAT | `string` | `"azdo-pat"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Azure DevOps Project ID where the service connection will be created | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group containing the Key Vault | `string` | n/a | yes |
| <a name="input_service_connection_name"></a> [service\_connection\_name](#input\_service\_connection\_name) | Name of the service connection to create | `string` | n/a | yes |
| <a name="input_service_principal_id"></a> [service\_principal\_id](#input\_service\_principal\_id) | Client ID of the existing Azure AD service principal | `string` | n/a | yes |
| <a name="input_service_principal_key"></a> [service\_principal\_key](#input\_service\_principal\_key) | Client secret of the existing Azure AD service principal | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_authorized_all_pipelines"></a> [authorized\_all\_pipelines](#output\_authorized\_all\_pipelines) | Whether all pipelines are authorized to use this connection |
| <a name="output_azure_subscription_id"></a> [azure\_subscription\_id](#output\_azure\_subscription\_id) | Azure Subscription ID connected |
| <a name="output_azure_subscription_name"></a> [azure\_subscription\_name](#output\_azure\_subscription\_name) | Azure Subscription name connected |
| <a name="output_service_connection_id"></a> [service\_connection\_id](#output\_service\_connection\_id) | ID of the created service connection |
| <a name="output_service_connection_name"></a> [service\_connection\_name](#output\_service\_connection\_name) | Name of the created service connection |
| <a name="output_service_principal_id"></a> [service\_principal\_id](#output\_service\_principal\_id) | Client ID of the service principal |
<!-- END_TF_DOCS -->