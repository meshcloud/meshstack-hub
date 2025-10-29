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
