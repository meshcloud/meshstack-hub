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

Each is a ServiceAccount, a ClusterRole, a ClusterRoleBinding and `kubernetes.io/service-account-token`
Secrets named `<name>-token-<YYYY-MM>`: one for the month in `token_generation` and one for the
month before. The block returns the current tokens, so a composition that passes the current month
rotates them monthly while the previous tokens stay valid for another month. Nothing cloud-specific
is involved, so this runs on any conformant cluster.

## What it is not

It does **not** register a meshPlatform. Deciding that a cluster becomes a meshStack platform — its
identifier, location, landing zones and quota definitions — belongs to the composition that owns
the cluster, and the **STACKIT Kubernetes Platform** reference architecture does it in its own
`platform.tf` using the two tokens this block outputs. With `output_to_vault` set, it writes them to
the Vault KV v2 secret `<path_prefix>kubernetes/platform` under the keys `replicator-token` and
`metering-token` instead, and both outputs are empty.

## The kubeconfig is an input of the building block

The block reaches the cluster through `kubeconfig.yaml`, a sensitive FILE input the ordering
composition sets on the building block, so a rotated kubeconfig changes no definition.

## One set of identities per cluster

`meshfed-service` and `meshfed-metering` are ClusterRole names, which are cluster-global: two of
these deployed to the same cluster would collide. That is deliberate. Each platform ordered from
the reference architecture gets its own cluster, so the upstream module's name-suffix and
bring-your-own-ClusterRole machinery is not carried over. Reintroduce it if a single cluster ever
has to carry more than one meshStack platform registration.

## The tokens are populated before the run finishes

Kubernetes fills a service-account-token Secret asynchronously. The token Secrets here keep the
provider's `wait_for_service_account_token = true`, so the apply that creates them blocks until
`data.token` is set — which is what makes `replicator_token` and `metering_token` reliably
non-empty on the first run, with no sleep, poll or second apply.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 5.12.0, < 6.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_namespace"></a> [namespace](#module\_namespace) | ./modules/namespace | n/a |
| <a name="module_service_accounts"></a> [service\_accounts](#module\_service\_accounts) | ./modules/service-account | n/a |

## Resources

| Name | Type |
|------|------|
| [terraform_data.kubeconfig](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [vault_kv_secret_v2.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kv_secret_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_imports"></a> [imports](#input\_imports) | Set to `{}` to take over the existing namespace `service_account_namespace` and the replicator and metering ServiceAccounts, ClusterRoles and ClusterRoleBindings of their fixed names, for example those of an earlier meshPlatform registration. Null creates them. | `object({})` | `null` | no |
| <a name="input_metering_additional_rules"></a> [metering\_additional\_rules](#input\_metering\_additional\_rules) | Extra RBAC rules added to the metering cluster role. | <pre>list(object({<br/>    api_groups        = list(string)<br/>    resources         = list(string)<br/>    verbs             = list(string)<br/>    resource_names    = optional(list(string))<br/>    non_resource_urls = optional(list(string))<br/>  }))</pre> | n/a | yes |
| <a name="input_metering_enabled"></a> [metering\_enabled](#input\_metering\_enabled) | Create the metering service account; `metering_token` is empty without it. | `bool` | n/a | yes |
| <a name="input_output_to_vault"></a> [output\_to\_vault](#input\_output\_to\_vault) | Vault KV v2 login this building block writes its secret with: the server `address`, the engine `mount`, a userpass `username` and `password`, and an optional `path_prefix`. The secret is `<path_prefix>kubernetes/platform`, with the keys `replicator-token` and, when metering is enabled, `metering-token`. Null returns them as outputs. | <pre>object({<br/>    address     = string<br/>    mount       = string<br/>    username    = string<br/>    password    = string<br/>    path_prefix = optional(string, "")<br/>  })</pre> | `null` | no |
| <a name="input_release_on_destroy"></a> [release\_on\_destroy](#input\_release\_on\_destroy) | Leave the namespace and the objects in it in place when this building block is destroyed. Cannot change once they are managed. | `bool` | `false` | no |
| <a name="input_replicator_additional_rules"></a> [replicator\_additional\_rules](#input\_replicator\_additional\_rules) | Extra RBAC rules added to the replicator cluster role. | <pre>list(object({<br/>    api_groups        = list(string)<br/>    resources         = list(string)<br/>    verbs             = list(string)<br/>    resource_names    = optional(list(string))<br/>    non_resource_urls = optional(list(string))<br/>  }))</pre> | n/a | yes |
| <a name="input_service_account_namespace"></a> [service\_account\_namespace](#input\_service\_account\_namespace) | Namespace that holds the replicator and metering service accounts. | `string` | n/a | yes |
| <a name="input_token_generation"></a> [token\_generation](#input\_token\_generation) | Month `YYYY-MM` of the replicator and metering tokens. The tokens of the month before stay valid, older ones are deleted. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_metering_service_account_name"></a> [metering\_service\_account\_name](#output\_metering\_service\_account\_name) | Name of the metering ServiceAccount and its companion resources. Null when metering\_enabled is false. |
| <a name="output_metering_token"></a> [metering\_token](#output\_metering\_token) | Service account token meshStack uses to read metering data from the cluster. Empty when metering\_enabled is false or `output_to_vault` is set. |
| <a name="output_replicator_service_account_name"></a> [replicator\_service\_account\_name](#output\_replicator\_service\_account\_name) | Name of the replicator ServiceAccount, its ClusterRole and its ClusterRoleBinding, and prefix of its token Secrets. |
| <a name="output_replicator_token"></a> [replicator\_token](#output\_replicator\_token) | Service account token meshStack uses to replicate namespaces onto the cluster. Empty when `output_to_vault` is set. |
| <a name="output_service_account_namespace"></a> [service\_account\_namespace](#output\_service\_account\_namespace) | Namespace holding the replicator and metering service accounts. |
| <a name="output_vault_secret"></a> [vault\_secret](#output\_vault\_secret) | `{path, secret_hash}` of the secret written to `output_to_vault`, or `{}` when that is not set. `secret_hash` is the secret's KV version and changes with its content. |
<!-- END_TF_DOCS -->
