# Azure Service Principal

This building block creates a service principal in Azure Entra ID (formerly Azure Active Directory) with role-based access to your Azure subscription. Service principals are used for automated authentication and authorization in CI/CD pipelines, applications, and automation scripts.

## 🚀 Usage Examples

- A development team creates a service principal to **automate deployments** from their CI/CD pipelines to Azure resources.
- A DevOps engineer sets up separate service principals for **development, staging, and production** environments with appropriate permissions.
- A team configures a read-only service principal for **monitoring and compliance tools** that need to scan infrastructure without making changes.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create service principal | ✅ | ❌ |
| Assign Azure roles to service principal | ✅ | ❌ |
| Provide service principal credentials | ✅ | ❌ |
| Store client secret securely | ❌ | ✅ |
| Use service principal in pipelines/applications | ❌ | ✅ |
| Monitor secret expiration | ❌ | ✅ |
| Request secret rotation before expiration | ❌ | ✅ |
| Use least privilege roles | ⚠️ | ✅ |
| Review and audit service principal usage | ✅ | ✅ |
| Request removal of unused service principals | ❌ | ✅ |

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

## 📝 Receiving Service Principal Credentials

After the Platform Team creates your service principal, you'll receive:
- **Client ID** (Service Principal ID / Application ID)
- **Client Secret** (Password)
- **Tenant ID** (Azure AD Directory ID)
- **Subscription ID** (Target Azure subscription)

**Store these values securely immediately** - the client secret cannot be retrieved again without rotation.

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

Service principals are commonly used with Azure DevOps service connections. The Platform Team will configure the service connection using your service principal credentials, allowing your pipelines to authenticate to Azure.

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

When secrets approach expiration (you should receive alerts):

1. **Request rotation from Platform Team**:
   - Provide service principal name
   - Indicate urgency (days until expiration)
   - List affected services/pipelines

2. **Receive new credentials** from Platform Team

3. **Update credentials in all locations**:
   - Azure Key Vault secrets
   - CI/CD pipeline secrets
   - Application configuration
   - Environment variables

4. **Test authentication** with new credentials

5. **Verify all services** using the service principal are working

6. **Confirm completion** with Platform Team

## ⚠️ Important Notes

- **Save credentials immediately** - client secrets cannot be retrieved after initial provisioning
- Secret rotation must be requested from Platform Team before expiration
- Service principal names should be descriptive and follow naming conventions
- Role assignments are at subscription scope
- Common roles: Owner, Contributor, Reader (request appropriate level)
- Old secrets are automatically revoked after rotation
- Always use separate service principals per environment (dev, staging, prod)

## 🆘 Troubleshooting

### Secret expired

**Cause**: Secret has passed expiration date

**Solution**:
1. Contact Platform Team immediately to request emergency rotation
2. Provide list of affected services for impact assessment
3. Receive new credentials from Platform Team
4. Update all services using the credential as quickly as possible

### Service principal authentication fails

**Cause**: Multiple possible causes

**Solution**:
1. Verify client ID, tenant ID, and secret are correct
2. Check if secret has expired (contact Platform Team)
3. Verify you're authenticating to the correct subscription
4. Ensure service principal has required role assignment
5. Contact Platform Team to verify service principal status

### Need to remove service principal

**Cause**: Service principal no longer needed

**Solution**:
1. Document all locations where credentials are used
2. Remove credentials from all pipelines and applications
3. Contact Platform Team to request service principal deletion
4. Confirm no services are affected after removal

## 📊 Monitoring Secret Expiration

**Platform Team Responsibilities**:
- Monitor secret expiration dates
- Send alerts 30 days before expiration
- Provide rotation services

**Your Responsibilities**:
- Respond to expiration alerts promptly
- Request rotation at least 2 weeks before expiration
- Track where credentials are used
- Update credentials in all locations after rotation
- Test services after rotation

**Recommendation**: Maintain an inventory of where each service principal is used for quick rotation.

## 🔗 Common Integration Patterns

### Complete CI/CD Setup with Azure DevOps

**Request from Platform Team**:
1. Service principal for Azure access (Contributor role)
2. Azure DevOps service connection using that service principal
3. Store credentials in Key Vault

**Your Setup**:
1. Receive service principal credentials
2. Configure Azure DevOps service connection (or verify Platform Team configuration)
3. Use service connection in pipelines (see Azure DevOps Service Connection documentation)

### Multi-Environment Setup

**Request separate service principals per environment**:
- **Development**: `myapp-dev-sp` with Contributor role, 180-day rotation
- **Staging**: `myapp-staging-sp` with Contributor role, 90-day rotation
- **Production**: `myapp-prod-sp` with Contributor role, 60-day rotation

**Benefits**:
- Isolated credentials per environment
- Different rotation schedules based on risk
- Easier to revoke access to specific environments
- Better audit trail

## 📚 Related Documentation

- [Entra ID Service Principals](https://learn.microsoft.com/en-us/entra/identity-platform/app-objects-and-service-principals)
- [Azure RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Best Practices for Service Principals](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal)
- [Credential Management](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal#option-3-create-a-new-client-secret)
