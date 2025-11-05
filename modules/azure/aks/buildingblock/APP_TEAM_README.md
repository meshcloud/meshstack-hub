# Azure Kubernetes Service (AKS)

## Description
This building block provides a production-grade Azure Kubernetes Service (AKS) cluster with integrated security, monitoring, and networking features. It delivers a fully managed Kubernetes environment with Azure AD authentication, workload identity support, and comprehensive observability through Log Analytics. The cluster supports both public and private deployment scenarios with optional hub-and-spoke network connectivity.

## Usage Motivation
This building block is for application teams that need to deploy containerized applications on a secure, scalable, and managed Kubernetes platform. The AKS cluster comes pre-configured with enterprise-grade security features, eliminating the operational complexity of managing Kubernetes infrastructure while maintaining the flexibility to run any containerized workload.

## 🚀 Usage Examples
- A development team deploys microservices-based applications using Kubernetes deployments, services, and ingress controllers.
- A data engineering team runs distributed data processing workloads using Kubernetes jobs and cron jobs.
- An operations team manages multi-tenant applications with namespace isolation and resource quotas.
- A DevOps team implements GitOps-based continuous deployment pipelines targeting the AKS cluster.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|--------------|-----------------|
| Provisioning and configuring the AKS cluster | ✅ | ❌ |
| Managing cluster upgrades and patches | ✅ | ❌ |
| Configuring Azure AD authentication and RBAC | ✅ | ❌ |
| Setting up Log Analytics and monitoring infrastructure | ✅ | ❌ |
| Managing virtual network and subnet configuration | ✅ | ❌ |
| Managing hub network peering (for private clusters) | ✅ | ❌ |
| Deploying and managing applications and workloads | ❌ | ✅ |
| Configuring application-level resource limits and quotas | ❌ | ✅ |
| Managing Kubernetes namespaces and RBAC within the cluster | ❌ | ✅ |
| Monitoring application performance and logs | ❌ | ✅ |
| Implementing application security policies (Network Policies, Pod Security) | ❌ | ✅ |

## 💡 Best Practices for Secure and Efficient AKS Usage

### Security
- **Use Workload Identity**: Leverage Azure AD Workload Identity for secure authentication to Azure resources without storing credentials
- **Implement Network Policies**: Define Kubernetes Network Policies to control pod-to-pod communication
- **Enable Pod Security Standards**: Apply Kubernetes Pod Security Standards to enforce security best practices
- **Use Azure Key Vault**: Store secrets in Azure Key Vault and inject them into pods using CSI Secret Store driver
- **Scan container images**: Regularly scan container images for vulnerabilities before deployment

### Performance & Scalability
- **Set resource requests and limits**: Always define CPU and memory requests/limits for predictable scheduling and resource management
- **Use Horizontal Pod Autoscaler (HPA)**: Implement HPA to automatically scale applications based on metrics
- **Optimize container images**: Use multi-stage builds and minimal base images to reduce image size and startup time
- **Implement health probes**: Configure liveness and readiness probes for reliable application health monitoring

### Operations & Monitoring
- **Use structured logging**: Implement structured logging (JSON) for better log analysis in Log Analytics
- **Monitor cluster metrics**: Regularly review cluster metrics in Azure Monitor for capacity planning
- **Implement GitOps**: Use GitOps tools like Flux or ArgoCD for declarative application deployment
- **Tag resources**: Use labels and annotations consistently for resource organization and cost allocation

### Networking
- **Use Ingress controllers**: Deploy an Ingress controller for HTTP/HTTPS routing instead of multiple LoadBalancer services
- **Implement egress control**: Use Azure Firewall or Network Security Groups to control outbound traffic
- **Enable service mesh**: Consider using a service mesh (like Istio or Linkerd) for advanced traffic management and observability

## Cluster Features

### Authentication & Authorization
- **Azure AD Integration**: Cluster uses Azure AD for authentication, enabling centralized identity management (optional)
- **OIDC Issuer**: Workload Identity enabled for secure pod-to-Azure-resource authentication

### Monitoring & Logging
- **Log Analytics Workspace**: Centralized logging for cluster and application logs (optional)
- **Container Insights**: Integrated monitoring for container performance and health
- **Diagnostic Settings**: Cluster metrics and logs forwarded to Log Analytics

### Networking
- **Flexible VNet Options**:
  - Create new VNet and subnet automatically (default)
  - Use existing VNet and subnet (for shared platform networking)
- **Azure CNI**: Advanced networking capabilities with pod-level networking
- **Private Cluster**: Optional private API server accessible only via private endpoint
- **Hub Connectivity**: Optional VNet peering to central hub network for on-premises connectivity
  - Only created when deploying with new VNet (`vnet_name == null`)
  - Use existing VNet scenario for centrally-managed peering

### Auto-Scaling
- **Cluster Autoscaler**: Automatically adjusts node count based on resource requirements (when enabled)
- **System Node Pool**: Dedicated node pool for system workloads with optional auto-scaling

## Configuration Variables

### Networking Configuration

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `vnet_name` | Name of existing VNet to use. If `null`, creates new VNet. | No | `null` (creates new) |
| `existing_vnet_resource_group_name` | Resource group of existing VNet. Only used when `vnet_name` is provided. | No | Same as AKS RG |
| `subnet_name` | Name of existing subnet to use. If `null`, creates new subnet. | No | `null` (creates new) |
| `vnet_address_space` | Address space for new VNet. Only used when `vnet_name == null`. | No | `10.240.0.0/16` |
| `subnet_address_prefix` | Address prefix for new subnet. Only used when `subnet_name == null`. | No | `10.240.0.0/20` |
| `allow_gateway_transit_from_hub` | Allow gateway transit from hub for on-premises connectivity. | No | `false` |

### Hub Connectivity (for Private Clusters)

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `hub_subscription_id` | Subscription ID of hub network. Required for hub peering. | Conditional | `null` |
| `hub_resource_group_name` | Resource group of hub VNet. Required for hub peering. | Conditional | `null` |
| `hub_vnet_name` | Name of hub VNet to peer with. Set to `null` to disable peering. | No | `null` |

**Note:** Hub peering is **only created when `vnet_name == null`** (new VNet scenario). If using an existing VNet, peering must be managed externally.

## Getting Started

### Public Cluster
1. **Access the cluster**: Use `az aks get-credentials --resource-group <rg> --name <cluster-name>` to configure kubectl access
2. **Verify connectivity**: Run `kubectl get nodes` to confirm cluster connectivity
3. **Deploy your application**: Use `kubectl apply` or Helm to deploy applications
4. **Monitor your workloads**: View logs and metrics in Azure Monitor or Log Analytics

### Private Cluster
1. **Ensure network connectivity**: Access must be from a network peered with the AKS VNet or the hub network
2. **Access the cluster**: Use `az aks get-credentials --resource-group <rg> --name <cluster-name>` from a machine with network access
3. **Use Azure Bastion or VPN**: Connect via Azure Bastion, VPN Gateway, or ExpressRoute for management access
4. **Verify connectivity**: Run `kubectl get nodes` to confirm cluster connectivity
5. **Deploy your application**: Use `kubectl apply` or Helm to deploy applications
6. **Monitor your workloads**: View logs and metrics in Azure Monitor or Log Analytics
