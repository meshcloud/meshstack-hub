# Azure Service Principal

## 🚀 Usage Examples

### Basic Service Principal for CI/CD

```hcl
module "cicd_service_principal" {
  source = "./buildingblock"

  display_name          = "my-app-cicd-sp"
  description           = "Service principal for automated deployments"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  azure_role            = "Contributor"
}
```

### Read-Only Service Principal for Monitoring

```hcl
module "monitoring_sp" {
  source = "./buildingblock"

  display_name          = "monitoring-readonly-sp"
  description           = "Read-only access for monitoring tools"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  azure_role            = "Reader"
}
```

### Service Principal with Extended Secret Lifetime

```hcl
module "long_lived_sp" {
  source = "./buildingblock"

  display_name          = "backup-service-sp"
  description           = "Service principal for backup automation"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
  azure_role            = "Contributor"
  secret_rotation_days  = 180
}
```

## 🔄 Shared Responsibility Matrix

| Task | Platform Team | App Team |
|------|--------------|----------|
| Provide service principal building block | ✅ | ❌ |
| Create service principal via Terraform | ⚠️ | ⚠️ |
| Store client secret securely | ❌ | ✅ |
| Configure role assignments | ⚠️ | ⚠️ |
| Monitor secret expiration | ❌ | ✅ |
| Rotate secrets before expiration | ❌ | ✅ |
| Use least privilege roles | ❌ | ✅ |
| Review and audit service principal usage | ✅ | ✅ |
| Remove unused service principals | ❌ | ✅ |

## 💡 Best Practices

### Service Principal Naming

**Why**: Clear names help identify purpose and ownership.

**Recommended Patterns**:
- Include application/service name: `myapp-production-sp`
- Include purpose: `myapp-cicd-sp`, `myapp-monitoring-sp`
- Include environment: `myapp-dev-sp`, `myapp-prod-sp`

**Examples**:
- ✅ `ecommerce-prod-deployment-sp`
- ✅ `analytics-monitoring-sp`
- ✅ `backup-automation-sp`
- ❌ `sp1`
- ❌ `test-service-principal`

### Role Selection

**Why**: Follow least privilege principle to minimize security risks.

**When to Use Each Role**:

**Reader**:
- Monitoring and reporting tools
- Compliance scanning
- Read-only dashboards
- Cost analysis tools

**Contributor** (Recommended):
- CI/CD pipelines deploying resources
- Application deployments
- Infrastructure as Code
- Standard automation tasks
- **Cannot** assign roles to other principals

**Owner** (Use Very Sparingly):
- Infrastructure as Code managing RBAC
- Creating additional service principals
- Full subscription management
- ⚠️ **Only use when absolutely necessary**
- ⚠️ **Requires strong justification**

### Secret Rotation Strategy

**Why**: Regular secret rotation reduces risk of credential compromise.

**Recommended Rotation Periods**:
- **Production environments**: 90 days (default)
- **Development/test**: 180 days
- **Long-running automation**: 90-180 days
- **High-security applications**: 30-60 days

**Important**: Plan secret rotation carefully to avoid service disruptions.

### Secure Secret Storage

**Never**:
- ❌ Commit secrets to version control
- ❌ Store secrets in plain text files
- ❌ Share secrets via email or chat
- ❌ Log secrets in application logs

**Always**:
- ✅ Store in Azure Key Vault
- ✅ Use secret management systems (HashiCorp Vault, etc.)
- ✅ Use environment variables for runtime
- ✅ Rotate secrets before expiration
- ✅ Use separate service principals per environment

## 📝 Retrieving Service Principal Credentials

After creating the service principal, retrieve the credentials:

```bash
terraform output service_principal_id
terraform output tenant_id
terraform output -raw client_secret
```

**Store these values securely** - the client secret cannot be retrieved again without rotation.

## 🔐 Using Service Principal for Authentication

### Azure CLI

```bash
az login --service-principal \
  --username <service_principal_id> \
  --password <client_secret> \
  --tenant <tenant_id>
```

### Terraform

```hcl
provider "azurerm" {
  features {}
  
  client_id       = var.service_principal_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}
```

### Azure DevOps Service Connection

```hcl
module "service_principal" {
  source = "./buildingblock"
  
  display_name          = "azuredevops-deployment-sp"
  azure_subscription_id = var.subscription_id
  azure_role            = "Contributor"
}

module "azuredevops_connection" {
  source = "../../azuredevops/service-connection-subscription/buildingblock"
  
  service_principal_id  = module.service_principal.service_principal_id
  service_principal_key = module.service_principal.client_secret
  azure_tenant_id       = module.service_principal.tenant_id
  # ... other configuration
}
```

### GitHub Actions

```yaml
- name: Azure Login
  uses: azure/login@v1
  with:
    creds: |
      {
        "clientId": "${{ secrets.AZURE_CLIENT_ID }}",
        "clientSecret": "${{ secrets.AZURE_CLIENT_SECRET }}",
        "subscriptionId": "${{ secrets.AZURE_SUBSCRIPTION_ID }}",
        "tenantId": "${{ secrets.AZURE_TENANT_ID }}"
      }
```

