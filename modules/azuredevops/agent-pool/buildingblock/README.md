---
name: Azure DevOps Agent Pool
supportedPlatforms:
  - azuredevops
description: |
  Creates an Azure DevOps agent pool connected to an existing Azure VMSS for elastic scaling of build agents.
category: devops
---

# Azure DevOps Agent Pool Building Block

This building block creates an Azure DevOps agent pool with elastic pool configuration that connects to an existing Azure Virtual Machine Scale Set (VMSS) for dynamic agent scaling.

## Features

- **Agent Pool Creation**: Creates organization-level Azure DevOps agent pool
- **Elastic Pool Integration**: Connects to existing Azure VMSS for automatic scaling
- **Project Authorization**: Optional project-level queue and pipeline authorization
- **Auto-scaling**: Dynamically scales agents based on demand

## Prerequisites

- Azure DevOps organization
- Existing Azure Virtual Machine Scale Set with Azure DevOps agent image
- Azure service connection with access to the VMSS resource group
- Personal Access Token with required scopes (managed by backplane)

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│   Backplane     │───▶│  Building Block  │───▶│ Azure DevOps Org │
│                 │    │                  │    │                  │
│ • Service       │    │ • Agent Pool     │    │ • Organization   │
│   Principal     │    │ • Elastic Pool   │    │   Agent Pool     │
│ • Key Vault     │    │ • Project Queue  │    │ • Auto-scaling   │
│ • PAT Storage   │    │ • Admins         │    │ • VMSS backend   │
└─────────────────┘    └──────────────────┘    └──────────────────┘
                                 │
                                 ▼
                        ┌─────────────────┐
                        │  Azure VMSS     │
                        │                 │
                        │ • Existing RG   │
                        │ • Agent image   │
                        │ • Scaling rules │
                        └─────────────────┘
```

## Usage

```hcl
module "azure_devops_agent_pool" {
  source = "path/to/azuredevops/agent-pool/buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdevops-terraform"
  resource_group_name           = "rg-azdevops-terraform"

  agent_pool_name          = "my-elastic-pool"
  vmss_name                = "vmss-build-agents"
  vmss_resource_group_name = "rg-build-agents"

  service_endpoint_id    = "12345678-1234-1234-1234-123456789012"
  service_endpoint_scope = "abcdef01-2345-6789-abcd-ef0123456789"

  max_capacity   = 10
  desired_idle   = 2

  auto_provision         = false
  auto_update            = true
  recycle_after_each_use = false

  project_id = "project-123"
}
```

## Configuration Options

### Elastic Pool Settings

- **max_capacity**: Maximum number of VMs in the scale set (1-1000)
- **desired_idle**: Number of agents to keep idle and ready (0+)
- **recycle_after_each_use**: Whether to tear down VM after each job
- **time_to_live_minutes**: Time to keep idle agents before removal

### Agent Pool Settings

- **auto_provision**: Automatically provision projects with this pool
- **auto_update**: Automatically update agents
- **agent_interactive_ui**: Enable interactive UI for agents

## Agent Pool Administrators

Agent pool administration is managed at the **organization level** in Azure DevOps. After creating the pool with Terraform, administrators must be assigned manually:

1. Navigate to **Organization Settings** → **Agent pools** in Azure DevOps
2. Select your agent pool
3. Go to **Security** tab
4. Add users/groups to **Administrator** role

**Permissions granted to administrators**:
- Manage agent pool settings
- View and manage agents
- Configure elastic pool properties
- Authorize pipelines to use the pool

## Important Notes

- **VMSS Must Exist**: The Azure VMSS must be created before using this building block
- **Agent Image**: The VMSS must use an image with Azure DevOps agent pre-installed
- **Service Connection**: Requires Azure service connection with read access to VMSS
- **PAT Requirements**: Personal Access Token needs Agent Pools (Read & Manage) scope
- **Project Authorization**: Optional but recommended for pipeline access
- **User Management**: Agent pool administrators must be assigned manually in Azure DevOps portal

## Troubleshooting

### Agent Pool Creation Failed

**Cause**: Insufficient permissions or PAT scope issues

**Solution**:
1. Verify PAT has "Agent Pools (Read & Manage)" scope
2. Check organization-level permissions
3. Ensure user is an Agent Pool Administrator at org level

### VMSS Connection Failed

**Cause**: Service connection lacks access to VMSS or resource group

**Solution**:
1. Verify service connection has Reader role on VMSS resource group
2. Check VMSS exists and is in correct resource group
3. Ensure service endpoint ID and scope are correct

### Agents Not Scaling

**Cause**: VMSS configuration or elastic pool settings issue

**Solution**:
1. Check VMSS has Azure DevOps agent installed
2. Verify max_capacity is greater than desired_idle
3. Review elastic pool configuration in Azure DevOps portal
4. Check VMSS scaling settings in Azure portal

### Project Authorization Failed

**Cause**: Invalid project ID or insufficient permissions

**Solution**:
1. Verify project_id is correct
2. Check PAT has project-level permissions
3. Ensure agent pool exists before authorization
