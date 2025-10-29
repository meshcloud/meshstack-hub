# Azure Virtual Machine Scale Set

## Description
This building block provides Azure Virtual Machine Scale Sets for deploying horizontally scalable compute workloads. VMSS automatically manages the creation, configuration, and distribution of VM instances across availability zones, with built-in autoscaling and load balancing capabilities.

## Usage Motivation
This building block is for application teams that need scalable, highly available compute infrastructure for stateless applications like web servers, API backends, batch processing, or containerized workloads. VMSS eliminates the need to manually manage individual VMs while providing automatic scaling based on demand.

## 🚀 Usage Examples

### Web Application with Load Balancer
Deploy a web application that automatically scales based on CPU usage and distributes traffic across instances:

```hcl
module "web_app_vmss" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "webapp-vmss"
  resource_group_name = "rg-webapp-prod"
  location            = "West Europe"
  sku                 = "Standard_D2s_v3"

  os_type         = "Linux"
  admin_username  = "webadmin"
  ssh_public_key  = file("~/.ssh/id_rsa.pub")

  vnet_address_space    = "10.10.0.0/16"
  subnet_address_prefix = "10.10.1.0/24"

  enable_autoscaling        = true
  autoscale_min             = 2
  autoscale_max             = 10
  autoscale_default         = 3
  cpu_scale_out_threshold   = 70
  cpu_scale_in_threshold    = 30

  enable_load_balancer  = true
  enable_public_ip      = true
  health_probe_protocol = "Http"
  health_probe_port     = 80
  health_probe_path     = "/health"

  lb_rules = [
    {
      name          = "http"
      protocol      = "Tcp"
      frontend_port = 80
      backend_port  = 80
    }
  ]

  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "Hello from $(hostname)" > /var/www/html/index.html
    systemctl start nginx
  EOT
  )

  tags = {
    Environment = "Production"
    Application = "WebApp"
  }
}
```

**Use Case:** Hosting a public-facing web application that needs to handle variable traffic with automatic scaling.

### Cost-Optimized Batch Processing
Deploy a batch processing cluster using spot instances for significant cost savings:

```hcl
module "batch_processing" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "batch-vmss"
  resource_group_name = "rg-batch-processing"
  location            = "West Europe"
  sku                 = "Standard_F8s_v2"

  os_type         = "Linux"
  admin_username  = "batchuser"
  ssh_public_key  = var.ssh_public_key

  vnet_address_space    = "10.20.0.0/16"
  subnet_address_prefix = "10.20.1.0/24"

  enable_spot_instances = true
  spot_max_bid_price    = -1
  spot_eviction_policy  = "Deallocate"

  enable_autoscaling = true
  autoscale_min      = 0
  autoscale_max      = 50
  autoscale_default  = 5

  custom_data = base64encode(<<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    systemctl start docker
    systemctl enable docker
  EOT
  )

  tags = {
    Environment = "Production"
    Workload    = "BatchProcessing"
    CostOptimized = "true"
  }
}
```

**Use Case:** Running fault-tolerant batch jobs, data processing, or containerized workloads that can handle interruptions.

### Multi-Zone High Availability Deployment
Deploy a highly available application across multiple availability zones:

```hcl
module "ha_api_service" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "api-vmss"
  resource_group_name = "rg-api-prod"
  location            = "West Europe"
  sku                 = "Standard_D4s_v3"

  os_type         = "Linux"
  admin_username  = "apiuser"
  ssh_public_key  = var.ssh_public_key

  vnet_address_space    = "10.30.0.0/16"
  subnet_address_prefix = "10.30.1.0/24"

  zones        = ["1", "2", "3"]
  upgrade_mode = "Rolling"

  enable_autoscaling = true
  autoscale_min      = 6
  autoscale_max      = 30
  autoscale_default  = 9

  enable_load_balancer  = true
  enable_public_ip      = false
  health_probe_protocol = "Http"
  health_probe_port     = 8080
  health_probe_path     = "/api/health"

  lb_rules = [
    {
      name          = "api-https"
      protocol      = "Tcp"
      frontend_port = 443
      backend_port  = 8080
    }
  ]

  tags = {
    Environment       = "Production"
    HighAvailability = "true"
    Tier             = "API"
  }
}
```

