# Azure Key Vault

## Description
This building block provides a production-grade Azure Key Vault for secure storage and management of secrets, keys, and certificates. It delivers a fully managed and secure key vault with support for both public and private deployments, optional hub connectivity, and seamless integration with Azure services.

## Usage Motivation
This building block is for application teams that need a secure and scalable solution to store and manage secrets, encryption keys, and certificates. Azure Key Vault ensures compliance with security best practices and helps prevent accidental exposure of sensitive credentials, while eliminating the complexity of managing key storage infrastructure.

## 🚀 Usage Examples
- A development team stores API keys and database credentials in Azure Key Vault instead of hardcoding them in application code
- A DevOps team manages TLS certificates in Key Vault and integrates them with Azure Application Gateway for secure HTTPS communication
- A security team implements centralized secret management for microservices with automatic rotation policies
- An application uses managed identities to securely retrieve database connection strings from Key Vault

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|--------------|------------------|
| Provisioning and configuring Key Vault | ✅ | ❌ |
| Managing network configuration and private endpoints | ✅ | ❌ |
| Setting up hub network peering (for private Key Vault) | ✅ | ❌ |
| Enforcing security policies (e.g., RBAC, logging) | ✅ | ❌ |
| Storing and retrieving secrets, keys, and certificates | ❌ | ✅ |
| Rotating and managing secrets lifecycle | ❌ | ✅ |
| Implementing secret versioning strategies | ❌ | ✅ |
| Integrating Key Vault with applications and services | ❌ | ✅ |

## 💡 Best Practices for Secure and Efficient Key Vault Usage

### Security
- **Use Azure RBAC**: Always use Azure RBAC instead of access policies for better governance and auditing
- **Use managed identities**: Integrate with Azure services securely without exposing credentials
- **Enable soft delete and purge protection**: Prevent accidental deletion of secrets and keys
- **Use private endpoints**: Deploy private Key Vault for production workloads to prevent internet exposure
- **Implement network rules**: Restrict access using firewall rules when public access is required
- **Monitor access patterns**: Track who accesses which secrets and when

### Secret Management
- **Use semantic versioning**: Version secrets for better tracking and rollback capabilities
- **Implement rotation policies**: Configure automatic rotation for secrets that support it
- **Set expiration dates**: Configure expiration dates for secrets to enforce rotation
- **Use separate Key Vaults**: Separate development, staging, and production secrets
- **Avoid storing secrets in code**: Never commit secrets to source control
- **Use Key Vault references**: Use Key Vault references in App Service and Functions

### Performance & Reliability
- **Cache secrets appropriately**: Cache retrieved secrets in your application to reduce calls
- **Implement retry logic**: Handle transient failures with exponential backoff
- **Monitor throttling**: Track API call limits and optimize secret retrieval patterns
- **Use regional endpoints**: Deploy Key Vault close to your application for lower latency

### Cost Optimization
- **Use Standard tier**: Premium tier is only needed for HSM-protected keys
- **Monitor unused secrets**: Regularly audit and remove unused secrets and keys
- **Optimize API calls**: Batch secret retrieval where possible to reduce transaction costs
- **Use managed identities**: Avoid service principal credential management overhead

### CI/CD Integration
- **Use service principals or managed identities**: Authenticate CI/CD pipelines using Azure AD
- **Reference secrets at runtime**: Never store secrets in build artifacts
- **Implement approval gates**: Require security approval before accessing production secrets
- **Use separate Key Vaults**: Use different Key Vaults for CI/CD and production

## Deployment Scenarios

### Scenario Matrix

This building block supports 4 deployment scenarios based on your networking and security requirements:

| # | Scenario | Private Endpoint | VNet Type | Hub Peering | Use Case |
|---|----------|-----------------|-----------|-------------|----------|
| **1** | **New VNet + Hub Peering** | ✅ | New (created) | ✅ Created | Isolated workload needing hub/on-prem access |
| **2** | **Existing Shared VNet** | ✅ | Existing (shared) | ❌ Skipped | Multi-tenant with shared connectivity |
| **3** | **Private Isolated** | ✅ | New or Existing | ❌ None | Secure workload, same-VNet access only |
| **4** | **Completely Public** | ❌ | Not applicable | ❌ None | Dev/test, public internet access |

**Configuration Quick Reference:**

| Scenario | `private_endpoint_enabled` | `vnet_name` | `hub_vnet_name` |
|----------|---------------------------|-------------|-----------------|
| **1 - New VNet + Hub** | `true` | `null` | Set (creates peering) |
| **2 - Existing Shared VNet** | `true` | Set (existing) | Omit/null (no peering) |
| **3 - Private Isolated** | `true` | `null` or Set | `null` |
| **4 - Public** | `false` | Any | Any |

---

## Getting Started

### Authenticating with Key Vault

#### Using Azure CLI (Recommended)
```bash
# Login to Azure
az login

# Set Key Vault secrets
az keyvault secret set --vault-name mycompanykv --name "DatabasePassword" --value "SecurePassword123!"

# Retrieve secrets
az keyvault secret show --vault-name mycompanykv --name "DatabasePassword" --query value -o tsv
```

#### Using Azure PowerShell
```powershell
# Connect to Azure
Connect-AzAccount

# Set a secret
Set-AzKeyVaultSecret -VaultName "mycompanykv" -Name "DatabasePassword" -SecretValue (ConvertTo-SecureString "SecurePassword123!" -AsPlainText -Force)

# Retrieve a secret
Get-AzKeyVaultSecret -VaultName "mycompanykv" -Name "DatabasePassword" -AsPlainText
```

