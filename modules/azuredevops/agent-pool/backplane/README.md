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
