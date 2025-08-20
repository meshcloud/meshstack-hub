---
name: AKS Cluster
supportedPlatforms:
 - azure
description: |
  Provision a production-grade Azure Kubernetes Service (AKS) cluster with Azure AD, OIDC, Workload Identity, Log Analytics and custom VNet using Terraform.
---

# AKS Building Block

This Terraform module provisions a production-ready [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/) cluster including:

- Azure AD-based authentication
- Workload Identity & OIDC issuer enabled
- Custom Virtual Network & Subnet
- Log Analytics integration (Monitoring)
- Auto-scaling node pool
- System-assigned managed identity

## 🚀 Features

- ✅ Production-grade configuration
- 🔐 Integrated Azure AD admin group
- ☁️ Log Analytics Workspace (LAW) with `oms_agent`
- 🧠 OIDC issuer & Workload Identity support
- 🌐 Custom virtual network and subnet
- 📈 Auto-scaling system node pool

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | 3.4.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 4.36.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_kubernetes_cluster.aks](https://registry.terraform.io/providers/hashicorp/azurerm/4.36.0/docs/resources/kubernetes_cluster) | resource |
| [azurerm_log_analytics_workspace.law](https://registry.terraform.io/providers/hashicorp/azurerm/4.36.0/docs/resources/log_analytics_workspace) | resource |
| [azurerm_monitor_diagnostic_setting.aks_monitoring](https://registry.terraform.io/providers/hashicorp/azurerm/4.36.0/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_resource_group.aks](https://registry.terraform.io/providers/hashicorp/azurerm/4.36.0/docs/resources/resource_group) | resource |
| [azurerm_subnet.aks_subnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.36.0/docs/resources/subnet) | resource |
| [azurerm_virtual_network.vnet](https://registry.terraform.io/providers/hashicorp/azurerm/4.36.0/docs/resources/virtual_network) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aks_admin_group_object_id"></a> [aks\_admin\_group\_object\_id](#input\_aks\_admin\_group\_object\_id) | Object ID of the Azure AD group used for AKS admin access | `string` | n/a | yes |
| <a name="input_aks_cluster_name"></a> [aks\_cluster\_name](#input\_aks\_cluster\_name) | n/a | `string` | `"prod-aks"` | no |
| <a name="input_dns_prefix"></a> [dns\_prefix](#input\_dns\_prefix) | n/a | `string` | `"prodaks"` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | n/a | `string` | `"1.29.2"` | no |
| <a name="input_location"></a> [location](#input\_location) | n/a | `string` | `"Germany West Central"` | no |
| <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name) | Name of the Log Analytics Workspace. If null, no LAW or monitoring will be created. | `string` | `null` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | n/a | `number` | `3` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | n/a | `string` | `"aks-prod-rg"` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | n/a | `string` | `"Standard_DS3_v2"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aks_identity_client_id"></a> [aks\_identity\_client\_id](#output\_aks\_identity\_client\_id) | Client ID of the AKS system-assigned managed identity |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | Kubeconfig raw output |
| <a name="output_law_id"></a> [law\_id](#output\_law\_id) | Log Analytics Workspace ID |
| <a name="output_oidc_issuer_url"></a> [oidc\_issuer\_url](#output\_oidc\_issuer\_url) | OIDC issuer URL for federated identity and workload identity setup |
| <a name="output_subnet_id"></a> [subnet\_id](#output\_subnet\_id) | Subnet ID used by AKS |
<!-- END_TF_DOCS -->
