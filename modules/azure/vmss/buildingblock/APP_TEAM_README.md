# Azure Virtual Machine Scale Set

This building block creates a Virtual Machine Scale Set (VMSS) in Azure - a service that enables you to deploy and manage a set of identical, auto-scaling virtual machines. Scale sets provide high availability and allow your application to automatically scale as demand changes.

## 📋 Prerequisites

Before deploying a VMSS, your Platform Team must have:

- **Existing Spoke VNet**: A spoke virtual network already deployed (typically created via the `spoke-network` module)
- **Subnet**: A dedicated subnet within the spoke VNet for the VMSS instances
- **Network Information**: The VNet name, subnet name, and resource group containing the network

**Why This Matters**: The VMSS follows Azure landing zone best practices by using an existing hub-spoke network topology managed centrally by the Platform Team. The VMSS does not create its own VNet—it deploys into existing network infrastructure.

## 🚀 Usage Examples

- A web application team uses VMSS with **autoscaling** to handle variable traffic loads automatically, scaling from 2 to 20 instances based on CPU usage.
- A development team deploys a **spot instance scale set** for batch processing jobs, saving 70-90% on compute costs for fault-tolerant workloads.
- A production application uses VMSS across **3 availability zones** with a load balancer to achieve 99.99% SLA and seamless failover.
- A microservices team uses VMSS with **rolling upgrades** to deploy new application versions without downtime.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create VMSS infrastructure | ✅ | ❌ |
| Create/manage spoke VNet and subnet | ✅ | ❌ |
| Configure NSG rules for VMSS | ✅ | ⚠️ |
| Set up load balancer | ✅ | ❌ |
| Configure autoscaling rules | ✅ | ⚠️ |
| Deploy application code | ❌ | ✅ |
| Configure health probes for application | ⚠️ | ✅ |
| Monitor application metrics | ❌ | ✅ |
| Update application deployments | ❌ | ✅ |
| Manage VM instance updates | ⚠️ | ⚠️ |
| Configure application-specific security rules | ⚠️ | ✅ |
| Set up application monitoring and alerts | ❌ | ✅ |
| Optimize autoscaling parameters | ⚠️ | ✅ |

## 💡 Best Practices

### Scale Set Sizing

**Why**: Choosing the right VM size and instance count affects performance and cost.

**Recommended Approaches**:

**Development/Testing**:
- Start with `Standard_B2s` or `Standard_B2ms` (burstable, cost-effective)
- 1-2 instances for dev, disable autoscaling
- Consider spot instances (70-90% cost savings)

**Production Workloads**:
- Use `Standard_D2s_v3` or higher for consistent performance
- Minimum 2 instances across availability zones
- Enable autoscaling with appropriate thresholds
- Use regular (non-spot) instances for reliability

**High-Performance Applications**:
- Use compute-optimized (`F-series`) or memory-optimized (`E-series`) VMs
- Premium SSD storage for I/O-intensive workloads
- Consider using larger VM sizes instead of more instances (vertical vs horizontal scaling)

### Autoscaling Configuration

**Why**: Proper autoscaling ensures performance during traffic spikes while minimizing costs during low-traffic periods.

**Recommended Settings**:

**Web Applications**:
- Min: 2 instances, Max: 10-20 instances
- Scale out at 75% CPU, scale in at 25% CPU
- 5-minute cooldown periods

**Batch Processing**:
- Min: 0-1 instances, Max: Based on job queue depth
- Scale on custom metrics (queue length, job count)
- Use spot instances for cost savings

**API Services**:
- Min: 3 instances (spread across zones)
- Max: Based on expected peak load
- Scale out at 70% CPU, scale in at 30% CPU
- Consider scaling on request count or latency metrics

**Important**: Monitor scaling behavior and adjust thresholds based on your application's characteristics.

### High Availability Strategy

**Why**: Distributing instances across availability zones provides resilience against datacenter failures.

**Recommended Configurations**:

**Production (99.99% SLA)**:
- Use 3 availability zones: `zones = ["1", "2", "3"]`
- Minimum 3 instances (1 per zone)
- Standard Load Balancer SKU (required for zones)
- Enable zone balancing

**Non-Production (99.95% SLA)**:
- Single zone deployment (default)
- Minimum 2 instances for basic redundancy
- Basic or Standard Load Balancer

