# Kubernetes Service Account

This building block creates a Kubernetes service account in your namespace with role-based access to cluster resources. Service accounts are used for automated authentication and authorization in CI/CD pipelines, applications, and automation scripts running within or outside the cluster.

## 🚀 Usage Examples

- A development team creates a service account to **automate deployments** from their CI/CD pipelines to Kubernetes resources.
- A DevOps engineer sets up service accounts with **view access** for monitoring tools that need to observe cluster state.
- A team configures a service account with **edit permissions** for their application to manage resources within their namespace.
- An operations team uses the generated **kubeconfig** to configure external tools like ArgoCD or Flux.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create service account | ✅ | ❌ |
| Assign ClusterRole to service account | ✅ | ❌ |
| Provide kubeconfig credentials | ✅ | ❌ |
| Store kubeconfig securely | ❌ | ✅ |
| Use service account in pipelines/applications | ❌ | ✅ |
| Monitor service account usage | ✅ | ✅ |
| Use least privilege roles | ⚠️ | ✅ |
| Request removal of unused service accounts | ❌ | ✅ |

## 💡 Best Practices

### Service Account Naming

**Why**: Clear names help identify purpose and ownership.

**Recommended Patterns**:
- Include application/service name: `myapp-production-sa`
- Include purpose: `myapp-cicd-sa`, `myapp-monitoring-sa`
- Include environment: `myapp-dev-sa`, `myapp-prod-sa`

**Examples**:
- ✅ `ecommerce-prod-deployment-sa`
- ✅ `analytics-monitoring-sa`
- ✅ `backup-automation-sa`
- ❌ `sa1`
- ❌ `test-service-account`

### Role Selection

**Why**: Follow least privilege principle to minimize security risks.

| Role | Use Case |
|------|----------|
| `view` | Read-only access for monitoring, dashboards, debugging |
| `edit` | Deploy and manage applications within namespace |
| `admin` | Full namespace administration including RBAC |

**Recommendations**:
- Start with `view` and escalate only if needed
- Use `edit` for CI/CD pipelines that deploy applications
- Reserve `admin` for tools that need to manage RBAC or other privileged resources

### Kubeconfig Management

**Why**: The kubeconfig contains sensitive credentials that grant access to your namespace.

**Best Practices**:
- Store kubeconfig in a secure secrets manager (HashiCorp Vault, AWS Secrets Manager, etc.)
- Never commit kubeconfig to version control
- Rotate service account tokens periodically
- Use short-lived tokens where possible

**Example Usage**:
```bash
# Save kubeconfig to a file
echo "$KUBECONFIG_CONTENT" > kubeconfig

# Use with kubectl
kubectl --kubeconfig kubeconfig get pods

# Or set KUBECONFIG environment variable
export KUBECONFIG=./kubeconfig
kubectl get pods
```

### CI/CD Integration

**GitHub Actions Example**:
```yaml
steps:
  - name: Configure kubectl
    run: |
      echo "${{ secrets.KUBECONFIG }}" > kubeconfig
      kubectl --kubeconfig kubeconfig apply -f k8s/
```

**GitLab CI Example**:
```yaml
deploy:
  script:
    - echo "$KUBECONFIG" > kubeconfig
    - kubectl --kubeconfig kubeconfig apply -f k8s/
```

## ⚠️ Security Considerations

### Token Security

- The service account token provides **long-lived** access to the cluster
- Anyone with the kubeconfig can access resources according to the assigned role
- Treat the kubeconfig as a secret credential

### Namespace Isolation

- The role binding is **namespace-scoped**
- The service account cannot access resources in other namespaces
- Cross-namespace access requires additional configuration

### Audit and Monitoring

- All actions performed by the service account are **logged in Kubernetes audit logs**
- Work with your platform team to set up **alerting** for suspicious activity
- Regularly review service account usage and remove unused accounts

## 📋 Troubleshooting

### Common Issues

**"Forbidden" errors when using kubectl**:
- Verify the assigned ClusterRole has the required permissions
- Check if you're operating in the correct namespace
- Ensure the kubeconfig context is set correctly

**Token not working**:
- Verify the secret was created correctly
- Check if the service account exists
- Ensure the cluster CA certificate is correct

**Unable to connect to cluster**:
- Verify the cluster endpoint is reachable from your network
- Check firewall rules and network policies
- Ensure the cluster CA certificate matches the cluster

### Getting Help

Contact your platform team if you:
- Need elevated permissions beyond `edit`
- Require access to cluster-wide resources
- Experience persistent authentication issues
- Need to rotate or regenerate credentials
