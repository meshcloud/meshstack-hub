---
name: Building Block Run Controller
supportedPlatforms:
  - kubernetes
description: Deploys a meshStack building block runner into a Kubernetes namespace and registers it in meshStack.
---

# Building Block Run Controller

This building block deploys the run-controller of the
[building block runner](https://github.com/meshcloud/building-block-runner) into the tenant's
namespace and registers it in meshStack as a runner of type `ALL`, PRIVATE to the tenant's
workspace. The run-controller polls meshStack and starts every run as a Kubernetes Job in the same
namespace.

The building block runs on the shared runner meshStack hosts. Its run registers the runner with an
ephemeral key of the tenant's workspace. The runner polls meshStack with an API key the person
ordering creates beforehand in the tenant's workspace, with the rights the meshStack Panel grants a
private runner: `MANAGED_BUILDINGBLOCKRUN_SAVE` and `MANAGED_BUILDINGBLOCKRUNSOURCE_SAVE`. A run's
ephemeral key cannot hold `MANAGED_*` rights, so it cannot create that key.

The runner has no workload identity federation.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.25.0 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0.0, < 5.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_deployment_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/deployment_v1) | resource |
| [kubernetes_role_binding_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_binding_v1) | resource |
| [kubernetes_role_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/role_v1) | resource |
| [kubernetes_secret_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [meshstack_building_block_runner.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_runner) | resource |
| [tls_private_key.this](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [meshstack_instance.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/instance) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_image"></a> [image](#input\_image) | Image of the run-controller. | `string` | n/a | yes |
| <a name="input_job_image"></a> [job\_image](#input\_job\_image) | Image of the Jobs that execute the runs. Without a tag, the run-controller appends its own version. | `string` | n/a | yes |
| <a name="input_kubernetes_api"></a> [kubernetes\_api](#input\_kubernetes\_api) | Kubernetes API server connection data. | <pre>object({<br/>    server                 = string<br/>    cluster_ca_certificate = string<br/>    token                  = string<br/>  })</pre> | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace of the tenant the run-controller runs in and starts its Jobs in. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | meshStack project of the tenant. The runner is named after it. | `string` | n/a | yes |
| <a name="input_runner_api_key_client_id"></a> [runner\_api\_key\_client\_id](#input\_runner\_api\_key\_client\_id) | Client id of the API key the runner polls meshStack with. | `string` | n/a | yes |
| <a name="input_runner_api_key_client_secret"></a> [runner\_api\_key\_client\_secret](#input\_runner\_api\_key\_client\_secret) | Client secret of the runner's API key. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | meshStack workspace that owns the runner. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_runner_ref"></a> [runner\_ref](#output\_runner\_ref) | Reference to the registered building block runner, for `version_spec.runner_ref` of a building block definition. |
<!-- END_TF_DOCS -->
