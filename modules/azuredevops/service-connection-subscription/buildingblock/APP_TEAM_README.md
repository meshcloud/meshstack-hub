# Azure DevOps Service Connection (Subscription)

This building block connects your Azure DevOps pipelines to Azure subscriptions, enabling automated deployment and management of cloud resources. Service connections are configured via meshStack with secure authentication using workload identity federation (OIDC) - no secrets required.

## 🚀 Usage Examples

- A development team configures a service connection to **automatically deploy applications** to their Azure subscription via CI/CD pipelines.
- A DevOps engineer creates separate service connections for **development, staging, and production** environments with appropriate permissions.
- A team sets up a read-only service connection for **monitoring and compliance** pipelines that validate infrastructure without modifying it.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create Azure DevOps project | ✅ | ❌ |
| Create service principal for Azure access | ✅ | ❌ |
| Assign Azure roles to service principal | ✅ | ❌ |
| Create service connection | ✅ | ❌ |
| Provide service principal credentials | ✅ | ❌ |
| Authorize pipelines to use connection | ⚠️ | ⚠️ |
| Use service connection in pipelines | ❌ | ✅ |
| Deploy Azure resources via pipelines | ❌ | ✅ |
| Monitor deployments | ❌ | ✅ |
| Manage federated credentials | ✅ | ❌ |

## 💡 Best Practices

### Service Connection Naming

**Why**: Clear names help identify environment and purpose instantly in pipeline YAML.

**Recommended Patterns**:
- Include cloud provider: `Azure-Production`
- Include environment: `Azure-Dev`, `Azure-Staging`, `Azure-Prod`
- Include subscription purpose: `Azure-Monitoring`, `Azure-Shared-Services`

**Examples**:
- ✅ `Azure-Production`
- ✅ `Azure-Dev-Subscription`
- ✅ `Azure-Shared-Services`
- ✅ `Azure-ReadOnly-Monitoring`
- ❌ `connection1`
- ❌ `my-connection`

### Authorization Strategy

**Manual Authorization** (Recommended for Production):
- Explicit approval required before pipelines can use the connection
- More secure - prevents unauthorized access
- Best for production environments and sensitive subscriptions
- Compliance-friendly

**Automatic Authorization** (Development/Testing):
- All pipelines can immediately use the connection
- Convenient for development workflows
- Less secure but faster to use
- Best for dev/test environments only

### Service Principal Roles

The service principal's role determines what pipelines can do in Azure. The Platform Team assigns these roles outside this module.

**Common Role Assignments**:

**Reader** (Read-Only):
- View resources and configuration
- Monitoring and reporting pipelines
- Compliance checking
- Read-only validation tasks

**Contributor** (Recommended for Deployments):
- Deploy applications
- Manage most resources (VMs, storage, networking)
- Cannot modify role assignments or permissions
- Standard CI/CD operations

**Owner** (Use Sparingly):
- Full subscription control
- Can manage role assignments
- Infrastructure as Code managing RBAC
- Only use when absolutely necessary

### Multi-Environment Setup

**Best Practice**: Create separate service connections per environment, each using dedicated service principals with environment-appropriate permissions.

**Example Structure**:
- `Azure-Development`: Auto-authorized, Contributor role, dev subscription
- `Azure-Staging`: Manual authorization, Contributor role, staging subscription
- `Azure-Production`: Manual authorization, Contributor role, production subscription

### Authentication Method

This service connection uses **Workload Identity Federation (OIDC)** exclusively:

**Key Benefits**:
- **No secrets required** - uses OpenID Connect tokens instead of passwords
- **Automatic token rotation** - short-lived tokens are refreshed automatically
- **Enhanced security** - no long-lived credentials that can be compromised
- **Compliance-friendly** - meets modern security standards
- **Zero maintenance** - no credential rotation needed

**How it works**: Azure DevOps requests a token from Azure AD, which Azure validates using the federated identity credential configured by the Platform Team. The token is short-lived and automatically refreshed.

### Security Recommendations

**Do**:
- Use manual authorization for production environments
- Request minimal required permissions (Reader when possible, Contributor when needed)
- Monitor pipeline activity logs regularly
- Leverage workload identity federation's automatic token rotation

