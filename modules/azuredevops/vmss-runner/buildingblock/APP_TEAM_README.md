# Azure DevOps VMSS Runner

This building block provides scalable, self-hosted Azure DevOps pipeline runners that automatically scale based on your CI/CD workload. Unlike Microsoft-hosted agents, these runners run in your Azure subscription with direct access to private resources.

## 🚀 Usage Examples

- A development team deploys VMSS runners to **access private databases and internal APIs** during CI/CD pipelines without exposing them to the internet.
- A DevOps team configures auto-scaling runners to **handle variable pipeline workloads** efficiently, scaling from 0 to 50 agents based on demand.
- An organization uses self-hosted runners with **custom software pre-installed** (compilers, SDKs, tools) not available on Microsoft-hosted agents.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Provision VMSS and agent pool | ✅ | ❌ |
| Configure spoke network integration | ✅ | ❌ |
| Create Azure service connection | ✅ | ❌ |
| Define VM size and scaling limits | ⚠️ | ✅ |
| Choose OS image and storage type | ⚠️ | ✅ |
| Configure agent recycling policy | ⚠️ | ✅ |
| Request specific tools/software | ❌ | ✅ |
| Monitor VMSS health | ✅ | ⚠️ |
| Monitor agent pool capacity | ✅ | ✅ |
| Update VM images | ✅ | ❌ |
| Configure pipelines to use pool | ❌ | ✅ |
| Monitor pipeline performance | ❌ | ✅ |
| Optimize pipeline efficiency | ❌ | ✅ |
| Report agent pool issues | ❌ | ✅ |

## 🎯 When to Use This

**Use VMSS runners when you need:**
- ✅ Private network access to internal resources (databases, APIs, services)
- ✅ Custom software pre-installed on agents
- ✅ Higher resource limits (CPU, memory, disk) than Microsoft-hosted agents
- ✅ Compliance requirements for running builds in specific networks
- ✅ Cost optimization for high pipeline usage

**Don't use this if:**
- ❌ Pipelines only access public resources → Use Microsoft-hosted agents
- ❌ Very low pipeline volume → Overhead not worth it
- ❌ No private network requirements → Microsoft-hosted agents are simpler

## 💡 Configuration Guidance

### VM Size Selection

| VM SKU | vCPU | RAM | Use Case | Cost Tier |
|--------|------|-----|----------|-----------|
| `Standard_D2s_v3` | 2 | 8GB | Light builds, linting, testing | $ |
| `Standard_D4s_v3` | 4 | 16GB | Standard builds and tests | $$ |
| `Standard_D8s_v3` | 8 | 32GB | Heavy builds, parallel testing | $$$ |
| `Standard_D16s_v3` | 16 | 64GB | Very large builds, compilation | $$$$ |

**Start small and scale up based on actual usage metrics.**

### Scaling Strategy

**Conservative (Low Cost)**:
- No idle agents (scale from 0)
- Moderate max capacity (10 agents)
- Longer agent lifetime (60 minutes)
- Best for: Infrequent pipelines, cost-sensitive projects

**Balanced (Recommended)**:
- Small pool of ready agents (2 idle)
- Reasonable max capacity (20 agents)
- Standard lifetime (30 minutes)
- Best for: Regular development workflows

**Aggressive (High Performance)**:
- Always have agents ready (5 idle)
- High max capacity (50 agents)
- Quick scale-down (15 minutes)
- Best for: Continuous deployment, high-frequency pipelines

### Storage Options

**Standard SSD (`StandardSSD_LRS`)**:
- Lower cost
- Sufficient for most workloads
- Good for development environments

**Premium SSD (`Premium_LRS`)**:
- Higher performance
- Faster build times
- Recommended for production pipelines

### Agent Recycling

**Recycle After Each Use (`true`)**:
- Fresh environment per job
- Better security and isolation
- Slightly longer startup time
- Recommended for: Production, sensitive workloads

**Keep Agents Running (`false`)**:
- Faster subsequent job execution
- Shared state between jobs
- Lower cost (fewer VM restarts)
- Recommended for: Development, non-sensitive workloads

## 📝 Using VMSS Runners in Pipelines

### Basic Pipeline

```yaml
trigger:
  - main

pool:
  name: 'my-team-runners'

jobs:
  - job: Build
    steps:
      - script: |
          echo "Running on self-hosted VMSS runner"
          echo "Agent: $(Agent.Name)"
        displayName: 'Build Application'

      - script: |
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
          - script: npm run test:integration
            displayName: 'Run integration tests'
```

### Mixed Agent Types

Use VMSS runners for jobs requiring private access, Microsoft-hosted for simple tasks:

