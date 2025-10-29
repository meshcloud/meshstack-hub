# Azure DevOps VMSS Runner - App Team Guide

## 🚀 What is this?

This building block provides you with **scalable, self-hosted Azure DevOps pipeline runners** that automatically scale based on your CI/CD workload. Unlike Microsoft-hosted agents, these runners:

- Run in **your Azure subscription** within your spoke network
- Have **direct access** to private resources (databases, internal APIs, etc.)
- **Auto-scale** from 0 to your maximum capacity
- Can be **customized** with pre-installed tools and dependencies

## 🎯 When to Use This

Use VMSS runners when you need:

✅ **Private Network Access**: Pipelines need to reach internal resources  
✅ **Custom Software**: Pre-installed tools not available on Microsoft-hosted agents  
✅ **Higher Resource Limits**: Need more CPU, memory, or disk than hosted agents provide  
✅ **Compliance Requirements**: Must run builds in specific networks or subscriptions  
✅ **Cost Optimization**: High pipeline usage makes self-hosted agents more economical

**Don't use this if:**
- Your pipelines only access public resources → Use Microsoft-hosted agents
- You run very few pipelines → Overhead not worth it

## 📋 Prerequisites

Before requesting this building block, you need:

1. **Azure DevOps Project ID**: Get this from your project settings
2. **Azure Subscription ID**: Where the runners will be deployed
3. **Spoke Network Details**: VNet name, subnet name, and resource group
4. **Azure Service Connection**: Created via the `service-connection` building block
5. **SSH Public Key**: For emergency VM access (rarely needed)

## 🔄 Shared Responsibility Matrix

| Responsibility | Platform Team | App Team |
|----------------|---------------|----------|
| **Setup & Infrastructure** |
| Provision VMSS and agent pool | ✅ | |
| Configure spoke network integration | ✅ | |
| Create Azure service connection | ✅ | |
| Set up backplane (Key Vault, SP) | ✅ | |
| **Configuration** |
| Define VM size and scaling limits | | ✅ |
| Choose OS image and storage type | | ✅ |
| Configure agent recycling policy | | ✅ |
| Request specific tools/software | | ✅ |
| **Operations** |
| Monitor VMSS health | ✅ | |
| Monitor agent pool capacity | ✅ | ✅ |
| Update VM images | ✅ | |
| Troubleshoot scaling issues | ✅ | |
| **Pipeline Usage** |
| Configure pipelines to use pool | | ✅ |
| Monitor pipeline performance | | ✅ |
| Optimize pipeline efficiency | | ✅ |
| Report agent pool issues | | ✅ |

## 💡 Configuration Guide

### Basic Configuration

```hcl
# Minimal setup - good for testing
agent_pool_name     = "my-team-runners"
vmss_name           = "my-team-vmss"
desired_idle_agents = 1
max_capacity        = 5
```

### Production Configuration

```hcl
# Production setup - auto-scales for high throughput
agent_pool_name        = "prod-runners"
vmss_name              = "prod-vmss"
vm_sku                 = "Standard_D4s_v3"      # 4 vCPU, 16GB RAM
desired_idle_agents    = 3                       # Always ready
max_capacity           = 50                      # Peak capacity
recycle_after_each_use = true                    # Fresh environment per job
time_to_live_minutes   = 15                      # Quick scale-down
os_disk_type           = "Premium_LRS"           # Fast storage

tags = {
  environment = "production"
  team        = "platform"
  cost_center = "engineering"
}
```

### Development Configuration

```hcl
# Dev setup - cost-optimized
agent_pool_name     = "dev-runners"
vmss_name           = "dev-vmss"
vm_sku              = "Standard_D2s_v3"          # Smaller VM
desired_idle_agents = 0                           # No idle agents
max_capacity        = 10                          # Limited scale
time_to_live_minutes = 60                         # Longer TTL
os_disk_type         = "StandardSSD_LRS"          # Cheaper storage
```

## 🛠️ Using VMSS Runners in Pipelines

### YAML Pipeline Example

```yaml
# azure-pipelines.yml
trigger:
  - main

pool:
  name: 'my-team-runners'  # Your agent pool name

jobs:
  - job: Build
    steps:
      - script: |
          echo "Running on self-hosted VMSS runner"
          echo "Agent: $(Agent.Name)"
        displayName: 'Build Application'

      - script: |
          # Access private resources in spoke network
          curl http://internal-api.private:8080/health
        displayName: 'Health Check Internal API'
```

### Multi-Stage Pipeline

```yaml
stages:
  - stage: Build
    pool:
      name: 'my-team-runners'
    jobs:
      - job: CompileBuild
        steps:
          - task: Maven@3
            inputs:
              mavenPomFile: 'pom.xml'
              goals: 'clean package'

  - stage: Test
    pool:
      name: 'my-team-runners'
    jobs:
      - job: IntegrationTests
        steps:
          - script: |
              # Can access private database in spoke
              npm run test:integration
```

### Specific Pool in Job

```yaml
jobs:
  - job: LargeCompute
    pool:
      name: 'prod-runners'  # Use VMSS pool
    steps:
      - script: heavy-computation.sh

  - job: QuickLint
    pool:
      vmImage: 'ubuntu-latest'  # Use Microsoft-hosted
    steps:
      - script: npm run lint
```