**Use Case:** Critical API services requiring 99.99% uptime with automatic failover across zones.

### Windows-Based Application Server
Deploy Windows Server VMs for .NET applications:

```hcl
module "dotnet_app_vmss" {
  source = "./azure-vmss/buildingblock"

  vmss_name           = "dotnet-vmss"
  resource_group_name = "rg-dotnet-app"
  location            = "West Europe"
  sku                 = "Standard_D4s_v3"

  os_type        = "Windows"
  admin_username = "winadmin"
  admin_password = var.admin_password

  vnet_address_space    = "10.40.0.0/16"
  subnet_address_prefix = "10.40.1.0/24"

  image_publisher = "MicrosoftWindowsServer"
  image_offer     = "WindowsServer"
  image_sku       = "2022-Datacenter"
  image_version   = "latest"

  enable_autoscaling = true
  autoscale_min      = 2
  autoscale_max      = 8
  autoscale_default  = 3

  enable_load_balancer  = true
  enable_public_ip      = true
  health_probe_protocol = "Http"
  health_probe_port     = 80
  health_probe_path     = "/health"

  lb_rules = [
    {
      name          = "http"
      protocol      = "Tcp"
      frontend_port = 80
      backend_port  = 80
    }
  ]

  tags = {
    Environment = "Production"
    Platform    = ".NET"
  }
}
```

**Use Case:** Hosting ASP.NET applications or Windows-specific workloads with autoscaling.

## 🔄 Shared Responsibility Matrix

| Responsibility | Platform Team | Application Team |
|----------------|--------------|------------------|
| Provisioning VMSS infrastructure | ✅ | ❌ |
| Configuring networking (VNet, subnet, LB) | ✅ | ❌ |
| Setting up autoscaling rules | ✅ | ⚠️ (Provide requirements) |
| Managing VM images and OS updates | ⚠️ (Base images) | ✅ (Application-specific) |
| Installing and configuring applications | ❌ | ✅ |
| Monitoring VM health and performance | ⚠️ (Infrastructure) | ✅ (Application) |
| Managing application data and state | ❌ | ✅ |
| Configuring load balancer rules | ✅ | ⚠️ (Provide requirements) |
| Security patching and compliance | ⚠️ (OS baseline) | ✅ (Application) |
| Cost optimization and right-sizing | ⚠️ (Recommendations) | ✅ (Implementation) |
| Backup and disaster recovery | ❌ | ✅ |

## 💡 Best Practices

### Naming Conventions
- Use descriptive names: `{app}-{env}-vmss` (e.g., `webapp-prod-vmss`)
- Keep names short and DNS-compliant (lowercase, hyphens allowed)
- Include environment indicators: `dev`, `staging`, `prod`

### VM Sizing and Performance
- **Development/Test:** Standard_B2s, Standard_D2s_v3
- **Web Applications:** Standard_D2s_v3, Standard_D4s_v3
- **Compute-Intensive:** Standard_F4s_v2, Standard_F8s_v2
- **Memory-Intensive:** Standard_E4s_v3, Standard_E8s_v3
- Always start with smaller SKUs and scale up based on metrics

### Autoscaling Configuration
- **Minimum Instances:** Always keep at least 2 for high availability
- **Maximum Instances:** Set realistic limits based on budget and requirements
- **Scale-Out Threshold:** 70-75% CPU is typical for web workloads
- **Scale-In Threshold:** 25-30% CPU to avoid thrashing
- **Cooldown Period:** Default 5 minutes prevents rapid scaling
- Monitor autoscale actions in Azure Monitor to tune thresholds

