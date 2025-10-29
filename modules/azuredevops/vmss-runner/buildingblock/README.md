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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | ~> 1.1.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuredevops_agent_pool.vmss](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/agent_pool) | resource |
| [azuredevops_agent_queue.vmss](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/agent_queue) | resource |
| [azuredevops_elastic_pool.vmss](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/elastic_pool) | resource |
| [azurerm_linux_virtual_machine_scale_set.vmss](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine_scale_set) | resource |
| [azurerm_role_assignment.vmss_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subnet.spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_pool_name"></a> [agent\_pool\_name](#input\_agent\_pool\_name) | Name of the Azure DevOps agent pool | `string` | n/a | yes |
| <a name="input_agent_script_url"></a> [agent\_script\_url](#input\_agent\_script\_url) | URL to the agent installation script | `string` | `"https://raw.githubusercontent.com/microsoft/azure-pipelines-agent/master/docs/start/envlinux.md"` | no |
| <a name="input_azure_location"></a> [azure\_location](#input\_azure\_location) | Azure region for VMSS deployment | `string` | n/a | yes |
| <a name="input_azure_resource_group_name"></a> [azure\_resource\_group\_name](#input\_azure\_resource\_group\_name) | Name of the Azure resource group for VMSS | `string` | n/a | yes |
| <a name="input_azure_subscription_id"></a> [azure\_subscription\_id](#input\_azure\_subscription\_id) | Azure subscription ID where VMSS will be created | `string` | n/a | yes |
| <a name="input_azuredevops_org_url"></a> [azuredevops\_org\_url](#input\_azuredevops\_org\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_azuredevops_pat"></a> [azuredevops\_pat](#input\_azuredevops\_pat) | Azure DevOps Personal Access Token for agent registration | `string` | n/a | yes |
| <a name="input_azuredevops_project_id"></a> [azuredevops\_project\_id](#input\_azuredevops\_project\_id) | ID of the Azure DevOps project | `string` | n/a | yes |
| <a name="input_desired_idle_agents"></a> [desired\_idle\_agents](#input\_desired\_idle\_agents) | Number of idle agents to maintain | `number` | `1` | no |
| <a name="input_image_offer"></a> [image\_offer](#input\_image\_offer) | Offer of the VM image | `string` | `"0001-com-ubuntu-server-jammy"` | no |
| <a name="input_image_publisher"></a> [image\_publisher](#input\_image\_publisher) | Publisher of the VM image | `string` | `"Canonical"` | no |
| <a name="input_image_sku"></a> [image\_sku](#input\_image\_sku) | SKU of the VM image | `string` | `"22_04-lts-gen2"` | no |
| <a name="input_image_version"></a> [image\_version](#input\_image\_version) | Version of the VM image | `string` | `"latest"` | no |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Maximum number of agents in the pool | `number` | `10` | no |
| <a name="input_os_disk_type"></a> [os\_disk\_type](#input\_os\_disk\_type) | Type of OS disk storage | `string` | `"Premium_LRS"` | no |
| <a name="input_recycle_after_each_use"></a> [recycle\_after\_each\_use](#input\_recycle\_after\_each\_use) | Whether to recycle the agent after each job | `bool` | `false` | no |
| <a name="input_service_endpoint_id"></a> [service\_endpoint\_id](#input\_service\_endpoint\_id) | ID of the Azure service connection for VMSS management | `string` | n/a | yes |
| <a name="input_spoke_resource_group_name"></a> [spoke\_resource\_group\_name](#input\_spoke\_resource\_group\_name) | Name of the resource group containing the spoke virtual network | `string` | n/a | yes |
| <a name="input_spoke_subnet_name"></a> [spoke\_subnet\_name](#input\_spoke\_subnet\_name) | Name of the subnet in the spoke virtual network | `string` | n/a | yes |
| <a name="input_spoke_vnet_name"></a> [spoke\_vnet\_name](#input\_spoke\_vnet\_name) | Name of the spoke virtual network | `string` | n/a | yes |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key for VM access | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to Azure resources | `map(string)` | `{}` | no |
| <a name="input_time_to_live_minutes"></a> [time\_to\_live\_minutes](#input\_time\_to\_live\_minutes) | Time in minutes before an idle agent is removed | `number` | `30` | no |
| <a name="input_vm_sku"></a> [vm\_sku](#input\_vm\_sku) | SKU of the virtual machines in the scale set | `string` | `"Standard_D2s_v3"` | no |
| <a name="input_vmss_name"></a> [vmss\_name](#input\_vmss\_name) | Name of the Virtual Machine Scale Set | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_pool_id"></a> [agent\_pool\_id](#output\_agent\_pool\_id) | ID of the Azure DevOps agent pool |
| <a name="output_agent_pool_name"></a> [agent\_pool\_name](#output\_agent\_pool\_name) | Name of the Azure DevOps agent pool |
| <a name="output_agent_queue_id"></a> [agent\_queue\_id](#output\_agent\_queue\_id) | ID of the agent queue in the project |
| <a name="output_elastic_pool_id"></a> [elastic\_pool\_id](#output\_elastic\_pool\_id) | ID of the elastic pool configuration |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | ID of the subnet where VMSS is deployed |
| <a name="output_vmss_id"></a> [vmss\_id](#output\_vmss\_id) | ID of the Virtual Machine Scale Set |
| <a name="output_vmss_name"></a> [vmss\_name](#output\_vmss\_name) | Name of the Virtual Machine Scale Set |
| <a name="output_vmss_principal_id"></a> [vmss\_principal\_id](#output\_vmss\_principal\_id) | Managed identity principal ID of the VMSS |
<!-- END_TF_DOCS -->