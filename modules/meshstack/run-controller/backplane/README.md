# Building Block Run Controller — Backplane

Sets up what the run-controller building block needs on one Kubernetes cluster.

## What it provisions

- A namespace (`meshstack-run-controller` by default) holding a service account and its long-lived
  token secret.
- A cluster role and binding that let the service account manage the run-controller's service
  account, Role, RoleBinding, Secret and Deployment, and that hold every verb the run-controller's
  Role grants on Jobs, Secrets and service accounts, because RBAC only lets it grant what it holds.
- A `ValidatingAdmissionPolicy` and binding that reject every create, update or delete by the
  service account outside namespaces labeled `io.meshcloud/meshstack.managed-entity=true`, the
  label meshStack puts on the namespaces it manages.
- An API key of the integration's workspace with `MANAGED_BUILDINGBLOCKRUN_SAVE` and
  `MANAGED_BUILDINGBLOCKRUNSOURCE_SAVE`, which every runner the building block deploys polls
  meshStack with. A building block run cannot create it, because a definition may not declare
  `MANAGED_*` permissions. With `runner_api_key_validity_days` set, an apply after two thirds of
  that time replaces the key's secret, so apply the integration at least that often.

## Security model

RBAC cannot select namespaces by label, so the cluster role applies everywhere. The admission policy
limits writes to managed namespaces. Reads cannot be limited by admission. The cluster role grants
`get` on everything it manages, and `list` and `watch` on Jobs only, because the run-controller's
Role needs them. The building block run can therefore list the Jobs of every namespace.

The `kubernetes_api` output carries the API server URL, the CA bundle and the token. The
integration module passes it and `runner_api_key` to the building block definition as sensitive
static inputs. Replacing the API key reaches each runner with its building block's next run.

## Requirements

- Kubernetes 1.30 or later, for `ValidatingAdmissionPolicy`.
- The calling configuration configures the `kubernetes` provider for the cluster with a
  `cluster-admin` identity. The policy binding is a `kubernetes_manifest`, so the cluster must be
  reachable at plan time.
- The API server is reachable from the meshStack building block runner.
- The run-controller reaches the meshStack API from the cluster.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.27.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.12, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role_binding_v1.backplane](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1) | resource |
| [kubernetes_cluster_role_v1.backplane](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1) | resource |
| [kubernetes_manifest.managed_namespaces_only_binding](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/manifest) | resource |
| [kubernetes_namespace_v1.backplane](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret_v1.backplane_token](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.backplane](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [kubernetes_validating_admission_policy_v1.managed_namespaces_only](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/validating_admission_policy_v1) | resource |
| [meshstack_api_key.runner](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/api_key) | resource |
| [time_rotating.runner_api_key](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_server_ca_certificate"></a> [api\_server\_ca\_certificate](#input\_api\_server\_ca\_certificate) | PEM CA bundle that verifies the API server. Defaults to the cluster CA. Set it when the API server presents a certificate signed by another CA. | `string` | `null` | no |
| <a name="input_api_server_url"></a> [api\_server\_url](#input\_api\_server\_url) | URL of the Kubernetes API server that building block runs connect to (example: `https://api.k8s.example.com:6443`). | `string` | n/a | yes |
| <a name="input_managed_namespace_label"></a> [managed\_namespace\_label](#input\_managed\_namespace\_label) | Label the meshStack replicator sets to `true` on managed namespaces. The building block may only change objects in namespaces carrying it. | `string` | `"io.meshcloud/meshstack.managed-entity"` | no |
| <a name="input_meshstack_workspace_identifier"></a> [meshstack\_workspace\_identifier](#input\_meshstack\_workspace\_identifier) | meshStack workspace that owns the runners' API key. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the backplane's namespace, service account, cluster role and admission policy. | `string` | `"meshstack-run-controller"` | no |
| <a name="input_runner_api_key_validity_days"></a> [runner\_api\_key\_validity\_days](#input\_runner\_api\_key\_validity\_days) | Days the runners' API key is valid and rotated within, up to the limit of the meshStack instance. `null` means the key never expires. | `number` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kubernetes_api"></a> [kubernetes\_api](#output\_kubernetes\_api) | Kubernetes API connection data. |
| <a name="output_runner_api_key"></a> [runner\_api\_key](#output\_runner\_api\_key) | API key the runners poll meshStack with. |
| <a name="output_runner_api_key_version"></a> [runner\_api\_key\_version](#output\_runner\_api\_key\_version) | Hash of the runners' API key. It changes when the key is replaced. |
<!-- END_TF_DOCS -->