#### Using Managed Identity (Recommended for Applications)
```csharp
// .NET example using managed identity
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

var client = new SecretClient(
    new Uri("https://mycompanykv.vault.azure.net/"),
    new DefaultAzureCredential()
);

KeyVaultSecret secret = await client.GetSecretAsync("DatabasePassword");
string password = secret.Value;
```

### Working with Private Key Vault

For private Key Vault, ensure you have network connectivity:

1. **From Azure Resources**: Must be in peered VNet or same VNet as private endpoint
2. **From On-Premises**: Connect via hub VNet using ExpressRoute or VPN Gateway
3. **From Developer Workstation**: Use VPN or Azure Bastion to access private network

```bash
# Connect via VPN or Bastion, then access Key Vault
az keyvault secret show --vault-name mycompanykv --name "DatabasePassword"

# Verify private endpoint resolution
nslookup mycompanykv.vault.azure.net
# Should resolve to private IP (10.x.x.x)
```

### Managing Secrets

```bash
# Create a secret
az keyvault secret set --vault-name mycompanykv --name "ApiKey" --value "secret-value-123"

# Create a secret with expiration
az keyvault secret set --vault-name mycompanykv --name "TempToken" --value "token-abc" --expires "2025-12-31T23:59:59Z"

# List all secrets
az keyvault secret list --vault-name mycompanykv

# List secret versions
az keyvault secret list-versions --vault-name mycompanykv --name "ApiKey"

# Get a specific version
az keyvault secret show --vault-name mycompanykv --name "ApiKey" --version <version-id>

# Delete a secret (soft delete)
az keyvault secret delete --vault-name mycompanykv --name "ApiKey"

# Recover a deleted secret
az keyvault secret recover --vault-name mycompanykv --name "ApiKey"

# Purge a deleted secret (permanent)
az keyvault secret purge --vault-name mycompanykv --name "ApiKey"
```

### Managing Keys

```bash
# Create an RSA key
az keyvault key create --vault-name mycompanykv --name "MyEncryptionKey" --kty RSA --size 2048

# List keys
az keyvault key list --vault-name mycompanykv

# Get key details
az keyvault key show --vault-name mycompanykv --name "MyEncryptionKey"

# Delete a key
az keyvault key delete --vault-name mycompanykv --name "MyEncryptionKey"
```

### Managing Certificates

```bash
# Create a self-signed certificate
az keyvault certificate create --vault-name mycompanykv --name "MyCert" --policy "$(az keyvault certificate get-default-policy)"

# Import a certificate
az keyvault certificate import --vault-name mycompanykv --name "ImportedCert" --file certificate.pfx --password "certpassword"

# List certificates
az keyvault certificate list --vault-name mycompanykv

# Download a certificate
az keyvault certificate download --vault-name mycompanykv --name "MyCert" --file mycert.pem
```

### Monitoring and Troubleshooting

```bash
# Check Key Vault access
az keyvault check-access --vault-name mycompanykv

# Enable diagnostic logging
az monitor diagnostic-settings create \
  --resource <keyvault-resource-id> \
  --name kv-diagnostics \
  --workspace <log-analytics-workspace-id> \
  --logs '[{"category": "AuditEvent", "enabled": true}]'

# View Key Vault metrics
az monitor metrics list --resource <keyvault-resource-id> --metric Availability
```

## Security Checklist

- [ ] Use Azure RBAC instead of access policies
- [ ] Enable soft delete and purge protection
- [ ] Enable private endpoint for production workloads
- [ ] Configure network access rules (firewall or private endpoint)
- [ ] Implement diagnostic logging to Log Analytics
- [ ] Use managed identities for Azure service integration
- [ ] Implement RBAC with least-privilege access
- [ ] Set expiration dates on secrets
- [ ] Enable Azure Defender for Key Vault
- [ ] Regularly audit and rotate secrets
- [ ] Monitor access patterns and unusual activity
- [ ] Separate dev, staging, and production Key Vaults

## Common Integration Patterns

### Azure App Service
```bash
# Reference Key Vault secret in App Service configuration
az webapp config appsettings set \
  --resource-group myResourceGroup \
  --name myWebApp \
  --settings DatabasePassword="@Microsoft.KeyVault(VaultName=mycompanykv;SecretName=DatabasePassword)"
```

### Azure Functions
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "@Microsoft.KeyVault(VaultName=mycompanykv;SecretName=StorageConnectionString)",
    "DatabasePassword": "@Microsoft.KeyVault(VaultName=mycompanykv;SecretName=DatabasePassword)"
  }
}
```

### Kubernetes (AKS with CSI Driver)
```yaml
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: azure-keyvault-secrets
spec:
  provider: azure
  parameters:
    keyvaultName: "mycompanykv"
    tenantId: "<tenant-id>"
    objects: |
      array:
        - |
          objectName: DatabasePassword
          objectType: secret
---
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: myapp
    image: myapp:latest
    volumeMounts:
    - name: secrets-store
      mountPath: "/mnt/secrets"
      readOnly: true
  volumes:
  - name: secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: "azure-keyvault-secrets"
```

### CI/CD Pipeline (Azure DevOps)
```yaml
- task: AzureKeyVault@2
  inputs:
    azureSubscription: 'MyServiceConnection'
    KeyVaultName: 'mycompanykv'
    SecretsFilter: '*'
    RunAsPreJob: true
```

### GitHub Actions
```yaml
- name: Get secrets from Key Vault
  uses: Azure/get-keyvault-secrets@v1
  with:
    keyvault: "mycompanykv"
    secrets: 'DatabasePassword, ApiKey'
  id: kvSecrets

- name: Use secret
  run: |
    echo "Secret retrieved: ${{ steps.kvSecrets.outputs.DatabasePassword }}"
```
