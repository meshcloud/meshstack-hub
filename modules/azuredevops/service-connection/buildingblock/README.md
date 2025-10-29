---
name: Azure DevOps Service Connection
supportedPlatforms:
  - azuredevops
description: Provides an Azure service connection in Azure DevOps for pipeline integration with Azure subscriptions
category: devops
---

# Azure DevOps Service Connection Building Block

Creates and manages Azure service connections in Azure DevOps projects, enabling pipelines to deploy and manage resources in Azure subscriptions.

## Prerequisites

- Deployed Azure DevOps Service Connection backplane
- Azure DevOps project ID where the service connection will be created
- Azure subscription ID to connect to
- Azure DevOps PAT stored in Key Vault with `Service Connections (Read, Query & Manage)` scope
- Permissions to create service principals in Azure AD
- Permissions to assign roles in the target Azure subscription

## Features

- Creates service principal for Azure authentication
- Configures Azure DevOps service connection with automatic credential management
- Assigns Azure RBAC role to service principal on target subscription
- Optional automatic authorization for all pipelines
- Supports Contributor, Reader, and Owner roles

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
}
```

### Service Connection with Reader Role

```hcl
module "readonly_service_connection" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-sc-prod"
  resource_group_name           = "rg-azdo-sc-prod"

  project_id              = "12345678-1234-1234-1234-123456789012"
  service_connection_name = "Azure-Production-ReadOnly"
  azure_subscription_id   = "87654321-4321-4321-4321-210987654321"
  azure_role              = "Reader"
}
```

### Service Connection with Auto-Authorization

```hcl
module "authorized_service_connection" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-sc-prod"
  resource_group_name           = "rg-azdo-sc-prod"

  project_id                = "12345678-1234-1234-1234-123456789012"
  service_connection_name   = "Azure-Dev"
  azure_subscription_id     = "87654321-4321-4321-4321-210987654321"
  authorize_all_pipelines   = true
  description               = "Development environment service connection"
}
```

## Azure Role Options

- **Contributor** (default): Full management access except role assignments
- **Reader**: Read-only access to resources
- **Owner**: Full access including role assignments (use sparingly)

## Service Principal Management

This module automatically:
1. Creates an Azure AD application and service principal
2. Generates a client secret for authentication
3. Assigns the specified Azure role to the subscription
4. Configures the service connection in Azure DevOps

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
  project_id              = module.azuredevops_project.project_id
  service_connection_name = "Azure-Prod"
  azure_subscription_id   = "87654321-4321-4321-4321-210987654321"
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
- `service_principal_id` - Client ID of the created service principal
- `azure_subscription_id` - Connected Azure subscription ID
- `azure_role` - Azure role assigned to the service principal

## Security Considerations

- Service principal credentials are stored securely in Azure DevOps
- Use least privilege principle - prefer Reader or Contributor over Owner
- Service principal secrets are rotated automatically by Terraform on changes
- Enable manual authorization for production service connections
- Regularly review service principal permissions

## Limitations

- Service connection uses service principal authentication (workload identity not yet supported)
- Role assignment is at subscription scope only (not resource group or management group)
- Changing service connection name requires recreation
- Service principal secret rotation requires Terraform apply

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.53.1 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | ~> 1.1.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.service_connection](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_password.service_connection](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password) | resource |
| [azuread_service_principal.service_connection](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azuredevops_resource_authorization.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/resource_authorization) | resource |
| [azuredevops_serviceendpoint_azurerm.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/serviceendpoint_azurerm) | resource |
| [azurerm_role_assignment.service_connection](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_key_vault.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.azure_devops_pat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_subscription.target](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_authorize_all_pipelines"></a> [authorize\_all\_pipelines](#input\_authorize\_all\_pipelines) | Automatically authorize all pipelines to use this service connection | `bool` | `false` | no |
| <a name="input_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#input\_azure\_devops\_organization\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_azure_role"></a> [azure\_role](#input\_azure\_role) | Azure role to assign to the service principal on the target subscription | `string` | `"Contributor"` | no |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Azure Subscription ID to connect to | `string` | n/a | yes |
| <a name="input_description"></a> [description](#input\_description) | Description for the service connection | `string` | `"Azure subscription service connection managed by Terraform"` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault containing the Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_pat_secret_name"></a> [pat\_secret\_name](#input\_pat\_secret\_name) | Name of the secret in Key Vault that contains the Azure DevOps PAT | `string` | `"azdo-pat"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Azure DevOps Project ID where the service connection will be created | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group containing the Key Vault | `string` | n/a | yes |
| <a name="input_service_connection_name"></a> [service\_connection\_name](#input\_service\_connection\_name) | Name of the service connection to create | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_authorized_all_pipelines"></a> [authorized\_all\_pipelines](#output\_authorized\_all\_pipelines) | Whether all pipelines are authorized to use this connection |
| <a name="output_azure_role"></a> [azure\_role](#output\_azure\_role) | Azure role assigned to the service principal |
| <a name="output_azure_subscription_id"></a> [azure\_subscription\_id](#output\_azure\_subscription\_id) | Azure Subscription ID connected |
| <a name="output_azure_subscription_name"></a> [azure\_subscription\_name](#output\_azure\_subscription\_name) | Azure Subscription name connected |
| <a name="output_service_connection_id"></a> [service\_connection\_id](#output\_service\_connection\_id) | ID of the created service connection |
| <a name="output_service_connection_name"></a> [service\_connection\_name](#output\_service\_connection\_name) | Name of the created service connection |
| <a name="output_service_principal_id"></a> [service\_principal\_id](#output\_service\_principal\_id) | Client ID of the service principal |
| <a name="output_service_principal_object_id"></a> [service\_principal\_object\_id](#output\_service\_principal\_object\_id) | Object ID of the service principal |
<!-- END_TF_DOCS -->