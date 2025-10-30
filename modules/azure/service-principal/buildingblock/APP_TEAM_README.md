# Azure Service Principal

This building block creates a service principal in Azure Entra ID (formerly Azure Active Directory) with role-based access to your Azure subscription. Service principals are used for automated authentication and authorization in CI/CD pipelines, applications, and automation scripts.

## 🚀 Usage Examples

- A development team creates a service principal to **automate deployments** from their CI/CD pipelines to Azure resources.
- A DevOps engineer sets up separate service principals for **development, staging, and production** environments with appropriate permissions.
- A team configures a read-only service principal for **monitoring and compliance tools** that need to scan infrastructure without making changes.
- A team uses **workload identity federation (OIDC)** with GitHub Actions or Azure DevOps to authenticate without managing secrets.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create service principal | ✅ | ❌ |
| Assign Azure roles to service principal | ✅ | ❌ |
| Choose authentication method (secret vs OIDC) | ⚠️ | ⚠️ |
| Provide service principal credentials (if using secrets) | ✅ | ❌ |
| Configure federated identity (if using OIDC) | ✅ | ❌ |
| Store client secret securely (if using secrets) | ❌ | ✅ |
| Use service principal in pipelines/applications | ❌ | ✅ |
| Monitor secret expiration (if using secrets) | ❌ | ✅ |
| Request secret rotation before expiration (if using secrets) | ❌ | ✅ |
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

## 🔐 Authentication Methods

Service principals support two authentication methods. Choose based on your use case:

### Method 1: Client Secret (Traditional)

**How it works**: A password is generated and used for authentication.

**Best for**:
- Legacy applications
- Environments without OIDC support
- Simple script-based automation

**Limitations**:
- Secrets expire and require rotation
- Secrets must be stored securely
- Risk of secret exposure

### Method 2: Workload Identity Federation (OIDC) - Recommended

**How it works**: Uses OpenID Connect tokens from trusted identity providers (GitHub, Azure DevOps, etc.) without storing secrets.

**Best for**:
- GitHub Actions workflows
- Azure DevOps pipelines
- GitLab CI/CD
- Modern cloud-native applications

**Benefits**:
- ✅ No secrets to manage or rotate
- ✅ Automatic token rotation
- ✅ Reduced security risk
- ✅ Simplified credential management
- ✅ Audit trail tied to identity provider

**Request from Platform Team**: "Please create a service principal with workload identity federation for GitHub Actions" (or your platform)

## 📝 Receiving Service Principal Credentials

### For Client Secret Authentication

After the Platform Team creates your service principal, you'll receive:
- **Client ID** (Service Principal ID / Application ID)
- **Client Secret** (Password)
- **Tenant ID** (Azure AD Directory ID)
- **Subscription ID** (Target Azure subscription)

**Store these values securely immediately** - the client secret cannot be retrieved again without rotation.

### For Workload Identity Federation (OIDC)

After the Platform Team configures your service principal, you'll receive:
- **Client ID** (Service Principal ID / Application ID)
- **Tenant ID** (Azure AD Directory ID)
- **Subscription ID** (Target Azure subscription)
- Federated credential configuration details (issuer, subject, audience)

**No secrets to store** - authentication uses short-lived tokens from your CI/CD platform.

## 🔐 Using Service Principal for Authentication

### With Client Secret

#### Azure CLI

```bash
az login --service-principal \
  --username <service_principal_id> \
  --password <client_secret> \
  --tenant <tenant_id>
```

#### Terraform

```hcl
provider "azurerm" {
  features {}

  client_id       = var.service_principal_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id
}
```

#### GitHub Actions (with secrets)

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

### With Workload Identity Federation (OIDC)

#### GitHub Actions (recommended)

```yaml
name: Deploy to Azure

on:
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Azure Login with OIDC
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Azure CLI commands
        run: |
          az account show
          az group list
```

**Key differences**:
- ✅ No `client-secret` needed
- ✅ Must set `permissions: id-token: write`
- ✅ GitHub generates short-lived tokens automatically

#### Azure DevOps Pipelines (recommended)

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - task: AzureCLI@2
    inputs:
      azureSubscription: 'MyServiceConnection'  # Uses OIDC
      scriptType: 'bash'
      scriptLocation: 'inlineScript'
      inlineScript: |
        az account show
        az group list