```yaml
jobs:
  - job: HeavyBuild
    pool:
      name: 'prod-runners'
    steps:
      - script: |
          # Access private database
          ./run-heavy-build.sh

  - job: QuickLint
    pool:
      vmImage: 'ubuntu-latest'
    steps:
      - script: npm run lint
```

## 🔒 Security Best Practices

### Network Security
- ✅ Runners are isolated in spoke subnet with NSG rules
- ✅ Restrict outbound access to only required resources
- ✅ Use private endpoints for Azure services
- ❌ Don't expose runners to public internet

### Credential Management
- ✅ Use Azure DevOps service connections for Azure access
- ✅ Store secrets in Azure DevOps variable groups or Key Vault
- ✅ Use managed identity for Azure resource access
- ❌ Never hardcode credentials in pipelines

### Agent Hygiene
- ✅ Enable agent recycling for sensitive workloads
- ✅ Regularly update VM images with security patches
- ✅ Monitor agent pool for unusual activity
- ❌ Don't persist sensitive data on agent disks

## 📊 Capacity Planning

### Configuration Examples

**Development Environment**:
- VM Size: `Standard_D2s_v3`
- Idle Agents: 0
- Max Capacity: 10
- Time to Live: 60 minutes
- Storage: StandardSSD_LRS
- **Cost**: Low, scales to zero when not in use

**Production Environment**:
- VM Size: `Standard_D4s_v3`
- Idle Agents: 3
- Max Capacity: 50
- Time to Live: 15 minutes
- Storage: Premium_LRS
- Recycle After Use: true
- **Cost**: Higher, but optimized for performance and security

## 🐛 Troubleshooting

### No Agents Available

**Symptoms**: Pipeline queued but no agents pick it up

**Solutions**:
1. Check idle agent count is > 0, or increase max capacity
2. Verify VMSS has quota in Azure subscription
3. Check agent pool status in Azure DevOps settings
4. Ensure service connection has correct permissions

### Slow Agent Startup

**Symptoms**: Long wait time between job queue and start

**Solutions**:
1. Increase idle agent count to pre-warm pool
2. Reduce time-to-live to keep agents warm longer
3. Consider larger VM SKU for faster boot times
4. Optimize custom installation scripts

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
1. Reduce idle agent count to 0 or lower value
2. Use smaller VM SKU
3. Disable recycling if not required
4. Increase time-to-live to reduce churn
5. Review pipeline efficiency - optimize build times

### Agent Pool Shows No Capacity

**Symptoms**: Agent pool exists but shows 0/0 agents

**Solutions**:
1. Check VMSS status in Azure Portal
2. Verify service principal permissions
3. Review VMSS activity logs for errors
4. Contact Platform Team for infrastructure issues

## 📈 Monitoring

### Azure DevOps Portal

1. Navigate to **Project Settings** → **Agent pools**
2. Select your pool
3. Monitor:
   - Number of online agents
   - Queued jobs
   - Recent job history
   - Agent capacity trends

### Azure Portal

1. Navigate to your VMSS resource
2. Check **Metrics**:
   - VM instance count (current vs desired)
   - CPU utilization
   - Network traffic
   - Disk IOPS
3. Review **Activity Log** for scaling events

### Recommended Alerts

Set up alerts for:
- VMSS instance count reaches max capacity (scale limit hit)
- No online agents for > 10 minutes (configuration issue)
- High CPU utilization > 80% for > 15 minutes (undersized VM)
- Frequent scaling events (possible configuration issue)

## 💰 Cost Optimization Tips

1. **Scale to Zero**: Set idle agents to 0 for dev/test environments
2. **Right-Size VMs**: Don't over-provision - start with D2s and scale up if needed
3. **Use Spot VMs** (advanced): Up to 90% savings for fault-tolerant workloads
4. **Optimize Pipelines**: Faster pipelines = fewer agent hours
5. **Scheduled Scaling**: Scale down during off-hours (requires additional setup)
6. **Disable Recycling**: For dev environments where security is less critical
7. **Storage Selection**: Use Standard SSD for non-production

## 📞 Getting Help

**Questions about:**
- **Setup/Configuration**: Contact Platform Team
- **Pipeline Usage**: Check Azure DevOps documentation
- **Network Connectivity**: Contact Network Team
- **Costs/Optimization**: Review with Platform Team and FinOps

**Useful Resources**:
- [Azure DevOps Agent Pools](https://docs.microsoft.com/azure/devops/pipelines/agents/pools-queues)
- [VMSS Scaling](https://docs.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-autoscale-overview)
- [Pipeline YAML Schema](https://docs.microsoft.com/azure/devops/pipelines/yaml-schema)
