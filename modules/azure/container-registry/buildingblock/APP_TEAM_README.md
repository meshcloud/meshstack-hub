# Azure Container Registry (ACR)

## Description
This building block provides a production-grade Azure Container Registry (ACR) for storing and managing Docker container images and OCI artifacts. It delivers a fully managed and secure container registry with support for both public and private deployments, optional hub connectivity, and seamless integration with Azure Kubernetes Service (AKS).

## Usage Motivation
This building block is for application teams that need a secure and reliable container registry to store Docker images, Helm charts, and other OCI artifacts. The ACR comes pre-configured with enterprise-grade security features including private endpoints, network access controls, and Azure AD authentication, eliminating the complexity of managing container registries while ensuring compliance with security policies.

## 🚀 Usage Examples
- A development team stores and versions Docker images for microservices applications
- A CI/CD pipeline pushes built container images to ACR and deploys them to AKS clusters
- A security team implements content trust and vulnerability scanning for container images
- A data science team stores and manages ML model containers and training environments

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|--------------|------------------|
| Provisioning and configuring the ACR | ✅ | ❌ |
| Managing network configuration and private endpoints | ✅ | ❌ |
| Setting up hub network peering (for private ACR) | ✅ | ❌ |
| Managing IAM roles and permissions | ✅ | ❌ |
| Pushing and managing container images | ❌ | ✅ |
| Implementing image tagging strategies | ❌ | ✅ |
| Scanning images for vulnerabilities | ❌ | ✅ |
| Managing image retention and cleanup | ❌ | ✅ |
| Integrating ACR with CI/CD pipelines | ❌ | ✅ |

## 💡 Best Practices for Secure and Efficient ACR Usage

### Security
- **Use Azure AD authentication**: Always use Azure AD (via `az acr login`) instead of admin credentials
- **Disable admin user**: Set `admin_enabled = false` in production to enforce Azure AD authentication
- **Enable content trust**: For Premium SKU, enable content trust to sign and verify images
- **Scan for vulnerabilities**: Integrate with Microsoft Defender for Containers or third-party scanners
- **Use private endpoints**: Deploy private ACR for production workloads to prevent internet exposure
- **Implement network rules**: Restrict access using IP allowlists when public access is required
- **Rotate credentials**: If using service principals, rotate credentials regularly

### Image Management
- **Use semantic versioning**: Tag images with semantic versions (e.g., `v1.2.3`) for better tracking
- **Avoid latest tag**: Always use specific version tags in production deployments
- **Implement retention policies**: Configure retention policies to automatically remove untagged manifests
- **Use multi-stage builds**: Optimize Dockerfile with multi-stage builds to reduce image size
- **Minimize layers**: Combine RUN commands to reduce the number of layers
- **Scan before push**: Scan images locally before pushing to ACR

### Performance & Reliability
- **Use dedicated data endpoints**: Enable data endpoints in Premium SKU for improved performance
- **Enable zone redundancy**: For high availability, enable zone redundancy in supported regions
- **Monitor registry metrics**: Track storage usage, pull/push operations, and throttling in Azure Monitor
- **Use caching**: Implement image pull caching in AKS for faster pod startup times

### Cost Optimization
- **Choose appropriate SKU**: Start with Standard for development, use Premium only when needed
- **Implement cleanup policies**: Remove old and unused images automatically
- **Monitor storage usage**: Regularly review storage consumption and clean up unnecessary images
- **Use retention policies**: Configure retention days to auto-delete untagged manifests
- **Optimize image sizes**: Smaller images reduce storage costs and improve pull performance

### CI/CD Integration
- **Use service principals or managed identities**: Authenticate CI/CD pipelines using Azure AD
- **Implement automated scanning**: Scan images as part of CI/CD pipeline
- **Tag with build metadata**: Include git commit SHA, build number in image tags
- **Use webhooks**: Configure ACR webhooks to trigger deployments or notifications
- **Implement approval gates**: Require security scan approval before production deployment

## Registry Features

### SKU Comparison

| Feature | Basic | Standard | Premium |
|---------|-------|----------|---------|
| Storage (GB) | 10 | 100 | 500 |
| Webhooks | 2 | 10 | 500 |
| Private endpoints | ❌ | ❌ | ✅ |
| Content trust | ❌ | ❌ | ✅ |
| Customer-managed keys | ❌ | ❌ | ✅ |
| Zone redundancy | ❌ | ❌ | ✅ |
| Retention policies | ❌ | ❌ | ✅ |

### Security Features
- **Azure AD Authentication**: Native integration with Azure Active Directory
- **RBAC**: Fine-grained role-based access control (AcrPull, AcrPush, AcrDelete)
- **Network Isolation**: Private endpoints with Private DNS integration
- **Content Trust**: Sign and verify container images (Premium SKU)
- **Vulnerability Scanning**: Integration with Microsoft Defender for Containers
- **Firewall Rules**: IP-based access control and VNet service endpoints

### Network Options
- **Public Access**: Internet-accessible registry with optional IP filtering
- **Private Endpoint**: Private IP address within your VNet (Premium SKU)
- **Hub Connectivity**: VNet peering to central hub for on-premises access
- **Service Endpoints**: VNet service endpoints for controlled access

### High Availability
- **Zone Redundancy**: Deploy across availability zones (Premium SKU, select regions)
- **SLA**: 99.9% uptime SLA for Standard and Premium SKUs

## Deployment Scenarios

### Scenario Matrix

This building block supports 4 deployment scenarios based on your networking and security requirements:

