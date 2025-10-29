# Azure DevOps Service Connection

Connect your Azure DevOps pipelines to Azure subscriptions to deploy and manage cloud resources automatically.

## 🚀 Usage Examples

### Basic Service Connection

```hcl
module "azure_prod_connection" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-prod"
  resource_group_name           = "rg-azdo-prod"

  project_id              = "12345678-1234-1234-1234-123456789012"
  service_connection_name = "Azure-Production"
  azure_subscription_id   = "87654321-4321-4321-4321-210987654321"
}
```

### Read-Only Connection

```hcl
module "azure_readonly" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-prod"
  resource_group_name           = "rg-azdo-prod"

  project_id              = "12345678-1234-1234-1234-123456789012"
  service_connection_name = "Azure-ReadOnly"
  azure_subscription_id   = "87654321-4321-4321-4321-210987654321"
  azure_role              = "Reader"
  description             = "Read-only access for monitoring pipelines"
}
```

### Development Environment (Auto-Authorized)

```hcl
module "azure_dev" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-prod"
  resource_group_name           = "rg-azdo-prod"

  project_id              = "12345678-1234-1234-1234-123456789012"
  service_connection_name = "Azure-Development"
  azure_subscription_id   = "11111111-1111-1111-1111-111111111111"
  authorize_all_pipelines = true
}
```

## 🔄 Shared Responsibility Matrix

| Task | Platform Team | App Team |
|------|--------------|----------|
| Deploy backplane infrastructure | ✅ | ❌ |
| Store Azure DevOps PAT in Key Vault | ✅ | ❌ |
| Create Azure DevOps project | ✅ | ❌ |
| Create service connection (via Terraform) | ✅ | ❌ |
| Authorize pipelines to use connection | ⚠️ (If manual) | ⚠️ (If manual) |
| Use service connection in pipelines | ❌ | ✅ |
| Deploy Azure resources via pipelines | ❌ | ✅ |
| Monitor service principal permissions | ✅ | ❌ |
| Rotate service principal credentials | ✅ | ❌ |

## 💡 Best Practices

### Service Connection Naming

**Why**: Clear names help identify environment and purpose instantly.

**Recommended Patterns**:
- Include cloud provider: `Azure-Production`
- Include environment: `Azure-Dev`, `Azure-Staging`, `Azure-Prod`
- Include subscription purpose: `Azure-Monitoring`, `Azure-Shared-Services`

**Examples**:
- ✅ `Azure-Production`
- ✅ `Azure-Dev-Subscription`
- ✅ `Azure-Shared-Services`
- ❌ `connection1`
- ❌ `my-connection`

### Role Selection

**Why**: Follow least privilege principle to minimize security risks.

**When to Use Each Role**:

**Reader**:
- Monitoring and reporting pipelines
- Compliance checking
- Read-only validation tasks

**Contributor** (Recommended):
- Deploying applications
- Managing resources
- Standard CI/CD operations
- Cannot modify role assignments

**Owner** (Use Sparingly):
- Infrastructure as Code managing RBAC
- Creating additional service principals
- Full subscription management
- ⚠️ Only use when absolutely necessary

### Authorization Strategy

**Manual Authorization** (`authorize_all_pipelines = false`):
- ✅ Production environments
- ✅ Sensitive subscriptions
- ✅ Compliance requirements
- Explicit pipeline approval required

**Automatic Authorization** (`authorize_all_pipelines = true`):
- ✅ Development environments
- ✅ Testing/sandbox subscriptions
- ✅ Internal tools
- ⚠️ Less secure but more convenient

### Multi-Environment Setup

**Pattern**: Separate service connections per environment

```hcl
module "azure_dev" {
  source                  = "./buildingblock"
  service_connection_name = "Azure-Development"
  azure_subscription_id   = var.dev_subscription_id
  authorize_all_pipelines = true
}

module "azure_staging" {
  source                  = "./buildingblock"
  service_connection_name = "Azure-Staging"
  azure_subscription_id   = var.staging_subscription_id
  azure_role              = "Contributor"
}

module "azure_prod" {
  source                  = "./buildingblock"
  service_connection_name = "Azure-Production"
  azure_subscription_id   = var.prod_subscription_id
  azure_role              = "Contributor"
  authorize_all_pipelines = false
}
```

## 📝 Using Service Connection in Your Pipeline

### Azure CLI Task

```yaml
# azure-pipelines.yml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    displayName: 'Deploy Resources'
    inputs:
      azureSubscription: 'Azure-Production'  # Your service connection name
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        az group create --name myResourceGroup --location eastus
        az storage account create --name mystorageaccount --resource-group myResourceGroup --sku Standard_LRS
```

