# Azure DevOps Pipeline Backplane

This module provisions the infrastructure required to support the Azure DevOps Pipeline building block.

## What It Provisions

- **Azure AD Service Principal**: For pipeline management automation
- **Azure Key Vault**: Stores Azure DevOps Personal Access Token (PAT)
- **Custom Role Definition**: Minimal permissions for reading Key Vault secrets
- **Role Assignment**: Grants the service principal access to Key Vault

## Prerequisites

- Azure subscription with permissions to create:
  - Azure AD applications and service principals
  - Key Vault instances
  - Custom role definitions and assignments
- Azure DevOps organization with Administrator access
- Azure DevOps PAT with `Build (Read & Execute)` scope

## Usage

```hcl
module "azuredevops_pipeline_backplane" {
  source = "./backplane"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  service_principal_name        = "azuredevops-pipeline-terraform"
  key_vault_name                = "kv-azdo-pipeline-prod"
  resource_group_name           = "rg-azdo-pipeline-prod"
  location                      = "West Europe"
  scope                         = "/subscriptions/00000000-0000-0000-0000-000000000000"
}
```

## Post-Deployment Steps

1. Create an Azure DevOps PAT with `Build (Read & Execute)` scope
2. Store the PAT in the provisioned Key Vault:
   ```bash
   az keyvault secret set --vault-name <key_vault_name> --name azdo-pat --value <your_pat>
   ```

## Outputs

- `service_principal_client_id` - For authentication
- `key_vault_name` - Where to store the PAT
- `key_vault_uri` - For programmatic access
- `azure_devops_organization_url` - Organization URL passed through

## Security Considerations

- Service principal has read-only access to Key Vault secrets
- PAT should be rotated regularly (recommended: every 90 days)
- Use separate backplane instances for different environments
