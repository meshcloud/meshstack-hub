---
name: Forgejo Actions Integration with STACKIT Kubernetes
supportedPlatforms:
  - kubernetes
description: |
  CI/CD pipeline using Forgejo Actions for secure, scalable Kubernetes deployment.
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
- **Additional secrets** – optional map of arbitrary Opaque secrets injected
  into the namespace (e.g. AI service keys).

## Why `restapi` is used for Action secrets & variables

Action secrets and variables are managed by the shared
[`action-variables-and-secrets`](https://github.com/meshcloud/meshstack-hub/tree/feature/ske-starter-kit-harbor-integration/modules/stackit/git-repository/buildingblock/action-variables-and-secrets)
sub-module (sourced from `git-repository`) using the generic `restapi` provider.
The Forgejo Terraform provider currently cannot delete secrets (only removes
them from state) and does not support action variables at all.

## Provider configuration

The module expects the following environment variables for the Forgejo provider
and the restapi providers:

| Variable            | Description |
|---------------------|-------------|
| `FORGEJO_HOST`      | Base URL of the Forgejo instance. |
| `FORGEJO_API_TOKEN`  | API token for authenticating with Forgejo. |

The Kubernetes provider is configured from a `kubeconfig.yaml` static file
input containing admin credentials to the SKE cluster.

<!-- terraform-docs is disabled for this directory (see .pre-commit-config.yaml), so the block below is maintained by hand. -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.0, < 3.0.0 |
| <a name="requirement_forgejo"></a> [forgejo](#requirement\_forgejo) | >= 1.4.0, < 2.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.35.1, < 3.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.8.0, < 4.0.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [forgejo_repository_action_secret.this](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [forgejo_repository_action_variable.this](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_variable) | resource |
| [kubernetes_cluster_role.clusterissuer_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.forgejo_actions_clusterissuer_access](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding) | resource |
| [kubernetes_default_service_account.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/default_service_account) | resource |
| [kubernetes_role_binding.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.additional](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.image_pull](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [random_string.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [restapi_object.legacy_action_secret](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.legacy_action_variable](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [terraform_data.await_pipeline_workflow](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [external_external.env](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_kubernetes_secrets"></a> [additional\_kubernetes\_secrets](#input\_additional\_kubernetes\_secrets) | Additional Kubernetes secrets to create in the tenant namespace. Map keys are secret names, values are secret data maps. | `map(map(string))` | n/a | yes |
| <a name="input_app_hostname"></a> [app\_hostname](#input\_app\_hostname) | Public application hostname for this stage (used by deploy workflow and ingress). | `string` | n/a | yes |
| <a name="input_container_registry_access_credentials"></a> [container\_registry\_access\_credentials](#input\_container\_registry\_access\_credentials) | Registry robot credentials. Null wires no registry, so pods pull public images only. | <pre>object({<br/>    push = object({ user = string, password = string })<br/>    pull = object({ user = string, password = string })<br/>  })</pre> | `null` | no |
| <a name="input_harbor_host"></a> [harbor\_host](#input\_harbor\_host) | The URL of the Harbor registry. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Associated namespace in kubernetes cluster. | `string` | n/a | yes |
| <a name="input_repository_id"></a> [repository\_id](#input\_repository\_id) | The ID of the Forgejo repository. | `number` | n/a | yes |
| <a name="input_stage"></a> [stage](#input\_stage) | Deployment stage used for Forgejo workflow dispatch and action secret naming. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_link"></a> [app\_link](#output\_app\_link) | Public URL for this stage application. |
<!-- END_TF_DOCS -->
