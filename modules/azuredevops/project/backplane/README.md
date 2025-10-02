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