## 🔄 Secret Rotation Process

When secrets approach expiration:

1. **Update rotation period** (if needed):
   ```hcl
   secret_rotation_days = 90
   ```

2. **Run Terraform apply**:
   ```bash
   terraform apply
   ```

3. **Retrieve new secret**:
   ```bash
   terraform output -raw client_secret
   ```

4. **Update secret in Key Vault or secret management system**:
   ```bash
   az keyvault secret set \
     --vault-name <key-vault-name> \
     --name <secret-name> \
     --value <new-secret>
   ```

5. **Verify services using the service principal are updated**

## ⚠️ Important Notes

- Client secrets are stored in Terraform state (ensure state is encrypted and secured)
- Secret cannot be retrieved after creation without rotation
- Changing `display_name` recreates the application and service principal
- Role assignments are at subscription scope only
- Only Owner, Contributor, and Reader roles are supported
- Old secrets are automatically revoked after rotation

## 🆘 Troubleshooting

### "Insufficient privileges" error during creation

**Cause**: User lacks permissions to create Entra ID applications

**Solution**: 
- Request "Application Developer" role in Entra ID
- Or request "Cloud Application Administrator" role for full access

### Secret expired

**Cause**: Secret has passed expiration date

**Solution**:
1. Update `secret_rotation_days` if needed
2. Run `terraform apply` to generate new secret
3. Retrieve and store new secret
4. Update all services using the credential

### Service principal authentication fails

**Cause**: Multiple possible causes

**Solution**:
1. Verify client ID, tenant ID, and secret are correct
2. Check role assignment:
   ```bash
   az role assignment list --assignee <service_principal_id>
   ```
3. Ensure secret hasn't expired:
   ```bash
   terraform output secret_expiration_date
   ```
4. Verify subscription ID is correct

### Cannot delete service principal

**Cause**: Service principal is in use or has dependencies

**Solution**:
1. Remove all role assignments first
2. Check for dependencies in Azure DevOps, GitHub, etc.
3. Run `terraform destroy` to properly clean up

## 📊 Monitoring Secret Expiration

Set up monitoring for secret expiration:

```bash
# Check expiration date
terraform output secret_expiration_date

# Calculate days until expiration
EXPIRY=$(terraform output -raw secret_expiration_date)
DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))
echo "Secret expires in $DAYS_LEFT days"
```

**Recommendation**: Set up alerts 30 days before expiration.

## 🔗 Integration Examples

### Complete CI/CD Setup with Azure DevOps

```hcl
# Create service principal for Azure access
module "azure_sp" {
  source = "./buildingblock"
  
  display_name          = "myapp-cicd-sp"
  description           = "CI/CD pipeline service principal"
  azure_subscription_id = var.azure_subscription_id
  azure_role            = "Contributor"
  secret_rotation_days  = 90
}

# Store secret in Key Vault
resource "azurerm_key_vault_secret" "sp_secret" {
  name         = "myapp-sp-secret"
  value        = module.azure_sp.client_secret
  key_vault_id = var.key_vault_id
}

# Create Azure DevOps service connection
module "azdo_connection" {
  source = "../../azuredevops/service-connection-subscription/buildingblock"
  
  azure_devops_organization_url = var.azdo_org_url
  key_vault_name                = var.key_vault_name
  resource_group_name           = var.resource_group_name
  
  project_id              = var.azdo_project_id
  service_connection_name = "Azure-Production"
  azure_subscription_id   = var.azure_subscription_id
  service_principal_id    = module.azure_sp.service_principal_id
  service_principal_key   = module.azure_sp.client_secret
  azure_tenant_id         = module.azure_sp.tenant_id
}
```

### Multi-Environment Setup

```hcl
# Development
module "dev_sp" {
  source = "./buildingblock"
  
  display_name          = "myapp-dev-sp"
  azure_subscription_id = var.dev_subscription_id
  azure_role            = "Contributor"
  secret_rotation_days  = 180
}

# Staging
module "staging_sp" {
  source = "./buildingblock"
  
  display_name          = "myapp-staging-sp"
  azure_subscription_id = var.staging_subscription_id
  azure_role            = "Contributor"
  secret_rotation_days  = 90
}

# Production
module "prod_sp" {
  source = "./buildingblock"
  
  display_name          = "myapp-prod-sp"
  azure_subscription_id = var.prod_subscription_id
  azure_role            = "Contributor"
  secret_rotation_days  = 60
}
```

## 📚 Related Documentation

- [Entra ID Service Principals](https://learn.microsoft.com/en-us/entra/identity-platform/app-objects-and-service-principals)
- [Azure RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Best Practices for Service Principals](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal)
- [Credential Management](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal#option-3-create-a-new-client-secret)
