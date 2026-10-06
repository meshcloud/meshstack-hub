---
name: Forgejo Actions Integration with STACKIT Kubernetes
supportedPlatforms:
  - kubernetes
description: |
  CI/CD pipeline using Forgejo Actions for secure, scalable Kubernetes deployment.
e2eCoveredBy: ske/ske-starterkit
---

# Forgejo Actions Integration with STACKIT Kubernetes

This building block connects a Forgejo repository with a tenant namespace on a
STACKIT Kubernetes Engine (SKE) cluster. It provisions the Kubernetes resources
(service account, RBAC, image-pull secrets) and configures the matching Forgejo
Actions secrets and variables so that a CI/CD pipeline can deploy into the
namespace.

## Features

- **Kubernetes service account & RBAC** – scoped credentials for the Forgejo
  Actions runner, including cluster-issuer read access for cert-manager.
- **Action secrets & variables** – per-stage `KUBECONFIG_<STAGE>`,
  `K8S_NAMESPACE_<STAGE>` and `APP_HOSTNAME_<STAGE>` managed via the shared
  [`action-variables-and-secrets`](https://github.com/meshcloud/meshstack-hub/tree/feature/ske-starter-kit-harbor-integration/modules/stackit/git-repository/buildingblock/action-variables-and-secrets)
  sub-module.
- **Harbor image-pull secret** – `kubernetes.io/dockerconfigjson` secret
  attached to the default service account so pods can pull from STACKIT Harbor.
- **Pipeline trigger** – after provisioning, automatically triggers the Forgejo
  Actions pipeline workflow and waits for it to complete.
- **Additional secrets** – optional Opaque secrets injected into the namespace
  (e.g. AI service keys), each filled from a Vault KV v2 secret.

## Why `restapi` is used for Action secrets & variables

Action secrets and variables are managed by the shared
[`action-variables-and-secrets`](https://github.com/meshcloud/meshstack-hub/tree/feature/ske-starter-kit-harbor-integration/modules/stackit/git-repository/buildingblock/action-variables-and-secrets)
sub-module (sourced from `git-repository`) using the generic `restapi` provider.
The Forgejo Terraform provider currently cannot delete secrets (only removes
them from state) and does not support action variables at all.

## Provider configuration

The Forgejo and restapi providers take the host from the `FORGEJO_HOST`
environment variable. The Forgejo API token, the registry pull robot and the
additional secrets are read from a Vault KV v2 engine, such as a STACKIT Secrets
Manager instance, with the `vault_reader` login. What a run reads is kept in its
Terraform state.

The Kubernetes provider is configured from a `kubeconfig.yaml` static file
input of a cluster-admin service account on the SKE cluster.

<!-- terraform-docs is disabled for this directory (see .pre-commit-config.yaml), so the block below is maintained by hand. -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.0 |
| <a name="requirement_forgejo"></a> [forgejo](#requirement\_forgejo) | >= 1.3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.35.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.8.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | >= 3.0.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 5.12.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_action_secrets_and_variables"></a> [action\_secrets\_and\_variables](#module\_action\_secrets\_and\_variables) | github.com/meshcloud/meshstack-hub//modules/stackit/git-repository/buildingblock/action-variables-and-secrets | `${var.hub_git_ref}` |

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role.clusterissuer_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.forgejo_actions_clusterissuer_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_default_service_account.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/default_service_account) | resource |
| [kubernetes_role_binding.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.additional](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.image_pull](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [terraform_data.await_pipeline_workflow](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [external_external.env](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [vault_kv_secret_v2.additional](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/kv_secret_v2) | data source |
| [vault_kv_secret_v2.forgejo_api_token](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/kv_secret_v2) | data source |
| [vault_kv_secret_v2.registry_pull](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/kv_secret_v2) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_kubernetes_secrets"></a> [additional\_kubernetes\_secrets](#input\_additional\_kubernetes\_secrets) | Opaque Kubernetes secrets to create in the tenant namespace, by name, each from the Vault KV v2 secret at the given path. Every key of that secret becomes a key of the Kubernetes secret. | `map(string)` | n/a | yes |
| <a name="input_app_hostname"></a> [app\_hostname](#input\_app\_hostname) | Public application hostname for this stage (used by deploy workflow and ingress). | `string` | n/a | yes |
| <a name="input_forgejo_api_token_path"></a> [forgejo\_api\_token\_path](#input\_forgejo\_api\_token\_path) | Vault KV v2 secret holding the Forgejo API token under the key `forgejo_api_token`. | `string` | n/a | yes |
| <a name="input_harbor_host"></a> [harbor\_host](#input\_harbor\_host) | The URL of the Harbor registry. | `string` | `"https://registry.onstackit.cloud"` | no |
| <a name="input_hub_git_ref"></a> [hub\_git\_ref](#input\_hub\_git\_ref) | Hub git ref this building block runs from. Pins the shared modules it sources so they stay in lockstep with this module's own checkout. | `string` | `"main"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Associated namespace in kubernetes cluster. | `string` | n/a | yes |
| <a name="input_registry_pull_path"></a> [registry\_pull\_path](#input\_registry\_pull\_path) | Vault KV v2 secret holding the registry pull robot under the keys `username` and `password`. | `string` | n/a | yes |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Name of the Forgejo repository. | `string` | n/a | yes |
| <a name="input_repository_owner"></a> [repository\_owner](#input\_repository\_owner) | Owner of the Forgejo repository. | `string` | n/a | yes |
| <a name="input_stage"></a> [stage](#input\_stage) | Deployment stage used for Forgejo workflow dispatch and action secret naming. | `string` | n/a | yes |
| <a name="input_vault_reader"></a> [vault\_reader](#input\_vault\_reader) | Vault KV v2 login this building block reads its secrets with: the server `address`, the engine `mount` and a userpass `username` and `password`. | <pre>object({<br/>    address  = string<br/>    mount    = string<br/>    username = string<br/>    password = string<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_link"></a> [app\_link](#output\_app\_link) | Public URL for this stage application. |
<!-- END_TF_DOCS -->