| # | Scenario | Private Endpoint | VNet Type | Hub Peering | Use Case |
|---|----------|-----------------|-----------|-------------|----------|
| **1** | **New VNet + Hub Peering** | ✅ | New (created) | ✅ Created | Isolated workload needing hub/on-prem access |
| **2** | **Existing Shared VNet** | ✅ | Existing (shared) | ❌ Skipped | Multi-tenant with shared connectivity |
| **3** | **Private Isolated** | ✅ | New or Existing | ❌ None | Secure workload, same-VNet access only |
| **4** | **Completely Public** | ❌ | Not applicable | ❌ None | Dev/test, public CI/CD access |

**Configuration Quick Reference:**

| Scenario | `private_endpoint_enabled` | `vnet_name` | `hub_vnet_name` |
|----------|---------------------------|-------------|-----------------|
| **1 - New VNet + Hub** | `true` | `null` | Set (creates peering) |
| **2 - Existing Shared VNet** | `true` | Set (existing) | Omit/null (no peering) |
| **3 - Private Isolated** | `true` | `null` or Set | `null` |
| **4 - Public** | `false` | Any | Any |

---

## Getting Started

### Authenticating with ACR

#### Using Azure CLI (Recommended)
```bash
# Login to ACR using Azure AD
az acr login --name mycompanyacr

# Verify login
docker images
```

#### Using Docker with Admin Credentials (Not Recommended for Production)
```bash
# Get admin credentials (only if admin_enabled = true)
az acr credential show --name mycompanyacr

# Docker login with username/password
docker login mycompanyacr.azurecr.io -u <username> -p <password>
```

#### Using Managed Identity (AKS)
```bash
# AKS automatically authenticates using its managed identity
# No manual login required when AcrPull role is assigned
kubectl create deployment nginx --image=mycompanyacr.azurecr.io/nginx:latest
```

### Pushing Images

```bash
# Tag your image
docker tag myapp:latest mycompanyacr.azurecr.io/myapp:v1.0.0

# Push to ACR
docker push mycompanyacr.azurecr.io/myapp:v1.0.0

# List images in ACR
az acr repository list --name mycompanyacr
```

### Pulling Images

```bash
# Pull image from ACR
docker pull mycompanyacr.azurecr.io/myapp:v1.0.0

# From AKS
kubectl run myapp --image=mycompanyacr.azurecr.io/myapp:v1.0.0
```

### Working with Private ACR

For private ACR, ensure you have network connectivity:

1. **From Azure Resources**: Must be in peered VNet or same VNet as private endpoint
2. **From On-Premises**: Connect via hub VNet using ExpressRoute or VPN Gateway
3. **From Developer Workstation**: Use VPN or Azure Bastion to access private network

```bash
# Connect via VPN or Bastion, then login
az acr login --name mycompanyacr

# Verify private endpoint resolution
nslookup mycompanyacr.azurecr.io
# Should resolve to private IP (10.x.x.x)
```

### Managing Images

```bash
# List repositories
az acr repository list --name mycompanyacr

# List tags for a repository
az acr repository show-tags --name mycompanyacr --repository myapp

# Delete an image
az acr repository delete --name mycompanyacr --image myapp:v1.0.0

# Purge old images (older than 30 days)
az acr run --cmd "acr purge --filter 'myapp:.*' --ago 30d" --registry mycompanyacr /dev/null
```

### Monitoring and Troubleshooting

```bash
# View ACR metrics
az monitor metrics list --resource <acr-resource-id> --metric StorageUsed

# Check ACR health
az acr check-health --name mycompanyacr

# View webhook events
az acr webhook list-events --name mywebhook --registry mycompanyacr

# Enable diagnostic logs
az monitor diagnostic-settings create \
  --resource <acr-resource-id> \
  --name acr-diagnostics \
  --workspace <log-analytics-workspace-id> \
  --logs '[{"category": "ContainerRegistryRepositoryEvents", "enabled": true}]'
```

## Security Checklist

- [ ] Disable admin user (`admin_enabled = false`)
- [ ] Use Azure AD authentication exclusively
- [ ] Enable private endpoint for production workloads
- [ ] Configure network access rules (IP allowlist or private endpoint)
- [ ] Enable content trust for Premium SKU
- [ ] Implement vulnerability scanning in CI/CD pipeline
- [ ] Configure retention policies to clean up old images
- [ ] Enable diagnostic logging to Log Analytics
- [ ] Use managed identities for AKS integration
- [ ] Implement RBAC with least-privilege access
- [ ] Enable Microsoft Defender for Containers
- [ ] Regularly rotate service principal credentials (if used)

## Common Integration Patterns

### CI/CD Pipeline (Azure DevOps)
```yaml
- task: Docker@2
  inputs:
    command: buildAndPush
    repository: myapp
    containerRegistry: mycompanyacr
    tags: |
      $(Build.BuildId)
      latest
```

### GitHub Actions
```yaml
- name: Login to ACR
  uses: azure/docker-login@v1
  with:
    login-server: mycompanyacr.azurecr.io
    username: ${{ secrets.ACR_USERNAME }}
    password: ${{ secrets.ACR_PASSWORD }}

- name: Build and push
  run: |
    docker build -t mycompanyacr.azurecr.io/myapp:${{ github.sha }} .
    docker push mycompanyacr.azurecr.io/myapp:${{ github.sha }}
```

### Kubernetes Deployment
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
spec:
  template:
    spec:
      containers:
      - name: myapp
        image: mycompanyacr.azurecr.io/myapp:v1.0.0
```
