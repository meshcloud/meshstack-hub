---
name: GitHub Actions Connector for Kubernetes
supportedPlatforms:
  - kubernetes
description: Connects a GitHub repository to a Kubernetes namespace, so GitHub Actions deploys into the namespace.
---

# GitHub Actions Connector for Kubernetes

This building block wires one GitHub repository environment to one Kubernetes namespace. It creates
a `github-actions-<repo>-<hash>` service account in the namespace, binds it to `edit` there, and
hands its credentials to a GitHub environment. A namespace can hold several connectors, one per
repository and environment; a starter kit orders one per stage.

## Contract with the repository's workflow

The GitHub environment receives:

| Name | Kind | Content |
|---|---|---|
| `KUBECONFIG` | secret | kubeconfig of the service account, context set to the namespace |
| `K8S_NAMESPACE` | variable | the namespace name |

The connector does not provide an image registry. Deployments reference images the cluster can
already pull.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | >= 6.5.0, < 7.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_actions_environment_secret.kubeconfig](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_secret) | resource |
| [github_actions_environment_variable.k8s_namespace](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_variable) | resource |
| [github_repository_environment.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment) | resource |
| [kubernetes_role_binding_v1.github_actions_edit](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_secret_v1.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_github_environment_name"></a> [github\_environment\_name](#input\_github\_environment\_name) | GitHub environment that receives the deployment credentials of this namespace. | `string` | n/a | yes |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | Name of the GitHub repository to connect, within the organization the GitHub App is installed in. | `string` | n/a | yes |
| <a name="input_kubernetes_api"></a> [kubernetes\_api](#input\_kubernetes\_api) | API server URL, PEM CA bundle and token of the connector backplane's service account. | <pre>object({<br/>    server                 = string<br/>    cluster_ca_certificate = string<br/>    token                  = string<br/>  })</pre> | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace of the tenant the connector deploys into. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_environment_name"></a> [github\_environment\_name](#output\_github\_environment\_name) | GitHub environment that holds the deployment credentials of this namespace. |
<!-- END_TF_DOCS -->
