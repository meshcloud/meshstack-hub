---
name: Kubernetes Service Account
supportedPlatforms:
  - kubernetes
description: Creates a Kubernetes service account with ClusterRole binding and generates a kubeconfig for authentication
# The cluster kubeconfig is the only thing this needs, and it arrives as an input — there is
# nothing to set up cloud-side beforehand.
requiresBackplane: false
---

# Kubernetes Service Account Building Block

Creates and manages a Kubernetes service account with role binding to a specified ClusterRole, and generates a kubeconfig file for authentication.

This documentation is intended as a reference for cloud foundation or platform engineers using this module.

## Prerequisites

- Access to a Kubernetes cluster
- A kubeconfig for an identity allowed to create service accounts, secrets and role bindings,
  registered on the building block definition as the static FILE input `kubeconfig.yaml`

## Features

- Creates a Kubernetes service account in a specified namespace
- Creates a secret with service account token
- Binds the service account to a specified ClusterRole (admin, edit, view, or custom), in its
  namespace or, with `bind_cluster_wide`, in every namespace
- Generates a ready-to-use kubeconfig file as output, or writes it to a Vault KV v2 secret under the
  key `kubeconfig` when `output_to_vault` is set

> ⚠️ **Security Notice**: The `kubeconfig` output contains a service account token that grants access to the Kubernetes cluster. When displayed as plain text in meshStack, this sensitive credential will be visible to users who can view the building block outputs. Ensure that only authorized users have access to view these outputs, and advise users to store the kubeconfig securely after retrieval.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38, < 3.0.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 5.12.0, < 6.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role_binding.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_role_binding.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [vault_kv_secret_v2.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kv_secret_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bind_cluster_wide"></a> [bind\_cluster\_wide](#input\_bind\_cluster\_wide) | Grant `cluster_role` in every namespace through a ClusterRoleBinding, instead of in `namespace` only through a RoleBinding. | `bool` | `false` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the k8s cluster hosting this service account | `string` | n/a | yes |
| <a name="input_cluster_role"></a> [cluster\_role](#input\_cluster\_role) | ClusterRole to bind the service account with. e.g. admin, edit, view (or any custom cluster role) | `string` | n/a | yes |
| <a name="input_context"></a> [context](#input\_context) | Defines which cluster to interact with. Can be any name | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Service account name | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace where the service account will be created. Recommended: Use platform tenant ID as input in meshStack | `string` | n/a | yes |
| <a name="input_output_to_vault"></a> [output\_to\_vault](#input\_output\_to\_vault) | Vault KV v2 secret this building block writes its secrets to instead of returning them as outputs: the server `address`, the engine `mount`, a userpass `username` and `password`, and the secret `path`. Null returns them as outputs. | <pre>object({<br/>    address  = string<br/>    mount    = string<br/>    username = string<br/>    password = string<br/>    path     = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instructions"></a> [instructions](#output\_instructions) | Instructions for using the kubeconfig |
| <a name="output_kubeconfig"></a> [kubeconfig](#output\_kubeconfig) | Kubeconfig file content for authenticating with the Kubernetes cluster. Empty when `output_to_vault` is set. |
| <a name="output_vault_secret"></a> [vault\_secret](#output\_vault\_secret) | `{path, secret_hash}` of the secret written to `output_to_vault`, or `{}` when that is not set. `secret_hash` is the secret's KV version and changes with its content. |
<!-- END_TF_DOCS -->
