---
name: Azure AKS Namespace
supportedPlatforms:
  - azure
description: Creates a Kubernetes namespace on an existing AKS cluster with a resource quota, default container limits and Entra group access, ordered at workspace level.
---

# Azure AKS Namespace

Creates one namespace on an existing AKS cluster. It is a **workspace** building block: no meshStack
project, tenant or platform is involved. The block authenticates to the cluster as the backplane's
managed identity through workload identity federation and holds no kubeconfig.

## What it creates

- the namespace, labelled with the owning workspace
- a `ResourceQuota` and a `LimitRange` with default container requests and limits
- a `RoleBinding` per Entra group to the `admin`, `edit` or `view` cluster role

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.64.0, < 5.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.0, < 4.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.35.1, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_limit_range_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/limit_range_v1) | resource |
| [kubernetes_namespace_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_resource_quota_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/resource_quota_v1) | resource |
| [kubernetes_role_binding_v1.group](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_kubernetes_cluster.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/kubernetes_cluster) | data source |
| [http_http.aks_token](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_admin_group_object_ids"></a> [admin\_group\_object\_ids](#input\_admin\_group\_object\_ids) | Entra group object IDs granted the `admin` cluster role inside the namespace. | `list(string)` | `[]` | no |
| <a name="input_aks_cluster_name"></a> [aks\_cluster\_name](#input\_aks\_cluster\_name) | Name of the AKS cluster the namespace is created in. | `string` | n/a | yes |
| <a name="input_aks_resource_group_name"></a> [aks\_resource\_group\_name](#input\_aks\_resource\_group\_name) | Resource group of the AKS cluster. | `string` | n/a | yes |
| <a name="input_default_container_limits"></a> [default\_container\_limits](#input\_default\_container\_limits) | LimitRange defaults for containers that declare no requests or limits of their own. | <pre>object({<br/>    cpu_request    = optional(string, "100m")<br/>    memory_request = optional(string, "128Mi")<br/>    cpu_limit      = optional(string, "500m")<br/>    memory_limit   = optional(string, "512Mi")<br/>  })</pre> | `{}` | no |
| <a name="input_edit_group_object_ids"></a> [edit\_group\_object\_ids](#input\_edit\_group\_object\_ids) | Entra group object IDs granted the `edit` cluster role inside the namespace. | `list(string)` | `[]` | no |
| <a name="input_namespace_name"></a> [namespace\_name](#input\_namespace\_name) | Name of the Kubernetes namespace to create. | `string` | n/a | yes |
| <a name="input_oidc_token_file_path"></a> [oidc\_token\_file\_path](#input\_oidc\_token\_file\_path) | File the building block runner writes its federated OIDC token to. | `string` | `"/var/run/secrets/workload-identity/azure/token"` | no |
| <a name="input_resource_quota"></a> [resource\_quota](#input\_resource\_quota) | ResourceQuota applied to the namespace. | <pre>object({<br/>    requests_cpu    = optional(string, "2")<br/>    requests_memory = optional(string, "4Gi")<br/>    limits_cpu      = optional(string, "4")<br/>    limits_memory   = optional(string, "8Gi")<br/>    pods            = optional(string, "50")<br/>  })</pre> | `{}` | no |
| <a name="input_view_group_object_ids"></a> [view\_group\_object\_ids](#input\_view\_group\_object\_ids) | Entra group object IDs granted the `view` cluster role inside the namespace. | `list(string)` | `[]` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | Identifier of the meshStack workspace that owns the namespace. Recorded as a label. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the AKS cluster hosting the namespace. |
| <a name="output_cluster_resource_group_name"></a> [cluster\_resource\_group\_name](#output\_cluster\_resource\_group\_name) | Resource group of the AKS cluster hosting the namespace. |
| <a name="output_namespace_name"></a> [namespace\_name](#output\_namespace\_name) | Name of the created Kubernetes namespace. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