**Don't**:
- Try to manage service principal credentials (they don't exist with OIDC!)
- Store any credentials in pipeline YAML or code repositories
- Use Owner role unless absolutely necessary
- Auto-authorize production service connections

## 📝 Using Service Connection in Pipelines

### Azure CLI Task

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    displayName: 'Deploy Resources'
    inputs:
      azureSubscription: 'Azure-Production'
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        az group create --name myResourceGroup --location eastus
        az storage account create --name mystorageaccount \
          --resource-group myResourceGroup --sku Standard_LRS
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

If manual authorization is configured:

1. Run your pipeline - it will pause for authorization
2. Azure DevOps prompts: "This pipeline needs permission to access a resource"
3. Click **View** and then **Permit**
4. Pipeline continues execution

**To authorize permanently**:
1. Go to **Project Settings** → **Service connections**
2. Select your service connection
3. Click **Security** → Authorize specific pipelines
4. Select pipelines that should always have access

### Automatic Authorization

If automatic authorization is configured:
- No action needed
- All pipelines can immediately use the connection

## 🔍 Verifying Service Connection

After creation, verify in Azure DevOps:

1. Navigate to **Project Settings**
2. Go to **Service connections**
3. Find your service connection name
4. Verify:
   - ✅ Connection status is green (verified)
   - ✅ Subscription name matches expected
   - ✅ Service principal is valid

### Testing the Connection

Create a simple test pipeline:

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

Run manually to verify connectivity and permissions.

## ⚠️ Important Notes

- Service principal must be created and configured by Platform Team
- Service connection name is used in pipeline YAML (case-sensitive)
- Service principal permissions are managed outside this module
- Manual authorization is more secure for production environments
- No credential rotation required - workload identity federation handles authentication automatically

## 🆘 Troubleshooting

### "Service connection not found" in pipeline

**Cause**: Service connection name mismatch or not authorized

**Solution**:
1. Verify service connection name matches exactly in YAML (case-sensitive)
2. Check if manual authorization is required
3. Ensure connection exists in project settings

### "Insufficient permissions" error

**Cause**: Service principal lacks required permissions for the operation

**Solution**:
1. Contact Platform Team to verify service principal role assignment
2. Verify required role for your operation:
   - Resource creation/modification: Contributor
   - Read-only operations: Reader
   - RBAC modifications: Owner
3. Check scope of role assignment (subscription/resource group level)

### Service connection shows as invalid

**Cause**: Service principal or federated credential configuration issue

**Solution**:
1. Contact Platform Team to verify:
   - Service principal exists and is active
   - Federated identity credential is properly configured
   - Azure DevOps organization ID matches the issuer
2. Platform Team will investigate and fix the federated credential configuration

### Cannot deploy to resource group

**Cause**: Service principal has Reader role (read-only)

**Solution**: Contact Platform Team to assign Contributor role to the service principal at the appropriate scope

### Pipeline authorization keeps prompting

**Cause**: Manual authorization required for each pipeline run

**Solution**:
1. Authorize the pipeline permanently (see "Authorizing Pipelines" section above)
2. Or request automatic authorization if appropriate for the environment

### "Subscription not found" error

**Cause**: Service principal doesn't have access to the subscription

**Solution**: Contact Platform Team to verify:
- Service principal exists
- Service principal has role assignment on the subscription
- Subscription ID is correct

## 🔄 Credential Management

### No Credential Rotation Required!

This service connection uses **Workload Identity Federation (OIDC)**, which means:

✅ **No secrets to manage** - authentication uses short-lived tokens
✅ **Automatic token rotation** - tokens expire quickly and are refreshed automatically
✅ **Zero maintenance** - no manual credential rotation needed
✅ **Better security** - no long-lived credentials that can leak or be compromised

### What This Means for You

**You don't need to**:
- Request credential rotation
- Worry about expiring passwords or secrets
- Schedule maintenance windows for credential updates
- Update pipeline configurations for credential changes

**The Platform Team manages**:
- Service principal configuration
- Federated identity credential setup
- Azure role assignments
- Trust relationship between Azure DevOps and Azure AD

## 📚 Related Documentation

- [Azure DevOps Service Connections](https://learn.microsoft.com/en-us/azure/devops/pipelines/library/service-endpoints)
- [Azure Service Principal Best Practices](https://learn.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal)
- [Azure RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Pipeline Permissions](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/resources#authorize-a-resource)
