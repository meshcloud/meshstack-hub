---
name: Azure DevOps VMSS Runner
supportedPlatforms:
  - azuredevops
description: Provides a scalable Azure DevOps agent pool using Azure Virtual Machine Scale Sets connected to a specific spoke network for CI/CD pipeline execution.
category: ci-cd
---

# Azure DevOps VMSS Runner - Building Block

This building block module creates an Azure DevOps agent pool backed by Azure Virtual Machine Scale Sets (VMSS) for scalable, self-hosted pipeline runners.

## Features

- **Elastic Agent Pool**: Automatically scales based on pipeline demand
- **Spoke Network Integration**: Connects runners to existing spoke virtual networks
- **Customizable Capacity**: Configure idle agents and maximum capacity
- **Flexible VM Options**: Choose VM size, OS image, and storage type
- **Agent Lifecycle Management**: Control agent recycling and time-to-live
- **Managed Identity**: Built-in system-assigned identity for Azure resource access

## Resources Created

- **Azure DevOps Agent Pool**: Self-hosted agent pool
- **Azure DevOps Agent Queue**: Project-specific agent queue
- **Azure DevOps Elastic Pool**: Auto-scaling configuration
- **Azure VMSS**: Linux-based virtual machine scale set
- **Network Integration**: Connection to specified spoke subnet
- **IAM Assignments**: Network Contributor role for VMSS identity

## Prerequisites

- Existing Azure DevOps project (project ID required)
- Azure subscription with VMSS creation permissions
- Existing spoke virtual network with subnet
- Azure service connection in Azure DevOps (created via service-connection module)
- SSH public key for VM access
- Azure DevOps PAT with Agent Pools permissions

## Required Inputs

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `azuredevops_org_url` | Azure DevOps organization URL | string | - |
| `azuredevops_project_id` | Azure DevOps project ID | string | - |
| `azuredevops_pat` | Azure DevOps PAT | string (sensitive) | - |
| `service_endpoint_id` | Azure service connection ID | string | - |
| `agent_pool_name` | Agent pool name | string | - |
| `vmss_name` | VMSS name | string | - |
| `azure_subscription_id` | Azure subscription ID | string | - |
| `azure_resource_group_name` | Resource group for VMSS | string | - |
| `azure_location` | Azure region | string | - |
| `spoke_vnet_name` | Spoke VNet name | string | - |
| `spoke_subnet_name` | Spoke subnet name | string | - |
| `spoke_resource_group_name` | Spoke resource group | string | - |
| `ssh_public_key` | SSH public key | string | - |

## Optional Inputs

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `vm_sku` | VM size | string | `Standard_D2s_v3` |
| `desired_idle_agents` | Number of idle agents | number | `1` |
| `max_capacity` | Maximum agents | number | `10` |
| `time_to_live_minutes` | Agent TTL in minutes | number | `30` |
| `recycle_after_each_use` | Recycle agent after job | bool | `false` |
| `os_disk_type` | OS disk storage type | string | `Premium_LRS` |
| `image_publisher` | VM image publisher | string | `Canonical` |
| `image_offer` | VM image offer | string | `0001-com-ubuntu-server-jammy` |
| `image_sku` | VM image SKU | string | `22_04-lts-gen2` |
| `image_version` | VM image version | string | `latest` |
| `tags` | Azure resource tags | map(string) | `{}` |

## Outputs

- `agent_pool_id`: Azure DevOps agent pool ID
- `agent_pool_name`: Agent pool name
- `agent_queue_id`: Project agent queue ID
- `elastic_pool_id`: Elastic pool configuration ID
- `vmss_id`: VMSS resource ID
- `vmss_name`: VMSS name
- `vmss_principal_id`: VMSS managed identity principal ID
- `subnet_id`: Deployed subnet ID

## Usage Example

```hcl
module "vmss_runner" {
  source = "./buildingblock"

  azuredevops_org_url     = "https://dev.azure.com/myorg"
  azuredevops_project_id  = "12345678-1234-1234-1234-123456789012"
  azuredevops_pat         = var.azuredevops_pat
  service_endpoint_id     = module.service_connection.service_connection_id

  agent_pool_name = "production-runners"
  vmss_name       = "prod-vmss-runners"

  azure_subscription_id     = "11111111-2222-3333-4444-555555555555"
  azure_resource_group_name = "vmss-runners-rg"
  azure_location            = "eastus"

  spoke_vnet_name           = "spoke-prod-vnet"
  spoke_subnet_name         = "runner-subnet"
  spoke_resource_group_name = "networking-rg"

  ssh_public_key = file("~/.ssh/id_rsa.pub")

  vm_sku              = "Standard_D4s_v3"
  desired_idle_agents = 2
  max_capacity        = 20
  recycle_after_each_use = true

  tags = {
    environment = "production"
    managed_by  = "terraform"
  }
}
```

## Validation

The module includes validation for:
- OS disk type must be one of: `Standard_LRS`, `StandardSSD_LRS`, `Premium_LRS`
- `desired_idle_agents` must be between 0 and `max_capacity`
- `max_capacity` must be greater than 0

## Architecture

```
┌─────────────────────┐
│ Azure DevOps        │
│ ┌─────────────────┐ │
│ │  Agent Pool     │ │
│ │  (Elastic)      │ │
│ └────────┬────────┘ │
│          │          │
│ ┌────────▼────────┐ │
│ │  Agent Queue    │ │
│ │  (Project)      │ │
│ └─────────────────┘ │
└──────────┬──────────┘
           │
           │ Service Connection
           │
┌──────────▼──────────┐
│ Azure VMSS          │
│ ┌─────────────────┐ │
│ │ VM Instances    │ │
│ │ - Agent 1       │ │
│ │ - Agent 2       │ │
│ │ - Agent N       │ │
│ └─────────────────┘ │
│          │          │
│          │          │
│ ┌────────▼────────┐ │
│ │ Spoke Subnet    │ │
│ └─────────────────┘ │
└─────────────────────┘
```

## Security Considerations

- VMSS uses system-assigned managed identity
- Agents registered with secure PAT
- Network isolation via spoke subnet
- SSH key-based authentication
- Network Contributor role scoped to subnet only

## Scaling Behavior

The elastic pool automatically:
- Maintains `desired_idle_agents` ready agents
- Scales up to `max_capacity` under load
- Removes idle agents after `time_to_live_minutes`
- Recycles agents if `recycle_after_each_use` is enabled

## Troubleshooting

**Agents not registering:**
- Verify PAT has Agent Pools (Read & Manage) permissions
- Check service connection has access to subscription
- Ensure spoke subnet allows outbound internet access

**Scaling issues:**
- Verify `max_capacity` is sufficient
- Check Azure subscription VMSS quotas
- Review elastic pool configuration in Azure DevOps

**Network connectivity:**
- Ensure subnet NSG allows required traffic
- Verify VNet has route to internet for Azure DevOps access
- Check subnet has sufficient IP addresses