**Critical Production (Maximum Resilience)**:
- 3 availability zones with 2+ instances per zone
- Rolling upgrade mode with health probes
- Automatic instance repair enabled

### Upgrade Strategy

**Why**: Different upgrade modes provide different trade-offs between automation and control.

**Upgrade Modes**:

**Manual (Default - Most Control)**:
- You control when instances are updated
- Best for critical workloads requiring change windows
- Update instances with: `az vmss update-instances`
- Zero risk of unexpected disruptions

**Rolling (Recommended for Production)**:
- Automatic rolling updates with health checks
- No downtime during updates
- Requires health probe configuration
- Updates 20% of instances at a time (configurable)
- Automatic rollback on health check failures

**Automatic (Convenience)**:
- Azure updates instances automatically when image changes
- Suitable for non-critical dev/test environments
- Requires health probe configuration
- Less control over update timing

### Security Best Practices

**Network Security**:

**Never**:
- ❌ Enable SSH/RDP from internet (0.0.0.0/0) in production
- ❌ Use default admin usernames (admin, administrator, root)
- ❌ Store credentials in custom_data scripts
- ❌ Disable network security groups

**Always**:
- ✅ Use Azure Bastion for administrative access
- ✅ Restrict management ports to specific IP ranges or use VPN
- ✅ Enable only necessary application ports
- ✅ Use managed identities for Azure resource access
- ✅ Enable boot diagnostics for troubleshooting
- ✅ Rotate SSH keys or passwords regularly

### Load Balancer Configuration

**Why**: Proper load balancer setup ensures traffic distribution and health monitoring.

**Best Practices**:

**Production Setup**:
- Use Standard Load Balancer SKU (required for zones)
- Configure application-specific health probes
- Use HTTP/HTTPS probes with custom paths (e.g., `/health`, `/status`)
- Set probe interval to 15 seconds
- Use 2 consecutive failures before marking unhealthy

**Internal vs External**:
- Use `enable_public_ip = false` for internal applications
- Use `enable_public_ip = true` for internet-facing applications
- Consider Application Gateway for advanced HTTP routing

**Health Probe Examples**:
```hcl
# Web application
health_probe_protocol     = "Http"
health_probe_port         = 80
health_probe_request_path = "/health"

# API service
health_probe_protocol     = "Https"
health_probe_port         = 443
health_probe_request_path = "/api/health"

# TCP service (database, cache)
health_probe_protocol     = "Tcp"
health_probe_port         = 5432
```

### Cost Optimization

**Why**: VMSS costs can grow significantly; optimization strategies can reduce costs by 50-90%.

**Strategies**:

**Spot Instances (70-90% savings)**:
- Use for: Batch jobs, dev/test, stateless workloads
- Don't use for: Databases, stateful apps, critical production services
- Set `spot_max_bid_price = -1` for maximum availability
- Implement graceful shutdown handling (30-second eviction notice)

**Autoscaling**:
- Enable autoscaling to reduce instances during off-peak hours
- Set aggressive scale-in thresholds for non-production
- Use scheduled scaling for predictable patterns

**Right-Sizing**:
- Monitor CPU and memory utilization
- Downsize VMs if consistently below 40% utilization
- Use burstable B-series for variable workloads

**Storage Optimization**:
- Use Standard_LRS for dev/test (cheapest)
- Use StandardSSD_LRS for production (balanced)
- Reserve Premium_LRS for high-IOPS workloads

## 📝 Receiving Scale Set Details

After the Platform Team creates your VM Scale Set, you'll receive:

- **Scale Set Name**: Name of the VMSS resource
- **Resource Group**: Resource group containing all resources
- **Network Information**: VNet name, subnet name, and network resource group (where VMSS is deployed)
- **Load Balancer IP**: Public or private IP for accessing your application
- **Admin Credentials**: Username and SSH key (Linux) or password (Windows)
- **Connection Instructions**: Commands for managing and accessing instances
- **Managed Identity Principal ID**: For granting Azure resource access

### Understanding Network Configuration

Your VMSS is deployed into an existing spoke VNet:

```bash
# View network details
az vmss show \
  --resource-group <resource-group> \
  --name <vmss-name> \
  --query "virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].ipConfigurations[0].subnet.id"
```

