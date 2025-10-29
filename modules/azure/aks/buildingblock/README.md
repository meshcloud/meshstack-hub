---
name: AKS Cluster
supportedPlatforms:
 - azure
description: |
  Provision a production-grade Azure Kubernetes Service (AKS) cluster with Azure AD, OIDC, Workload Identity, Log Analytics and custom VNet using Terraform.
category: compute
---

# AKS Building Block

This Terraform module provisions a production-ready [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/) cluster including:

- Azure AD-based authentication
- Workload Identity & OIDC issuer enabled
- Custom Virtual Network & Subnet
- Log Analytics integration (Monitoring)
- Auto-scaling node pool (optional)
- System-assigned managed identity

## 🚀 Features

- ✅ Production-grade configuration
- 🔐 Integrated Azure AD admin group
- ☁️ Log Analytics Workspace (LAW) with comprehensive diagnostics
- 🧠 OIDC issuer & Workload Identity support
- 🌐 Custom virtual network and subnet configuration
- 📈 Optional auto-scaling for system node pool
- 🔧 Configurable network plugins (Azure CNI, Kubenet) and policies (Azure, Calico, Cilium)

## Provider Requirements

This module uses **Azure Provider `~> 4.36.0`** because:
- Requires AKS workload identity and OIDC issuer features
- Tested and validated against 4.36.x patch versions
- Supports latest AKS cluster configuration options
- Allows automatic security patches via `~>` constraint

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.4.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.36.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | ~> 0.11.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_kubernetes_cluster.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_log_analytics_workspace.law](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_monitor_diagnostic_setting.aks_monitoring](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_resource_group.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |
| [azurerm_subnet.aks_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.aks_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.hub_to_aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [time_sleep.wait_for_subnet](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [azurerm_resource_group.hub_rg](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_virtual_network.hub_vnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/virtual_network) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aks_admin_group_object_id"></a> [aks\_admin\_group\_object\_id](#input\_aks\_admin\_group\_object\_id) | Object ID of the Azure AD group used for AKS admin access. If null, Azure AD RBAC will not be configured. | `string` | `null` | no |
| <a name="input_aks_cluster_name"></a> [aks\_cluster\_name](#input\_aks\_cluster\_name) | Name of the AKS cluster | `string` | `"prod-aks"` | no |
| <a name="input_dns_prefix"></a> [dns\_prefix](#input\_dns\_prefix) | DNS prefix for the AKS cluster | `string` | `"prodaks"` | no |
| <a name="input_dns_service_ip"></a> [dns\_service\_ip](#input\_dns\_service\_ip) | IP address for Kubernetes DNS service (must be within service\_cidr) | `string` | `"10.0.0.10"` | no |
| <a name="input_enable_auto_scaling"></a> [enable\_auto\_scaling](#input\_enable\_auto\_scaling) | Enable auto-scaling for the default node pool | `bool` | `false` | no |
| <a name="input_hub_resource_group_name"></a> [hub\_resource\_group\_name](#input\_hub\_resource\_group\_name) | Resource group name of the hub virtual network. Required when private\_cluster\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_subscription_id"></a> [hub\_subscription\_id](#input\_hub\_subscription\_id) | Subscription ID of the hub network. Required when private\_cluster\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_hub_vnet_name"></a> [hub\_vnet\_name](#input\_hub\_vnet\_name) | Name of the hub virtual network to peer with. Required when private\_cluster\_enabled is true and connecting to a hub. | `string` | `null` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for the AKS cluster | `string` | `"1.33.0"` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region where resources will be deployed | `string` | `"Germany West Central"` | no |
| <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name) | Name of the Log Analytics Workspace. If null, no LAW or monitoring will be created. | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | Number of days to retain logs in Log Analytics Workspace | `number` | `30` | no |
| <a name="input_max_node_count"></a> [max\_node\_count](#input\_max\_node\_count) | Maximum number of nodes for auto-scaling (set to enable auto-scaling) | `number` | `null` | no |
| <a name="input_min_node_count"></a> [min\_node\_count](#input\_min\_node\_count) | Minimum number of nodes for auto-scaling (set to enable auto-scaling) | `number` | `null` | no |
| <a name="input_network_plugin"></a> [network\_plugin](#input\_network\_plugin) | Network plugin to use (azure or kubenet) | `string` | `"azure"` | no |
| <a name="input_network_policy"></a> [network\_policy](#input\_network\_policy) | Network policy to use (azure, calico, or cilium) | `string` | `"azure"` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Initial number of nodes in the default node pool | `number` | `3` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | OS disk size in GB for the node pool | `number` | `100` | no |
| <a name="input_private_cluster_enabled"></a> [private\_cluster\_enabled](#input\_private\_cluster\_enabled) | Enable private cluster (API server only accessible via private endpoint) | `bool` | `false` | no |
| <a name="input_private_cluster_public_fqdn_enabled"></a> [private\_cluster\_public\_fqdn\_enabled](#input\_private\_cluster\_public\_fqdn\_enabled) | Enable public FQDN for private cluster (allows public DNS resolution but API server remains private) | `bool` | `false` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | Private DNS Zone ID for private cluster. Use 'System' for Azure-managed zone, or provide custom zone ID. Only used when private\_cluster\_enabled is true. | `string` | `"System"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group to create for the AKS cluster | `string` | `"aks-prod-rg"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | CIDR for Kubernetes services (must not overlap with VNet or subnet) | `string` | `"10.0.0.0/16"` | no |
| <a name="input_subnet_address_prefix"></a> [subnet\_address\_prefix](#input\_subnet\_address\_prefix) | Address prefix for the AKS subnet | `string` | `"10.240.0.0/20"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | Size of the virtual machines for the default node pool | `string` | `"Standard_DS3_v2"` | no |
| <a name="input_vnet_address_space"></a> [vnet\_address\_space](#input\_vnet\_address\_space) | Address space for the AKS virtual network | `string` | `"10.240.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aks_identity_client_id"></a> [aks\_identity\_client\_id](#output\_aks\_identity\_client\_id) | Client ID of the AKS system-assigned managed identity |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | Kubeconfig raw output |
| <a name="output_law_id"></a> [law\_id](#output\_law\_id) | Log Analytics Workspace ID |
| <a name="output_oidc_issuer_url"></a> [oidc\_issuer\_url](#output\_oidc\_issuer\_url) | OIDC issuer URL for federated identity and workload identity setup |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | Subnet ID used by AKS |
<!-- END_TF_DOCS -->
