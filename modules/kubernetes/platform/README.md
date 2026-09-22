---
name: Kubernetes meshPlatform Credentials
supportedPlatforms:
  - kubernetes
description: Creates the in-cluster replicator and metering service accounts meshStack authenticates with, and returns their tokens.
# The cluster kubeconfig is the only thing this needs, and it arrives as an input — there is
# nothing to set up cloud-side beforehand.
requiresBackplane: false
---

# Kubernetes meshPlatform Credentials Building Block

Creates the two in-cluster identities meshStack uses to drive a Kubernetes cluster, and hands their
tokens back:

- **replicator** (`meshfed-service`) — creates namespaces, resource quotas and role bindings for
  every tenant,
- **metering** (`meshfed-metering`) — reads pods and persistent volume claims to collect usage
  data, and can be switched off.

Each is a ServiceAccount, a `kubernetes.io/service-account-token` Secret, a ClusterRole and a
ClusterRoleBinding. Nothing cloud-specific is involved, so this runs on any conformant cluster.

## What it is not

It does **not** register a meshPlatform. Deciding that a cluster becomes a meshStack platform — its
identifier, location, landing zones and quota definitions — belongs to the composition that owns
the cluster, and the **STACKIT Kubernetes Platform** reference architecture does it in its own
`platform.tf` using the two tokens this block outputs.

## One set of identities per cluster

`meshfed-service` and `meshfed-metering` are ClusterRole names, which are cluster-global: two of
these deployed to the same cluster would collide. That is deliberate. Each platform ordered from
the reference architecture gets its own cluster, so the upstream module's name-suffix and
bring-your-own-ClusterRole machinery is not carried over. Reintroduce it if a single cluster ever
has to carry more than one meshStack platform registration.

## The tokens are populated before the run finishes

Kubernetes fills a service-account-token Secret asynchronously. Both Secrets here keep the
provider's `wait_for_service_account_token = true`, so the apply that creates them blocks until
`data.token` is set — which is what makes `replicator_token` and `metering_token` reliably
non-empty on the first run, with no sleep, poll or second apply.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role_binding_v1.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_binding_v1.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_cluster_role_v1.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_namespace_v1.meshcloud](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_secret_v1.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.metering](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [kubernetes_service_account_v1.replicator](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Raw kubeconfig (YAML) of the cluster the identities are created in — for example the `kubeconfig` output of the STACKIT SKE Cluster building block. The kubernetes provider is configured from it, so it must be a concrete value at plan time (i.e. supplied by a preceding building block, not created in this run). | `string` | n/a | yes |
| <a name="input_metering_additional_rules"></a> [metering\_additional\_rules](#input\_metering\_additional\_rules) | Extra RBAC rules added to the metering cluster role. | <pre>list(object({<br/>    api_groups        = list(string)<br/>    resources         = list(string)<br/>    verbs             = list(string)<br/>    resource_names    = optional(list(string))<br/>    non_resource_urls = optional(list(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_metering_enabled"></a> [metering\_enabled](#input\_metering\_enabled) | Create the metering service account. Turn this off when meshStack should not collect usage data from the cluster; `metering_token` is then null. | `bool` | `true` | no |
| <a name="input_replicator_additional_rules"></a> [replicator\_additional\_rules](#input\_replicator\_additional\_rules) | Extra RBAC rules added to the replicator cluster role. | <pre>list(object({<br/>    api_groups        = list(string)<br/>    resources         = list(string)<br/>    verbs             = list(string)<br/>    resource_names    = optional(list(string))<br/>    non_resource_urls = optional(list(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_service_account_namespace"></a> [service\_account\_namespace](#input\_service\_account\_namespace) | Namespace that holds the replicator and metering service accounts. | `string` | `"meshcloud"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_metering_service_account_name"></a> [metering\_service\_account\_name](#output\_metering\_service\_account\_name) | Name of the metering ServiceAccount and its companion resources. Null when metering\_enabled is false. |
| <a name="output_metering_token"></a> [metering\_token](#output\_metering\_token) | Service account token meshStack uses to read metering data from the cluster. Null when metering\_enabled is false. |
| <a name="output_replicator_service_account_name"></a> [replicator\_service\_account\_name](#output\_replicator\_service\_account\_name) | Name of the replicator ServiceAccount, its token Secret, its ClusterRole and its ClusterRoleBinding — all four share it. |
| <a name="output_replicator_token"></a> [replicator\_token](#output\_replicator\_token) | Service account token meshStack uses to replicate namespaces onto the cluster. |
| <a name="output_service_account_namespace"></a> [service\_account\_namespace](#output\_service\_account\_namespace) | Namespace holding the replicator and metering service accounts. |
<!-- END_TF_DOCS -->