```

**Service connection is configured by Platform Team with OIDC** - no secrets in Azure DevOps.

#### Terraform with OIDC

```hcl
provider "azurerm" {
  features {}

  use_oidc        = true
  client_id       = var.service_principal_id
  tenant_id       = var.tenant_id
  subscription_id = var.subscription_id

  # OIDC token automatically provided by CI/CD platform
}
```

## 🔄 Secret Rotation Process

**Note**: This section only applies to service principals using **client secret authentication**. Service principals using **workload identity federation (OIDC)** do not require secret rotation.

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

**Consider migrating to OIDC** to eliminate secret rotation requirements.

## ⚠️ Important Notes

### Authentication Method Choice

- **Prefer OIDC** for GitHub Actions, Azure DevOps, and modern CI/CD platforms
- **Use client secrets** only for legacy systems or when OIDC is not supported
- Discuss authentication method with Platform Team during request

### Client Secret Authentication

- **Save credentials immediately** - client secrets cannot be retrieved after initial provisioning
- Secret rotation must be requested from Platform Team before expiration
- Old secrets are automatically revoked after rotation

### OIDC Authentication

- No secrets to store or rotate
- Requires federated credential configuration by Platform Team
- Must include `permissions: id-token: write` in workflows (GitHub Actions)
- Subject claims must match your repository/project configuration

### General

- Service principal names should be descriptive and follow naming conventions
- Role assignments are at subscription scope
- Common roles: Owner, Contributor, Reader (request appropriate level)
- Always use separate service principals per environment (dev, staging, prod)

## 🆘 Troubleshooting

### Secret expired (Client Secret Authentication)

**Cause**: Secret has passed expiration date

**Solution**:
1. Contact Platform Team immediately to request emergency rotation
2. Provide list of affected services for impact assessment
3. Receive new credentials from Platform Team
4. Update all services using the credential as quickly as possible

**Prevention**: Migrate to workload identity federation (OIDC) to eliminate secret expiration.

### Service principal authentication fails

**Cause**: Multiple possible causes

**Solution**:

**For Client Secret Authentication**:
1. Verify client ID, tenant ID, and secret are correct
2. Check if secret has expired (contact Platform Team)
3. Verify you're authenticating to the correct subscription
4. Ensure service principal has required role assignment
5. Contact Platform Team to verify service principal status

**For OIDC Authentication**:
1. Verify `permissions: id-token: write` is set in workflow (GitHub Actions)
2. Confirm client ID and tenant ID are correct
3. Check federated credential configuration with Platform Team
4. Verify issuer and subject claims match your CI/CD platform
5. Ensure service principal has required role assignment
6. Review CI/CD platform logs for token generation errors

### OIDC token validation fails

**Cause**: Federated credential misconfiguration

**Common Issues**:
- **GitHub**: Subject claim doesn't match repository/branch/environment
- **Azure DevOps**: Service connection not configured for workload identity federation
- **Issuer mismatch**: Federated credential issuer doesn't match token issuer

**Solution**:
1. Contact Platform Team with error message
2. Verify workflow/pipeline configuration matches federated credential
3. Check subject claim format for your platform:
   - GitHub: `repo:<org>/<repo>:ref:refs/heads/<branch>`
   - Azure DevOps: `sc://<org>/<project>/<service-connection-name>`

### Need to remove service principal

**Cause**: Service principal no longer needed

**Solution**:
1. Document all locations where credentials are used
2. Remove credentials from all pipelines and applications
3. Contact Platform Team to request service principal deletion
4. Confirm no services are affected after removal

## 📊 Monitoring Secret Expiration

**Note**: This section only applies to service principals using **client secret authentication**. Service principals using **workload identity federation (OIDC)** automatically rotate tokens and do not require monitoring.

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

**Recommendation**: Maintain an inventory of where each service principal is used for quick rotation, or migrate to OIDC to eliminate this overhead.

## 🔗 Common Integration Patterns

### Pattern 1: GitHub Actions with OIDC (Recommended)

**Request from Platform Team**:
1. Service principal with **workload identity federation** for GitHub
2. Contributor role on target subscription
3. Federated credential configured for your repository

**Example Request**: "Please create a service principal with OIDC for `myorg/myrepo` repository with Contributor access"

**Your Setup**:
1. Receive client ID, tenant ID, subscription ID
2. Add as GitHub repository secrets:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
3. Use in workflows (see OIDC examples above)

**Benefits**:
- ✅ No secrets to manage
- ✅ Automatic token rotation
- ✅ GitHub's identity system provides audit trail

### Pattern 2: Azure DevOps with OIDC (Recommended)

**Request from Platform Team**:
1. Service principal with **workload identity federation** for Azure DevOps
2. Service connection configured with OIDC
3. Contributor role on target subscription

**Example Request**: "Please create an Azure DevOps service connection with OIDC for `myproject` with Contributor access"

**Your Setup**:
1. Platform Team configures service connection
2. Use service connection name in pipelines
3. No credentials to store in Azure DevOps

**Benefits**:
- ✅ Seamless pipeline integration
- ✅ No secret management
- ✅ Azure DevOps manages token lifecycle

### Pattern 3: Legacy CI/CD with Client Secrets

**Request from Platform Team**:
1. Service principal with **client secret authentication**
2. Contributor role on target subscription
3. Store credentials in Key Vault (recommended)

**Your Setup**:
1. Receive service principal credentials
2. Store in secret management system
3. Configure CI/CD platform with credentials
4. Monitor expiration and rotate before deadline

**Use when**:
- Platform doesn't support OIDC
- Legacy automation scripts
- Temporary/prototype setups

**Consider migrating to OIDC** when possible.

### Pattern 4: Multi-Environment Setup

**With OIDC (Recommended)**:
Request separate service principals per environment:
- **Development**: `myapp-dev-sp` with OIDC, Contributor role
- **Staging**: `myapp-staging-sp` with OIDC, Contributor role
- **Production**: `myapp-prod-sp` with OIDC, Contributor role

**With Client Secrets (If OIDC Not Available)**:
- **Development**: `myapp-dev-sp` with Contributor role, 180-day rotation
- **Staging**: `myapp-staging-sp` with Contributor role, 90-day rotation
- **Production**: `myapp-prod-sp` with Contributor role, 60-day rotation

**Benefits**:
- Isolated identities per environment
- Easier to revoke access to specific environments
- Better audit trail
- Different security policies per environment

### Pattern 5: Read-Only Monitoring

**Request from Platform Team**:
1. Service principal with Reader role
2. OIDC (if monitoring runs in CI/CD) or client secret (if external tool)

**Use Cases**:
- Cost analysis dashboards
- Compliance scanning tools
- Infrastructure monitoring
- Security auditing tools

## 📚 Related Documentation

- [Entra ID Service Principals](https://learn.microsoft.com/en-us/entra/identity-platform/app-objects-and-service-principals)
- [Azure RBAC Roles](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles)
- [Best Practices for Service Principals](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal)
- [Credential Management](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal#option-3-create-a-new-client-secret)
