# SKE Backplane

This module provisions the STACKIT Kubernetes Engine (SKE) cluster and sets up the
meshStack platform integration (replicator and metering service accounts).

## What it creates

- **SKE Cluster** with a configurable node pool (machine type, count, availability zones)
- **Kubeconfig** for cluster access (180-day expiration, auto-refresh)
- **meshStack platform integration** via [terraform-kubernetes-meshplatform](https://github.com/meshcloud/terraform-kubernetes-meshplatform):
  - Replicator service account for namespace provisioning
  - Metering service account for usage data collection

## Usage

This module is called from `meshstack_integration.tf` and its outputs are wired into the
`meshstack_platform` resource's `config.kubernetes` block.

```hcl
module "backplane" {
  source = "./backplane"

  stackit_project_id = "your-project-id"
  cluster_name       = "ske-cluster"
  region             = "eu01"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.68.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_meshplatform"></a> [meshplatform](#module\_meshplatform) | git::https://github.com/meshcloud/terraform-kubernetes-meshplatform.git | v0.1.0 |

## Resources

| Name | Type |
|------|------|
| [stackit_ske_cluster.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/ske_cluster) | resource |
| [stackit_ske_kubeconfig.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/ske_kubeconfig) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Availability zones for the default node pool. | `list(string)` | <pre>[<br>  "eu01-1"<br>]</pre> | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the SKE cluster. | `string` | `"ske-cluster"` | no |
| <a name="input_enable_kubernetes_version_updates"></a> [enable\_kubernetes\_version\_updates](#input\_enable\_kubernetes\_version\_updates) | Enable automatic Kubernetes version updates during maintenance windows. | `bool` | `true` | no |
| <a name="input_enable_machine_image_version_updates"></a> [enable\_machine\_image\_version\_updates](#input\_enable\_machine\_image\_version\_updates) | Enable automatic machine image version updates during maintenance windows. | `bool` | `true` | no |
| <a name="input_machine_type"></a> [machine\_type](#input\_machine\_type) | Machine type for the default node pool. | `string` | `"c2i.2"` | no |
| <a name="input_maintenance_end"></a> [maintenance\_end](#input\_maintenance\_end) | End of the maintenance window (UTC). | `string` | `"06:00:00Z"` | no |
| <a name="input_maintenance_start"></a> [maintenance\_start](#input\_maintenance\_start) | Start of the maintenance window (UTC). | `string` | `"02:00:00Z"` | no |
| <a name="input_meshplatform_namespace"></a> [meshplatform\_namespace](#input\_meshplatform\_namespace) | Kubernetes namespace for the meshStack platform integration (replicator + metering service accounts). | `string` | `"meshcloud"` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | Number of nodes in the default node pool. | `number` | `1` | no |
| <a name="input_region"></a> [region](#input\_region) | STACKIT region for the SKE cluster. | `string` | `"eu01"` | no |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project ID where the SKE cluster will be created. | `string` | n/a | yes |
| <a name="input_volume_size"></a> [volume\_size](#input\_volume\_size) | Volume size in GB for nodes in the default node pool. | `number` | `25` | no |
| <a name="input_volume_type"></a> [volume\_type](#input\_volume\_type) | Volume type for nodes in the default node pool. | `string` | `"storage_premium_perf0"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_client_certificate"></a> [client\_certificate](#output\_client\_certificate) | PEM-encoded client certificate for authentication. |
| <a name="output_client_key"></a> [client\_key](#output\_client\_key) | PEM-encoded client key for authentication. |
| <a name="output_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#output\_cluster\_ca\_certificate) | PEM-encoded CA certificate for the cluster. |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the SKE cluster. |
| <a name="output_console_url"></a> [console\_url](#output\_console\_url) | URL to the STACKIT portal for this SKE cluster. |
| <a name="output_kube_host"></a> [kube\_host](#output\_kube\_host) | Kubernetes API server endpoint. |
| <a name="output_kubernetes_version"></a> [kubernetes\_version](#output\_kubernetes\_version) | Kubernetes version running on the cluster. |
| <a name="output_metering_token"></a> [metering\_token](#output\_metering\_token) | Access token for the meshStack metering service account. |
| <a name="output_replicator_token"></a> [replicator\_token](#output\_replicator\_token) | Access token for the meshStack replicator service account. |
<!-- END_TF_DOCS -->