This shows which subnet your instances are using. The spoke VNet typically includes:
- Connectivity to hub network for shared services
- Network Security Groups (NSGs) controlling traffic
- Route tables for centralized routing

## 🔐 Managing VM Instances

### Viewing Scale Set Status

```bash
az vmss list-instances \
  --resource-group <resource-group> \
  --name <vmss-name> \
  --output table
```

### Manually Scaling

```bash
az vmss scale \
  --resource-group <resource-group> \
  --name <vmss-name> \
  --new-capacity <number>
```

### Updating Instances

After changing the VM image or configuration:

```bash
az vmss update-instances \
  --resource-group <resource-group> \
  --name <vmss-name> \
  --instance-ids "*"
```

### Connecting to Instances

**Linux with SSH** (if SSH access enabled):

```bash
az vmss list-instance-connection-info \
  --resource-group <resource-group> \
  --name <vmss-name>

ssh <admin-username>@<instance-ip>
```

**Windows with RDP** (if RDP access enabled):

```powershell
mstsc /v:<instance-ip>
```

**Recommended: Use Azure Bastion** for secure access without public IPs.

## 🔄 Application Deployment Strategies

### Strategy 1: Custom Image (Recommended)

**Best for**: Production applications with complex setup

**Process**:
1. Create VM with your application installed and configured
2. Generalize VM: `az vm deallocate` and `az vm generalize`
3. Create image: `az image create`
4. Update VMSS to use custom image
5. Update instances: `az vmss update-instances`

**Benefits**:
- Fast instance creation
- Consistent environment
- Reduced startup time

### Strategy 2: Cloud-Init / Custom Data

**Best for**: Simple applications, dev/test environments

**Process**:
1. Provide initialization script via `custom_data` variable
2. Script runs on first boot of each instance
3. New instances automatically configured

**Example (Linux)**:
```bash
#!/bin/bash
apt-get update
apt-get install -y nginx
systemctl start nginx
```

**Limitations**:
- Runs only on initial boot
- Increases instance startup time
- Less suitable for complex deployments

### Strategy 3: Configuration Management

**Best for**: Complex, multi-tier applications

**Tools**: Ansible, Chef, Puppet, Azure DSC (Windows)

**Process**:
1. Deploy base image
2. Use managed identity to authenticate to configuration service
3. Pull and apply configuration on boot or via schedule

## 📊 Monitoring and Observability

### Key Metrics to Monitor

**Instance Health**:
- Available instances vs desired count
- Failed instance creations
- Instance provisioning state

**Performance**:
- CPU utilization (trigger for autoscaling)
- Memory utilization
- Disk IOPS and latency
- Network throughput

**Scaling Events**:
- Scale-out events (timestamp, trigger)
- Scale-in events
- Autoscale evaluation results

**Application Metrics**:
- Request rate and latency
- Error rates
- Custom application metrics

### Setting Up Alerts

**Recommended Alerts**:

1. **No Healthy Instances**: Alert if all instances fail health checks
2. **High CPU (>90%)**: Indicates capacity constraints
3. **Failed Scale Operations**: Alert on autoscale failures
4. **Load Balancer Backend Pool Empty**: No healthy instances

**Azure CLI Example**:
```bash
az monitor metrics alert create \
  --name "vmss-cpu-high" \
  --resource-group <rg> \
  --scopes <vmss-id> \
  --condition "avg Percentage CPU > 90" \
  --window-size 5m \
  --evaluation-frequency 1m
```

## ⚠️ Important Notes

### Autoscaling Behavior

- Autoscaling evaluations run every 1-5 minutes
- Cooldown periods prevent rapid scaling oscillations
- Scale-out is prioritized over scale-in for availability
- Autoscale can be temporarily disabled without deleting rules

### Instance Updates

- Manual upgrade mode: You control when instances update
- Rolling upgrade mode: Automatic with health check validation
- Automatic upgrade mode: Azure updates instances automatically
- Unhealthy instances are not updated (prevents bad deployments)

### Spot Instances

- Can be evicted with 30-second notice when Azure needs capacity
- Suitable only for fault-tolerant, stateless workloads
- Eviction policy: Deallocate (can restart) or Delete (permanent)
- Not recommended for databases or stateful applications

### Networking

