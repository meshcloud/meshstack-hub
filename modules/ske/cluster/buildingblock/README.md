---
name: STACKIT SKE Cluster
supportedPlatforms:
  - stackit
description: Provisions a STACKIT Kubernetes Engine (SKE) cluster with a node pool and mints an admin kubeconfig.
---

# STACKIT SKE Cluster Building Block

This building block provisions a **STACKIT Kubernetes Engine (SKE)** cluster with a single node pool
and a nightly maintenance window, and mints an admin kubeconfig for it.

It exists so a composing architecture can create the cluster in its own apply and, once it exists,
read the kubeconfig back to configure `kubernetes`/`helm` providers and downstream building blocks —
a provider config cannot depend on a cluster created in the same apply.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.83.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [stackit_ske_cluster.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/ske_cluster) | resource |
| [stackit_ske_kubeconfig.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/ske_kubeconfig) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the SKE cluster. STACKIT caps SKE cluster names at 11 characters (lowercase alphanumeric and dashes). | `string` | n/a | yes |
| <a name="input_kubernetes_version_min"></a> [kubernetes\_version\_min](#input\_kubernetes\_version\_min) | Minimum Kubernetes minor version to run (e.g. `1.31`). Null lets STACKIT pick the current default; maintenance keeps it patched upward. | `string` | `null` | no |
| <a name="input_maintenance"></a> [maintenance](#input\_maintenance) | SKE maintenance window. Defaults to nightly automatic Kubernetes and machine-image updates between 01:00 and 02:00 UTC. | <pre>object({<br/>    enable_kubernetes_version_updates    = optional(bool, true)<br/>    enable_machine_image_version_updates = optional(bool, true)<br/>    start                                = optional(string, "01:00:00Z")<br/>    end                                  = optional(string, "02:00:00Z")<br/>  })</pre> | `{}` | no |
| <a name="input_node_pool"></a> [node\_pool](#input\_node\_pool) | Single node pool the cluster starts with. Defaults to a small general-purpose pool (`g2i.2`, 1-3 nodes) in `eu01-1`. | <pre>object({<br/>    name               = optional(string, "pool-1")<br/>    machine_type       = optional(string, "g2i.2")<br/>    minimum            = optional(number, 1)<br/>    maximum            = optional(number, 3)<br/>    availability_zones = optional(list(string), ["eu01-1"])<br/>    max_surge          = optional(number, 1)<br/>  })</pre> | `{}` | no |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project UUID the SKE cluster is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the cluster and its node pool are placed in. | `string` | `"eu01"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the SKE cluster. |
| <a name="output_cluster_url"></a> [cluster\_url](#output\_cluster\_url) | Deep link to the STACKIT project the cluster lives in, in the STACKIT portal. |
| <a name="output_kube_host"></a> [kube\_host](#output\_kube\_host) | Kubernetes API server URL of the cluster. |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Raw kubeconfig content for cluster access. |
| <a name="output_provider_config"></a> [provider\_config](#output\_provider\_config) | Decoded kubeconfig values for wiring a kubernetes/helm provider without re-parsing the raw kubeconfig. |
<!-- END_TF_DOCS -->
