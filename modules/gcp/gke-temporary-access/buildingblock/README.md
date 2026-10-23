---
name: GKE Temporary Namespace Access
supportedPlatforms:
  - gcp
description: Grants a developer time-limited access to one namespace of a GKE cluster, on their own Google identity.
---

# GKE Temporary Namespace Access

This module grants the requesting developer access to one namespace of a GKE cluster for 1 to 8
hours. It makes two grants to the developer's Google identity:

- `roles/container.clusterViewer` on the project, with an IAM condition that expires.
- A RoleBinding to `cluster_role` in the namespace, labelled and annotated with its expiry for the
  backplane's cleanup CronJob.

The expiry is fixed on the first run. A run after expiry removes both grants instead of recreating
them.

The `kubernetes` provider authenticates as the building block's own service account, using the
cluster's public endpoint.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0, < 8.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_project_iam_member.cluster_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [kubernetes_role_binding_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [time_static.requested_at](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [google_client_config.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |
| [google_container_cluster.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_author"></a> [author](#input\_author) | The meshStack user who requested access. They receive the access on their Google identity, which must use the same email. | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_binding_label"></a> [binding\_label](#input\_binding\_label) | Label the cleanup CronJob selects RoleBindings by. Take it from the backplane's `binding_label` output. | `string` | n/a | yes |
| <a name="input_cluster_location"></a> [cluster\_location](#input\_cluster\_location) | Region or zone of the GKE cluster. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the GKE cluster. | `string` | n/a | yes |
| <a name="input_cluster_role"></a> [cluster\_role](#input\_cluster\_role) | ClusterRole to bind the developer to. Take it from the backplane's `cluster_role` output. | `string` | n/a | yes |
| <a name="input_duration_hours"></a> [duration\_hours](#input\_duration\_hours) | How many hours the access lasts, counted from the first run. | `number` | n/a | yes |
| <a name="input_expiry_annotation"></a> [expiry\_annotation](#input\_expiry\_annotation) | Annotation the cleanup CronJob reads the expiry from. Take it from the backplane's `expiry_annotation` output. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to grant access to. Must be one of the namespaces the backplane offers. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID that contains the GKE cluster. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_expires_at"></a> [expires\_at](#output\_expires\_at) | When the access ends, in UTC RFC 3339. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