## 📊 Capacity Planning

### VM Size Selection

| VM SKU | vCPU | RAM | Use Case | Cost Tier |
|--------|------|-----|----------|-----------|
| `Standard_D2s_v3` | 2 | 8GB | Light builds, linting | $ |
| `Standard_D4s_v3` | 4 | 16GB | Standard builds, tests | $$ |
| `Standard_D8s_v3` | 8 | 32GB | Heavy builds, parallel tests | $$$ |
| `Standard_D16s_v3` | 16 | 64GB | Very large builds | $$$$ |

### Scaling Strategy

**Conservative (Low Cost)**
```hcl
desired_idle_agents  = 0
max_capacity         = 10
time_to_live_minutes = 60
```
- No idle agents (save money)
- Scale up only when needed
- Keep agents longer to reduce churn

**Balanced (Most Common)**
```hcl
desired_idle_agents  = 2
max_capacity         = 20
time_to_live_minutes = 30
```
- Small pool always ready
- Moderate max capacity
- Standard TTL

**Aggressive (High Performance)**
```hcl
desired_idle_agents  = 5
max_capacity         = 50
time_to_live_minutes = 15
```
- Always have agents ready
- High peak capacity
- Quick scale-down

## 🔒 Security Best Practices

### Network Security
- ✅ Runners are isolated in spoke subnet
- ✅ Use NSG rules to restrict outbound access
- ✅ Limit access to only required internal resources
- ❌ Don't expose runners to public internet

### Credential Management
- ✅ Use Azure DevOps service connections for Azure access
- ✅ Store secrets in Azure DevOps variable groups or Key Vault
- ✅ Use managed identity for Azure resource access
- ❌ Never hardcode credentials in pipelines

### Agent Hygiene
- ✅ Enable `recycle_after_each_use` for sensitive workloads
- ✅ Regularly update VM images
- ✅ Monitor agent pool for unusual activity
- ❌ Don't persist sensitive data on agent disks

## 🐛 Troubleshooting

### No Agents Available

**Symptoms**: Pipeline queued but no agents pick it up

**Solutions**:
1. Check `desired_idle_agents` > 0 or increase `max_capacity`
2. Verify VMSS has quota in Azure subscription
3. Check agent pool status in Azure DevOps settings
4. Ensure service connection has correct permissions

### Slow Agent Startup

**Symptoms**: Long wait time between job queue and start

**Solutions**:
1. Increase `desired_idle_agents` to pre-warm pool
2. Reduce `time_to_live_minutes` to keep agents warm longer
3. Consider larger VM SKU for faster boot times
4. Optimize custom script in agent installation

### Pipelines Failing on Private Resource Access

**Symptoms**: Can't reach internal APIs/databases

**Solutions**:
1. Verify spoke subnet NSG allows required traffic
2. Check subnet route table includes private resource networks
3. Confirm private DNS resolution works
4. Test connectivity: Add debug step `curl http://internal-resource`

### Cost Higher Than Expected

**Symptoms**: Azure bill shows high VMSS costs

**Solutions**:
1. Reduce `desired_idle_agents` to 0 or lower value
2. Use smaller VM SKU (e.g., D2s instead of D4s)
3. Enable `recycle_after_each_use = false` if not needed
4. Increase `time_to_live_minutes` to reduce churn
5. Review pipeline efficiency - reduce unnecessary runs

## 📈 Monitoring

### Azure DevOps Portal

1. Navigate to **Project Settings** → **Agent pools**
2. Select your pool (e.g., "my-team-runners")
3. Monitor:
   - Number of online agents
   - Queued jobs
   - Recent job history

### Azure Portal

1. Navigate to your VMSS resource
2. Check **Metrics**:
   - VM instance count
   - CPU utilization
   - Network traffic
3. Review **Activity Log** for scaling events

### Recommended Alerts

Set up alerts for:
- VMSS instance count reaches max capacity (scale limit hit)
- No online agents for > 10 minutes (configuration issue)
- High CPU utilization > 80% for > 15 minutes (undersized VM)

## 💰 Cost Optimization Tips

1. **Use Spot VMs** (advanced): Can reduce costs by up to 90% but agents may be evicted
2. **Right-size VMs**: Don't over-provision - start small and scale up if needed
3. **Scale to zero**: Set `desired_idle_agents = 0` for dev/test environments
4. **Scheduled scaling**: Use Azure Automation to scale down outside business hours
5. **Optimize pipelines**: Faster pipelines = fewer agent hours

## 📞 Getting Help

**Questions about:**
- **Setup/Configuration**: Contact Platform Team
- **Pipeline Usage**: Check Azure DevOps documentation
- **Costs**: Review with Platform Team and FinOps
- **Network Issues**: Contact Network Team

**Useful Resources:**
- [Azure DevOps Agent Pools Documentation](https://docs.microsoft.com/azure/devops/pipelines/agents/pools-queues)
- [VMSS Scaling Documentation](https://docs.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-autoscale-overview)
- [Pipeline YAML Schema](https://docs.microsoft.com/azure/devops/pipelines/yaml-schema)