### Azure PowerShell Task

```yaml
steps:
  - task: AzurePowerShell@5
    displayName: 'Run Azure PowerShell Script'
    inputs:
      azureSubscription: 'Azure-Production'
      ScriptType: 'InlineScript'
      Inline: |
        Get-AzResourceGroup
        New-AzResourceGroup -Name "myRG" -Location "eastus"
      azurePowerShellVersion: 'LatestVersion'
```

### Terraform Task

```yaml
steps:
  - task: TerraformTaskV4@4
    displayName: 'Terraform Init'
    inputs:
      provider: 'azurerm'
      command: 'init'
      backendServiceArm: 'Azure-Production'
      backendAzureRmResourceGroupName: 'terraform-state-rg'
      backendAzureRmStorageAccountName: 'tfstatestorage'
      backendAzureRmContainerName: 'tfstate'
      backendAzureRmKey: 'terraform.tfstate'

  - task: TerraformTaskV4@4
    displayName: 'Terraform Apply'
    inputs:
      provider: 'azurerm'
      command: 'apply'
      environmentServiceNameAzureRM: 'Azure-Production'
```

### ARM Template Deployment

```yaml
steps:
  - task: AzureResourceManagerTemplateDeployment@3
    displayName: 'Deploy ARM Template'
    inputs:
      azureResourceManagerConnection: 'Azure-Production'
      subscriptionId: '87654321-4321-4321-4321-210987654321'
      resourceGroupName: 'myResourceGroup'
      location: 'East US'
      templateLocation: 'Linked artifact'
      csmFile: 'azuredeploy.json'
      csmParametersFile: 'azuredeploy.parameters.json'
      deploymentMode: 'Incremental'
```

## 🔐 Authorizing Pipelines

### Manual Authorization (Recommended for Production)

If `authorize_all_pipelines = false`:

1. Run your pipeline - it will pause for authorization
2. Azure DevOps will prompt: "This pipeline needs permission to access a resource"
3. Click **View** and then **Permit**
4. Pipeline continues execution

**First-Time Setup**:
```yaml
# Pipeline will fail first time with authorization required
# Go to: Project Settings → Service connections → Your connection
# Click "Security" → Authorize specific pipelines
```

### Automatic Authorization

If `authorize_all_pipelines = true`:
- No action needed
- All pipelines can immediately use the connection

## 🔍 Verifying Service Connection

After creation, verify in Azure DevOps:

1. Navigate to **Project Settings**
2. Go to **Service connections**
3. Find your service connection name
4. Verify:
   - ✅ Connection status is green
   - ✅ Subscription name matches
   - ✅ Service principal is valid

### Testing the Connection

```yaml
# test-connection.yml
trigger: none

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'Azure-Production'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        echo "Testing Azure connection..."
        az account show
        az group list --output table
```

## ⚠️ Important Notes

- Service principal credentials are managed automatically by Terraform
- Changing `service_connection_name` requires recreating the connection
- Deleting the Terraform resource removes the service connection and service principal
- Service principal has subscription-level permissions only
- Manual authorization is more secure for production environments

## 🆘 Troubleshooting

### "Service connection not found" in pipeline

**Cause**: Service connection name mismatch or not authorized

**Solution**:
1. Verify service connection name matches exactly (case-sensitive)
2. Check if manual authorization is required
3. Ensure connection exists in project

### "Insufficient permissions" error

**Cause**: Service principal lacks required permissions

**Solution**:
1. Check `azure_role` is appropriate for the task
2. Verify role assignment in Azure portal:
   ```bash
   az role assignment list --assignee <service_principal_id> --subscription <subscription_id>
   ```
3. May need `Owner` role for certain operations

### Service connection shows as invalid

**Cause**: Service principal credentials expired or deleted

**Solution**: Run `terraform apply` to regenerate credentials

### Cannot deploy to resource group

**Cause**: Reader role assigned (read-only)

**Solution**: Change to Contributor role:
```hcl
azure_role = "Contributor"
```

### Pipeline authorization keeps prompting

**Cause**: Manual authorization required each time

**Solution**: Set `authorize_all_pipelines = true` or authorize pipeline permanently

## 🔄 Credential Rotation

Service principal secrets are automatically rotated when:
- Terraform detects configuration changes
- Resource is tainted and recreated

**Manual Rotation**:
```bash
terraform taint module.azure_connection.azuread_application_password.service_connection
terraform apply
```

## 📚 Related Documentation

- [Azure DevOps Service Connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)
- [Azure Service Principal Best Practices](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)
- [Azure RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Pipeline Permissions](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/resources#authorize-a-resource)
