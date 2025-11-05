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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | ~> 1.1.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.51.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuredevops_agent_queue.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/agent_queue) | resource |
| [azuredevops_elastic_pool.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/elastic_pool) | resource |
| [azuredevops_pipeline_authorization.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/pipeline_authorization) | resource |
| [azurerm_key_vault.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.azure_devops_pat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |
| [azurerm_virtual_machine_scale_set.existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_machine_scale_set) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_interactive_ui"></a> [agent\_interactive\_ui](#input\_agent\_interactive\_ui) | Enable agents to run with interactive UI | `bool` | `false` | no |
| <a name="input_agent_pool_name"></a> [agent\_pool\_name](#input\_agent\_pool\_name) | Name of the Azure DevOps agent pool | `string` | n/a | yes |
| <a name="input_auto_provision"></a> [auto\_provision](#input\_auto\_provision) | Automatically provision projects with this agent pool | `bool` | `false` | no |
| <a name="input_auto_update"></a> [auto\_update](#input\_auto\_update) | Automatically update agents in this pool | `bool` | `true` | no |
| <a name="input_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#input\_azure\_devops\_organization\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_desired_idle"></a> [desired\_idle](#input\_desired\_idle) | Number of agents to keep idle and ready to run jobs | `number` | `1` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault containing the Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_max_capacity"></a> [max\_capacity](#input\_max\_capacity) | Maximum number of virtual machines in the scale set | `number` | `10` | no |
| <a name="input_pat_secret_name"></a> [pat\_secret\_name](#input\_pat\_secret\_name) | Name of the Azure DevOps PAT Token stored in the KeyVault | `string` | `"azure-devops-pat"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Azure DevOps project ID to authorize the agent pool (optional) | `string` | `null` | no |
| <a name="input_recycle_after_each_use"></a> [recycle\_after\_each\_use](#input\_recycle\_after\_each\_use) | Tear down the virtual machine after each use | `bool` | `false` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Resource group name containing the Key Vault | `string` | n/a | yes |
| <a name="input_service_endpoint_id"></a> [service\_endpoint\_id](#input\_service\_endpoint\_id) | ID of the Azure service connection for the elastic pool | `string` | n/a | yes |
| <a name="input_service_endpoint_scope"></a> [service\_endpoint\_scope](#input\_service\_endpoint\_scope) | Project ID where the service endpoint is defined | `string` | n/a | yes |
| <a name="input_time_to_live_minutes"></a> [time\_to\_live\_minutes](#input\_time\_to\_live\_minutes) | Time in minutes to keep idle agents before removing them | `number` | `30` | no |
| <a name="input_vmss_name"></a> [vmss\_name](#input\_vmss\_name) | Name of the existing Azure Virtual Machine Scale Set | `string` | n/a | yes |
| <a name="input_vmss_resource_group_name"></a> [vmss\_resource\_group\_name](#input\_vmss\_resource\_group\_name) | Resource group name containing the VMSS | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_agent_pool_id"></a> [agent\_pool\_id](#output\_agent\_pool\_id) | ID of the created Azure DevOps agent pool |
| <a name="output_agent_pool_name"></a> [agent\_pool\_name](#output\_agent\_pool\_name) | Name of the created Azure DevOps agent pool |
| <a name="output_agent_queue_id"></a> [agent\_queue\_id](#output\_agent\_queue\_id) | ID of the agent queue in the project |
| <a name="output_desired_idle"></a> [desired\_idle](#output\_desired\_idle) | Number of desired idle agents |
| <a name="output_elastic_pool_id"></a> [elastic\_pool\_id](#output\_elastic\_pool\_id) | ID of the elastic pool configuration |
| <a name="output_max_capacity"></a> [max\_capacity](#output\_max\_capacity) | Maximum capacity of the elastic pool |
| <a name="output_vmss_id"></a> [vmss\_id](#output\_vmss\_id) | Azure Resource ID of the VMSS |
<!-- END_TF_DOCS -->