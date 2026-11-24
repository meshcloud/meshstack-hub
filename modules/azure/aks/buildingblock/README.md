---
name: AKS Cluster
supportedPlatforms:
 - azure
description: |
  Provision an Azure Kubernetes Service (AKS) cluster with its own vnet, OIDC issuer, workload identity, and an optional private API server peered into a hub vnet.
---

# AKS Building Block

This module creates an [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/) cluster in the subscription of a meshStack tenant:

- a resource group with a new vnet and subnet, or an existing vnet and subnet
- the cluster with a system-assigned identity, Azure RBAC, an OIDC issuer and workload identity
- optional: a private API server, with a two-way peering into a hub vnet
- optional: a Log Analytics workspace that receives the control plane logs
- optional: auto-scaling of the default node pool

`meshstack_integration.tf` registers it as a building block definition. Application teams choose
the cluster name, resource group, DNS prefix, node count and size, Kubernetes version, whether the
cluster is private, and the address ranges. The other variables keep their defaults there.

## Provider configuration

The module configures two `azurerm` providers. Both authenticate through the `ARM_*` environment
variables the building block definition sets. The default provider works in `subscription_id`, the
tenant's subscription. The `hub` provider works in `hub_subscription_id` and falls back to
`subscription_id` when no hub is set.

## Network scenarios

| Scenario | Variables |
|---|---|
| Public cluster, new vnet (default) | `private_cluster_enabled = false` |
| Private cluster, new vnet, no hub | `private_cluster_enabled = true` |
| Private cluster, new vnet peered into the hub | `private_cluster_enabled = true`, `hub_subscription_id`, `hub_resource_group_name`, `hub_vnet_name` |
| Existing vnet and subnet | `vnet_name`, `subnet_name`, `existing_vnet_resource_group_name` |