### Load Balancer Configuration
- Use health probes to detect unhealthy instances
- HTTP probes should return 200 status code from a dedicated health endpoint
- TCP probes are simpler but less application-aware
- Configure appropriate probe intervals (15-30 seconds)
- Define multiple rules for different ports/protocols as needed

### Upgrade Strategies
- **Manual:** Full control, suitable for critical applications requiring careful testing
- **Automatic:** Fast updates, suitable for stateless, fault-tolerant applications
- **Rolling:** Gradual updates with minimal downtime, best for production (requires Standard LB)

### High Availability
- Deploy across 3 availability zones for 99.99% SLA
- Use Rolling upgrade mode with zone distribution
- Minimum 3 instances (one per zone) for zone-redundancy
- Consider Azure Site Recovery for disaster recovery

### Spot Instances
- **Ideal For:** Batch jobs, dev/test, stateless workloads, CI/CD agents
- **Avoid For:** Production services, databases, stateful applications
- Set `spot_max_bid_price = -1` to pay up to on-demand price
- Use `Deallocate` eviction policy to preserve disks
- Implement retry logic in applications to handle evictions

### Security Best Practices
- **Linux:** Always use SSH keys (password auth disabled by default)
- **Windows:** Use strong passwords (store in Key Vault)
- Use managed identity for Azure resource authentication
- Deploy Application Gateway or Azure Firewall for advanced security
- Implement NSG rules to restrict traffic
- Enable Azure Defender for Cloud for threat detection
- Rotate credentials regularly

### Cost Optimization
- Enable autoscaling to avoid paying for idle capacity
- Use spot instances for non-critical workloads (up to 90% savings)
- Right-size VMs based on actual usage metrics
- Use Standard_LRS for development environments
- Consider Reserved Instances for predictable workloads (up to 72% savings)
- Set appropriate scale-in thresholds to reduce costs during off-peak hours
- Tag resources for cost tracking and chargeback

### Stateless Design
- VMSS is designed for stateless applications
- Store data in external services (Azure Storage, databases)
- Use Azure Files or managed disks for shared data
- Implement health checks that don't rely on local state
- Design for instance failures and replacements

### Monitoring and Logging
- Enable Azure Monitor for VM insights
- Configure diagnostic settings for VMSS
- Monitor autoscale activity logs
- Set up alerts for:
  - Failed deployments
  - Unhealthy instances
  - Autoscale failures
  - Spot instance evictions
- Use Log Analytics for centralized logging

### Custom Data and Cloud-Init
- Use `custom_data` for bootstrap scripts
- Keep scripts idempotent (safe to run multiple times)
- Install configuration management tools (Ansible, Chef, Puppet)
- Store sensitive data in Key Vault, not in scripts
- Test scripts thoroughly before production deployment

### Network Configuration
- Use appropriate subnet sizing (consider future growth)
- /24 subnet supports ~250 instances
- For large-scale: use /22 or /21 subnets
- Consider using internal load balancer for backend services
- Use Azure Firewall or NAT Gateway for outbound internet access

## Common Pitfalls to Avoid

❌ **Not enabling autoscaling for variable workloads** → Over-provisioning or under-provisioning
✅ Enable autoscaling with appropriate thresholds

❌ **Using spot instances for critical workloads** → Service interruptions
✅ Use regular instances for production services

❌ **Insufficient health probe configuration** → Unhealthy instances receiving traffic
✅ Implement proper health checks in your application

❌ **Not using availability zones** → Lower availability SLA
✅ Deploy across zones for production workloads

❌ **Setting autoscale_min = 0** → Cold start delays
✅ Keep minimum of 1-2 instances warm

❌ **Using Manual upgrade mode in production** → Delayed updates
✅ Use Rolling upgrade mode for automated, safe updates

❌ **Storing state on VM instances** → Data loss during scaling
✅ Design stateless applications with external storage