- VMSS uses existing spoke VNet managed by Platform Team
- All instances share the same subnet within the spoke VNet
- Each instance gets a private IP from the subnet's address space
- Public IPs are typically not assigned to individual instances
- Use load balancer public IP for internet-facing applications
- Network connectivity (hub access, on-premises, internet) is managed at the spoke VNet level

**Important**: If you need additional network connectivity or NSG rule changes, coordinate with your Platform Team.

### Storage

- OS disks are ephemeral (lost when instance deleted)
- Use Azure Storage, databases, or file shares for persistent data
- Premium storage offers better IOPS but higher cost
- Data disks can be attached for additional storage

## 🆘 Troubleshooting

### Instances not deploying

**Cause**: Quota limits, image unavailable, subnet full, or configuration errors

**Solution**:
1. Check subscription quota: `az vm list-usage --location <region>`
2. Verify image availability: `az vm image list`
3. Check subnet has available IP addresses: `az network vnet subnet show`
4. Review activity log for error messages
5. Verify NSG rules aren't blocking required traffic
6. Contact Platform Team if subnet capacity is exhausted

### Autoscaling not working

**Cause**: Misconfigured metrics, insufficient permissions, or cooldown periods

**Solution**:
1. Verify autoscale rule is enabled
2. Check metric data is being collected: `az monitor metrics list`
3. Review autoscale evaluation history: `az monitor autoscale show`
4. Wait for cooldown period to expire (default 5 minutes)
5. Ensure thresholds are appropriate for your workload

### Health probe failing

**Cause**: Application not responding, wrong port/path, or timeout issues

**Solution**:
1. Connect to an instance and test the health endpoint manually
2. Verify application is listening on correct port
3. Check application logs for errors
4. Increase probe interval or failure threshold if app is slow to start
5. Ensure NSG allows traffic on health probe port

### Cannot connect to instances

**Cause**: NSG rules blocking traffic, no public access configured, or spoke network routing issues

**Solution**:
1. Verify NSG rules on subnet and VMSS allow required traffic
2. Use Azure Bastion for secure access without public IPs
3. Check load balancer NAT rules if configured
4. For SSH/RDP issues, verify credentials and key format
5. Verify spoke VNet routing allows traffic to destination
6. Contact Platform Team for spoke network connectivity issues

### Spot instances frequently evicted

**Cause**: High demand for capacity in region or SKU

**Solution**:
1. Use different VM SKU with lower demand
2. Deploy to different region
3. Increase `spot_max_bid_price` (reduces savings)
4. Consider using regular instances instead

## 🔗 Common Integration Patterns

### Pattern 1: Auto-Scaling Web Application

**Setup**:
- VMSS with 2-10 instances
- Public load balancer with HTTP probe
- Autoscaling on CPU (scale out at 75%, scale in at 25%)
- Rolling upgrade mode
- Custom image with application pre-installed

**Benefits**: Automatic scaling, high availability, zero-downtime deployments

### Pattern 2: Internal Microservice

**Setup**:
- VMSS with 3-20 instances across 3 zones
- Private load balancer (no public IP)
- Autoscaling on request count or custom metrics
- Health probe on application /health endpoint
- Deploy via CI/CD with custom image updates

**Benefits**: High availability, cost-efficient, secure (no public access)

### Pattern 3: Batch Processing with Spot Instances

**Setup**:
- VMSS with spot instances
- No load balancer
- Scale on queue depth (Azure Queue/Service Bus)
- Manual upgrade mode
- Application reads from queue on startup

**Benefits**: 70-90% cost savings, automatic scale to handle queue depth

### Pattern 4: Dev/Test Environment

**Setup**:
- VMSS with 1-3 instances
- Manual scaling (autoscaling disabled)
- Spot instances for cost savings
- Cloud-init for simple application deployment
- SSH/RDP access for debugging

**Benefits**: Low cost, flexible for development and testing

## 📚 Related Documentation

- [Azure VM Scale Sets Overview](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/overview)
- [Autoscaling Best Practices](https://learn.microsoft.com/en-us/azure/azure-monitor/autoscale/autoscale-best-practices)
- [Spot VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/spot-vms)
- [VM Scale Set Health Monitoring](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-health-extension)
- [Custom Images](https://learn.microsoft.com/en-us/azure/virtual-machine-scale-sets/tutorial-use-custom-image-cli)
