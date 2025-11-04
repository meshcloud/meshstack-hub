# Azure DevOps Agent Pool

This building block creates an Azure DevOps agent pool that connects to your existing Azure Virtual Machine Scale Set (VMSS) for **automatically scaling build agents** based on your pipeline workload.

## 🚀 Usage Examples

- A development team needs **dedicated build agents** that scale automatically when multiple pipelines run simultaneously.
- DevOps engineers want to **reduce costs** by scaling down agents during off-peak hours and weekends.
- Platform teams provide **isolated agent pools** for different teams or projects with specific security requirements.
- Organizations need **Windows or Linux agents** with custom tools pre-installed for specialized build processes.

## 🔄 Shared Responsibility

| Responsibility | Platform Team | Application Team |
|----------------|---------------|------------------|
| Create agent pool | ✅ | ❌ |
| Configure elastic scaling | ✅ | ❌ |
| Manage VMSS infrastructure | ✅ | ❌ |
| Install agent base image | ✅ | ❌ |
| Configure pipeline to use pool | ❌ | ✅ |
| Monitor agent utilization | ❌ | ✅ |
| Request capacity changes | ❌ | ✅ |
| Install custom build tools | Depends | Depends |

## 👥 User Roles Explained

| Role in Authoritative System | Azure DevOps Group | What They Can Do | Best For |
|------------------------------|-------------------|------------------|----------|
| **admin** or **Workspace Owner** | Agent Pool Administrators | Manage pool settings, view agents, configure scaling | DevOps engineers, platform team |

## 💡 Best Practices

### Pool Configuration

**Why**: Proper configuration ensures optimal performance and cost efficiency.

**Recommendations**:
- Use descriptive pool names (e.g., `linux-docker-builders` not `pool1`)
- Set `desired_idle` to handle typical concurrent job load
- Keep `max_capacity` reasonable to control costs
- Enable `auto_update` to keep agents current with latest features

### Scaling Strategy

**Why**: Right-sizing your pool reduces costs while maintaining performance.

**Best Practices**:
```hcl
# For steady workload
desired_idle   = 2    # Keep 2 agents always ready
max_capacity   = 10   # Allow scaling to 10 during peak times

# For bursty workload
desired_idle   = 0    # No idle agents to save costs
max_capacity   = 20   # Higher ceiling for traffic spikes

# For continuous integration
desired_idle   = 5    # More agents ready for fast builds
recycle_after_each_use = true  # Clean state for each build
```

### Cost Optimization

**Why**: Agent pools can be expensive if not managed properly.

**Tips**:
- Set `time_to_live_minutes` to automatically remove idle agents (e.g., 30 minutes)
- Use `desired_idle = 0` for pools with infrequent usage
- Set `max_saved_node_count` to limit standing agents
- Consider separate pools for different workload patterns
- Use smaller VM sizes for simpler build jobs

### Security

**Why**: Build agents have access to your code and secrets.

**Recommendations**:
- Use dedicated agent pools for different security zones
- Enable `recycle_after_each_use` for sensitive builds
- Don't set `auto_provision = true` (explicitly authorize projects)
- Regularly update VMSS image with security patches
- Use managed identities instead of storing credentials

### VMSS Requirements

**Why**: The VMSS is the foundation for your elastic agent pool.