A private cluster that peers into the hub sends its outbound traffic through a route table
(`outbound_type = "userDefinedRouting"`). The module creates the route table without routes, so the
hub must provide the default route, for example through a firewall. With an existing vnet, the
module creates no peering; the owner of the vnet manages it.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.36.0, < 5.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11.1, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_kubernetes_cluster.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_log_analytics_workspace.law](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_monitor_diagnostic_setting.aks_monitoring](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_resource_group.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_route_table.aks_rt](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |
| [azurerm_subnet.aks_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_route_table_association.aks_subnet_rt](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.aks_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.hub_to_aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [time_sleep.wait_for_subnet](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_resource_group.hub_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_subnet.existing_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subnet) | data source |
| [azurerm_virtual_network.existing_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |
| [azurerm_virtual_network.hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aks_admin_group_object_id"></a> [aks\_admin\_group\_object\_id](#input\_aks\_admin\_group\_object\_id) | Object ID of the Azure AD group used for AKS admin access. If null, Azure AD RBAC will not be configured. | `string` | `null` | no |
| <a name="input_aks_cluster_name"></a> [aks\_cluster\_name](#input\_aks\_cluster\_name) | Name of the AKS cluster | `string` | n/a | yes |
| <a name="input_allow_gateway_transit_from_hub"></a> [allow\_gateway\_transit\_from\_hub](#input\_allow\_gateway\_transit\_from\_hub) | Allow gateway transit from hub to spoke. Set to true if hub has a gateway and you want spoke to use it. | `bool` | `false` | no |
| <a name="input_dns_prefix"></a> [dns\_prefix](#input\_dns\_prefix) | DNS prefix for the AKS cluster | `string` | n/a | yes |
| <a name="input_dns_service_ip"></a> [dns\_service\_ip](#input\_dns\_service\_ip) | IP address for Kubernetes DNS service (must be within service\_cidr) | `string` | `"10.0.0.10"` | no |
| <a name="input_enable_auto_scaling"></a> [enable\_auto\_scaling](#input\_enable\_auto\_scaling) | Enable auto-scaling for the default node pool | `bool` | `false` | no |
| <a name="input_existing_vnet_resource_group_name"></a> [existing\_vnet\_resource\_group\_name](#input\_existing\_vnet\_resource\_group\_name) | Resource group name of the existing VNet. Only used when vnet\_name is provided. Defaults to the AKS resource group if not specified. | `string` | `null` | no |
| <a name="input_hub_resource_group_name"></a> [hub\_resource\_group\_name](#input\_hub\_resource\_group\_name) | Resource group name of the hub virtual network. Required when private\_cluster\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_subscription_id"></a> [hub\_subscription\_id](#input\_hub\_subscription\_id) | Subscription ID of the hub network. Required when private\_cluster\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_vnet_name"></a> [hub\_vnet\_name](#input\_hub\_vnet\_name) | Name of the hub virtual network to peer with. Required when private\_cluster\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for the AKS cluster. Null lets AKS choose the version it recommends today, 1.34 takes the latest patch in that minor, 1.34.2 pins one. A pinned version needs maintenance: AKS moves a minor to LTS-only when its community support ends, and creating a cluster on it then fails. | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where resources will be deployed | `string` | n/a | yes |
| <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name) | Name of the Log Analytics Workspace. If null, no LAW or monitoring will be created. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs in Log Analytics Workspace | `number` | `30` | no |
| <a name="input_max_node_count"></a> [max\_node\_count](#input\_max\_node\_count) | Maximum number of nodes for auto-scaling (set to enable auto-scaling) | `number` | `null` | no |
| <a name="input_min_node_count"></a> [min\_node\_count](#input\_min\_node\_count) | Minimum number of nodes for auto-scaling (set to enable auto-scaling) | `number` | `null` | no |
| <a name="input_network_plugin"></a> [network\_plugin](#input\_network\_plugin) | Network plugin to use (azure or kubenet) | `string` | `"azure"` | no |
| <a name="input_network_policy"></a> [network\_policy](#input\_network\_policy) | Network policy to use (azure, calico, or cilium) | `string` | `"azure"` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Initial number of nodes in the default node pool | `number` | n/a | yes |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size in GB for the node pool | `number` | `100` | no |
| <a name="input_private_cluster_enabled"></a> [private\_cluster\_enabled](#input\_private\_cluster\_enabled) | Enable private cluster (API server only accessible via private endpoint) | `bool` | n/a | yes |
| <a name="input_private_cluster_public_fqdn_enabled"></a> [private\_cluster\_public\_fqdn\_enabled](#input\_private\_cluster\_public\_fqdn\_enabled) | Enable public FQDN for private cluster (allows public DNS resolution but API server remains private) | `bool` | `false` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | Private DNS Zone ID for private cluster. Use 'System' for Azure-managed zone, or provide custom zone ID. Only used when private\_cluster\_enabled is true. | `string` | `"System"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group to create for the AKS cluster | `string` | n/a | yes |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | CIDR for Kubernetes services (must not overlap with VNet or subnet) | `string` | `"10.0.0.0/16"` | no |
| <a name="input_subnet_address_prefix"></a> [subnet\_address\_prefix](#input\_subnet\_address\_prefix) | Address prefix for the AKS subnet (only used if subnet\_name is not provided) | `string` | n/a | yes |
| <a name="input_subnet_name"></a> [subnet\_name](#input\_subnet\_name) | Name of the subnet for AKS. If not provided, a new subnet will be created. | `string` | `null` | no |
| <a name="input_subscription_id"></a> [subscription\_id](#input\_subscription\_id) | The Azure subscription the cluster is created in, the tenant's landing zone. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Size of the virtual machines for the default node pool | `string` | n/a | yes |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | Address space for the AKS virtual network (only used if vnet\_name is not provided) | `string` | n/a | yes |
| <a name="input_vnet_name"></a> [vnet\_name](#input\_vnet\_name) | Name of the virtual network for AKS. If not provided, a new VNet will be created. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aks_cluster_id"></a> [aks\_cluster\_id](#output\_aks\_cluster\_id) | Azure resource ID of the AKS cluster |
| <a name="output_aks_cluster_name"></a> [aks\_cluster\_name](#output\_aks\_cluster\_name) | Name of the AKS cluster |
| <a name="output_aks_identity_client_id"></a> [aks\_identity\_client\_id](#output\_aks\_identity\_client\_id) | Client ID of the AKS system-assigned managed identity |
| <a name="output_aks_portal_url"></a> [aks\_portal\_url](#output\_aks\_portal\_url) | Azure Portal URL of the AKS cluster |
| <a name="output_kube_api_server_fqdn"></a> [kube\_api\_server\_fqdn](#output\_kube\_api\_server\_fqdn) | FQDN of the Kubernetes API server, the private one for a private cluster |
| <a name="output_law_id"></a> [law\_id](#output\_law\_id) | Log Analytics Workspace ID |
| <a name="output_oidc_issuer_url"></a> [oidc\_issuer\_url](#output\_oidc\_issuer\_url) | OIDC issuer URL for federated identity and workload identity setup |
| <a name="output_resource_group_name"></a> [resource\_group\_name](#output\_resource\_group\_name) | Resource group holding the AKS cluster |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | Subnet ID used by AKS |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
