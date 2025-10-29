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
