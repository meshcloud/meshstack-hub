---
name: GitHub Actions Connector for OpenShift
supportedPlatforms:
  - openshift
description: Connects a GitHub repository to an OpenShift project, so GitHub Actions builds images into the internal registry and deploys them into the project.
---

# GitHub Actions Connector for OpenShift

This building block wires one GitHub repository environment to one OpenShift project (namespace).
It creates a `github-actions` service account in the project, binds it to `edit` and
`system:image-builder`, and hands its credentials to a GitHub environment. A starter kit orders one
connector per stage, each with its own environment.

## Contract with the repository's workflow

The GitHub environment receives:

| Name | Kind | Content |
|---|---|---|
| `KUBECONFIG` | secret | kubeconfig of the service account, context set to the project |
| `OPENSHIFT_REGISTRY_TOKEN` | secret | service account token, the password for `docker login` to the internal registry |
| `OPENSHIFT_NAMESPACE` | variable | the project name |
| `OPENSHIFT_REGISTRY` | variable | host of the internal registry route |
| any `additional_environment_variables` | variable | set by the caller, e.g. the app hostname |

A workflow pushes to `${OPENSHIFT_REGISTRY}/${OPENSHIFT_NAMESPACE}/<image>` and references the
image in its deployment as `image-registry.openshift-image-registry.svc:5000/<namespace>/<image>`.
Containers must run under an arbitrary non-root UID, as the `restricted-v2` security context
constraint requires.

When `workflow_filename` is set, the connector dispatches that workflow on `deploy_branch` once the
credentials are in place, so the first deployment does not wait for a push.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | >= 6.5.0, < 7.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.35.1, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_actions_environment_secret.kubeconfig](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_secret) | resource |
| [github_actions_environment_secret.registry_token](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_secret) | resource |
| [github_actions_environment_variable.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/actions_environment_variable) | resource |
| [github_repository_environment.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_environment) | resource |
| [kubernetes_role_binding.github_actions_edit](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_role_binding.github_actions_image_builder](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding) | resource |
| [kubernetes_secret.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_service_account.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account) | resource |
| [terraform_data.workflow_dispatch](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_environment_variables"></a> [additional\_environment\_variables](#input\_additional\_environment\_variables) | Additional GitHub Actions variables to set on the environment. | `map(string)` | `{}` | no |
| <a name="input_deploy_branch"></a> [deploy\_branch](#input\_deploy\_branch) | Branch whose workflow deploys into this namespace. The connector dispatches the workflow on it once its credentials are in place. | `string` | `"main"` | no |
| <a name="input_github_environment_name"></a> [github\_environment\_name](#input\_github\_environment\_name) | GitHub environment that receives the deployment credentials of this namespace. | `string` | n/a | yes |
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | Name of the GitHub repository to connect, within the organization the GitHub App is installed in. | `string` | n/a | yes |
| <a name="input_kubernetes_api"></a> [kubernetes\_api](#input\_kubernetes\_api) | API server URL, PEM CA bundle and token of the connector backplane's service account. | <pre>object({<br/>    server                 = string<br/>    cluster_ca_certificate = string<br/>    token                  = string<br/>  })</pre> | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | OpenShift project (namespace) of the tenant the connector deploys into. | `string` | n/a | yes |
| <a name="input_registry_host"></a> [registry\_host](#input\_registry\_host) | Host of the cluster's internal image registry route that GitHub Actions pushes images to (example: `default-route-openshift-image-registry.apps.ocp.example.com`). | `string` | n/a | yes |
| <a name="input_workflow_filename"></a> [workflow\_filename](#input\_workflow\_filename) | Workflow to dispatch on `deploy_branch` after setup (example: `openshift-deploy.yml`). It must declare `on: workflow_dispatch`. Empty skips the dispatch. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_environment_name"></a> [github\_environment\_name](#output\_github\_environment\_name) | GitHub environment that holds the deployment credentials of this namespace. |
<!-- END_TF_DOCS -->