**Your VMSS Must Have**:
- Azure DevOps agent software pre-installed
- Required build tools and dependencies
- Network access to Azure DevOps (https://dev.azure.com)
- Sufficient disk space for build artifacts
- Proper VM size for your build workload

**Recommended VMSS Image**:
```bash
# Microsoft-hosted agent images (Ubuntu, Windows Server)
# Or custom image with your tooling pre-installed
```

### Agent Interactive UI

**Why**: Some builds require UI access (e.g., UI tests, browser automation).

**When to Enable**:
- Running Selenium or UI automation tests
- Building applications with graphical installers
- Testing desktop applications

**Note**: This increases costs as agents need more resources.

## 📝 Common Scenarios

### Scenario 1: Standard CI/CD Pool

A typical team running 10-20 builds per day:
```hcl
max_capacity           = 10
desired_idle           = 2
recycle_after_each_use = false
time_to_live_minutes   = 30
```

**Why**: Keeps 2 agents ready for immediate use, scales to 10 for concurrent builds, removes idle agents after 30 minutes.

### Scenario 2: High-Security Pool

For sensitive builds requiring clean environments:
```hcl
max_capacity           = 5
desired_idle           = 0
recycle_after_each_use = true
auto_provision         = false
```

**Why**: No standing agents (cost-efficient), every build gets a fresh VM (security), must explicitly authorize projects (access control).

### Scenario 3: Large-Scale Enterprise Pool

For organizations with hundreds of builds daily:
```hcl
max_capacity           = 50
desired_idle           = 10
max_saved_node_count   = 10
time_to_live_minutes   = 60
```

**Why**: Keeps 10 agents always ready, scales to 50 during peak times, maintains up to 10 idle agents for fast response.

### Scenario 4: Weekend Testing Pool

For teams running long test suites on weekends:
```hcl
max_capacity           = 20
desired_idle           = 0
time_to_live_minutes   = 15
```

**Why**: No idle agents during the week (cost savings), scales up when tests run, quick cleanup after tests complete.

## ⚙️ Configuration Reference

### Service Connection Setup

Before using this building block, you need:

1. **Azure Service Connection** in Azure DevOps
2. Service principal with **Reader** role on VMSS resource group
3. Service endpoint ID and project scope

**How to Get Service Endpoint ID**:
```bash
# Azure DevOps CLI
az devops service-endpoint list --organization https://dev.azure.com/myorg \
  --project myproject --query "[?name=='MyServiceConnection'].id"
```

### Project Authorization

If you provide `project_id`, the agent pool is automatically:
- Added as an agent queue to the project
- Authorized for all pipelines in the project

If you don't provide `project_id`:
- Pool is created at organization level
- Projects must manually add the pool
- Pipelines must be manually authorized

## ⚠️ Important Notes

- **VMSS Must Pre-Exist**: This building block does NOT create the VMSS - it must already exist
- **Agent Image**: Your VMSS must use an image with Azure DevOps agent installed
- **Network**: Agents must reach `https://dev.azure.com` and your artifact sources
- **PAT Scopes**: Required: Agent Pools (Read & Manage), optionally: Build (Read & Execute)
- **Scaling Time**: First agent startup can take 2-5 minutes depending on VM size
- **Costs**: You pay for running VMs - monitor usage to optimize costs

## 🆘 Troubleshooting

### Agents Not Appearing

**Cause**: VMSS doesn't have agent configured or can't reach Azure DevOps

**Solution**:
1. Check VMSS has Azure DevOps agent installed
2. Verify network connectivity from VMSS to `https://dev.azure.com`
3. Check agent logs on a VMSS instance
4. Verify service connection has access to VMSS

### Pool Not Scaling

**Cause**: Elastic pool configuration issue or demand too low

**Solution**:
1. Check `max_capacity` > `desired_idle`
2. Verify elastic pool is properly configured in Azure DevOps portal
3. Queue multiple jobs to trigger scaling
4. Review scaling metrics in Azure portal

### Build Jobs Stuck in Queue

**Cause**: No agents available or all agents busy

**Solution**:
1. Check agent pool status in Azure DevOps
2. Increase `max_capacity` or `desired_idle`
3. Verify VMSS has capacity to scale
4. Check if agents are online in pool

### High Costs

**Cause**: Too many idle agents or improper scaling configuration

**Solution**:
1. Reduce `desired_idle` to minimum needed
2. Lower `time_to_live_minutes` to remove idle agents faster
3. Set `max_saved_node_count` to limit standing agents
4. Review actual usage patterns and adjust capacity
5. Consider using smaller VM sizes

### Service Connection Error

**Cause**: Service connection lacks permissions or VMSS not found

**Solution**:
1. Verify service connection has Reader role on VMSS resource group
2. Check VMSS name and resource group are correct
3. Ensure service endpoint ID is valid
4. Test service connection in Azure DevOps portal

## 🎉 Getting Started

Once your agent pool is deployed:

1. **Verify Pool**: Check Azure DevOps → Organization Settings → Agent pools
2. **View Agents**: Wait a few minutes for initial agents to register
3. **Test Build**: Queue a simple pipeline job to verify functionality
4. **Configure Projects**: Add pool to projects that need it
5. **Monitor Usage**: Track agent utilization and adjust capacity

## 📚 Related Documentation

- [Azure DevOps Agent Pools](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/pools-queues)
- [Elastic Agent Pools](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents)
- [VMSS Integration](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/scale-set-agents)