❌ **Not monitoring autoscale activity** → Unexpected costs or performance issues
✅ Set up Azure Monitor alerts and review regularly

## Troubleshooting

### Issue: Instances not scaling automatically
**Symptoms:** VMSS stuck at current instance count despite CPU load
**Solutions:**
- Verify autoscaling is enabled (`enable_autoscaling = true`)
- Check Azure Monitor metrics are being collected
- Review autoscale activity logs in Azure Portal
- Ensure thresholds are appropriate (not too high/low)
- Verify sufficient time has passed since last scale action (cooldown)

### Issue: Load balancer health probe failures
**Symptoms:** Instances marked as unhealthy, traffic not distributed
**Solutions:**
- Verify application is listening on configured port
- For HTTP probes, ensure health endpoint returns 200 status
- Check NSG rules allow traffic from Azure Load Balancer (168.63.129.16/32)
- Review application logs for errors
- Test health probe endpoint manually from within subnet

### Issue: Spot instance frequent evictions
**Symptoms:** Instances constantly being deallocated/deleted
**Solutions:**
- Check Azure Spot pricing in your region
- Increase `spot_max_bid_price` if budget allows
- Choose less-constrained VM SKUs with better availability
- Consider hybrid deployment (regular + spot instances)
- Use `Deallocate` policy to preserve disks and reduce restart time

### Issue: Slow rolling upgrade
**Symptoms:** Upgrades taking longer than expected
**Solutions:**
- Verify load balancer health probes are responding quickly
- Check network connectivity between VMSS and health probe endpoint
- Review custom_data scripts for long-running operations
- Consider increasing max batch size (requires VMSS configuration changes)

### Issue: SSH/RDP connection failures
**Symptoms:** Unable to connect to VMSS instances
**Solutions:**
- For Linux: Verify SSH public key was provided correctly
- For Windows: Verify admin password is correct
- Check NSG rules allow inbound SSH (22) or RDP (3389)
- Ensure instances have network connectivity
- Use Azure Bastion for secure access without public IPs
- Check VMSS instance view for provisioning errors

### Issue: Custom_data script not executing
**Symptoms:** Application not installed/configured on instances
**Solutions:**
- Verify custom_data is base64encoded
- Check cloud-init logs: `/var/log/cloud-init.log` (Linux)
- Ensure script has proper shebang (`#!/bin/bash`)
- Test script locally before deploying
- Check for syntax errors in the script

## Integration Examples

### Using VMSS with Azure Key Vault
Access secrets using system-assigned managed identity:

```bash
# Get access token using managed identity
TOKEN=$(curl -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net" | jq -r .access_token)

# Retrieve secret from Key Vault
SECRET=$(curl -H "Authorization: Bearer $TOKEN" "https://myvault.vault.azure.net/secrets/mysecret?api-version=7.2" | jq -r .value)
```

Grant Key Vault access to VMSS identity:
```bash
az keyvault set-policy --name myvault \
  --object-id <vmss_principal_id> \
  --secret-permissions get list
```

### Using VMSS with Azure Container Registry
Pull container images using managed identity:

```bash
# Grant AcrPull role to VMSS identity
az role assignment create \
  --assignee <vmss_principal_id> \
  --role AcrPull \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>

# Login to ACR using managed identity
az acr login --name <acr-name> --identity
```

### Using VMSS with Azure Storage
Access storage using managed identity:

```bash
# Grant Storage Blob Data Reader role
az role assignment create \
  --assignee <vmss_principal_id> \
  --role "Storage Blob Data Reader" \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<storage-name>
```

## Next Steps

After deploying your VMSS:
1. Configure monitoring and alerts in Azure Monitor
2. Set up Log Analytics for centralized logging
3. Implement CI/CD pipelines for application updates
4. Configure backup strategy for any persistent data
5. Review and optimize autoscaling rules based on actual usage
6. Set up Azure Application Insights for application monitoring
7. Implement Azure Policy for governance and compliance
