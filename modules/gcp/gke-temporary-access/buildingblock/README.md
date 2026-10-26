---
name: GKE Temporary Namespace Access
supportedPlatforms:
  - gcp
description: Grants a developer time-limited access to a namespace of a GKE cluster using their Google account.
---

# GKE Temporary Namespace Access

This module grants the requesting developer access to one namespace of a GKE cluster for up to 8
hours. It adds two grants to the developer's Google identity:

- `roles/container.clusterViewer` on the project, with an IAM condition that expires.
- A RoleBinding to `cluster_role` in the namespace, labelled and annotated with its expiry.

The namespace must exist and must not be forbidden by the backplane. The duration is measured from
the first run. Rerunning with the same duration does not extend access. A run after expiry removes
both grants instead of recreating them.

The conditional IAM grant expires at the requested time. If another IAM grant still allows the
developer to authenticate, the backplane's cleanup CronJob removes this building block's RoleBinding
on its next successful run. It runs every five minutes. Independently granted access is unaffected.

The `kubernetes` provider authenticates as the building block's own service account, against the
`cluster_endpoint` and `cluster_ca_certificate` passed in.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_google"></a> [google](#requirement\_google) | >= 7.0, < 8.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0, < 4.0.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [google_project_iam_member.cluster_viewer](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/project_iam_member) | resource |
| [kubernetes_role_binding_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [random_uuid.grant_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) | resource |
| [time_static.requested_at](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [google_client_config.this](https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_author"></a> [author](#input\_author) | The meshStack user who requested access. Access is granted to their Google account, whose email address must match their meshStack email. | <pre>object({<br/>    type        = string<br/>    identifier  = string<br/>    displayName = string<br/>    username    = optional(string)<br/>    email       = optional(string)<br/>    euid        = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_binding_label"></a> [binding\_label](#input\_binding\_label) | Label key used to identify managed RoleBindings. The building block sets its value to `true`. Take it from the backplane's `binding_label` output. | `string` | n/a | yes |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | Base64-encoded CA certificate of the cluster's control plane. | `string` | n/a | yes |
| <a name="input_cluster_endpoint"></a> [cluster\_endpoint](#input\_cluster\_endpoint) | IP address or hostname of the cluster's control plane. | `string` | n/a | yes |
| <a name="input_cluster_location"></a> [cluster\_location](#input\_cluster\_location) | Region or zone of the GKE cluster. | `string` | n/a | yes |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the GKE cluster. | `string` | n/a | yes |
| <a name="input_cluster_role"></a> [cluster\_role](#input\_cluster\_role) | ClusterRole to bind the developer to. Take it from the backplane's `cluster_role` output. | `string` | n/a | yes |
| <a name="input_duration_hours"></a> [duration\_hours](#input\_duration\_hours) | Access duration in whole hours, from 1 to 8, measured from the first run. | `number` | n/a | yes |
| <a name="input_expiry_annotation"></a> [expiry\_annotation](#input\_expiry\_annotation) | Annotation key used to store the RoleBinding's expiry timestamp in RFC 3339 format (UTC). Take it from the backplane's `expiry_annotation` output. | `string` | n/a | yes |
| <a name="input_forbidden_namespaces"></a> [forbidden\_namespaces](#input\_forbidden\_namespaces) | Namespaces developers can't request access to. A trailing `*` matches a prefix. Take it from the backplane's `forbidden_namespaces` output. | `set(string)` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to grant access to. Must exist and must not be forbidden. | `string` | n/a | yes |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | GCP project ID that contains the GKE cluster. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_expires_at"></a> [expires\_at](#output\_expires\_at) | Access expiry timestamp in RFC 3339 format (UTC). |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
