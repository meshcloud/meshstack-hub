## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_forgejo"></a> [forgejo](#provider\_forgejo) | n/a |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.35.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [forgejo_repository_action_secret.additional](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [forgejo_repository_action_secret.container_registry](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [forgejo_repository_action_secret.kubeconfig](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [kubernetes_cluster_role_binding.forgejo_actions_clusterissuer_access](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/cluster_role_binding) | resource |
| [kubernetes_role_binding.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/role_binding) | resource |
| [kubernetes_secret.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_secret.image_pull](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_service_account.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/service_account) | resource |
| [forgejo_repository.this](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/data-sources/repository) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_environment_variables"></a> [additional\_environment\_variables](#input\_additional\_environment\_variables) | Map of additional environment variable key/value pairs to set as Forgejo repository action secrets. | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Associated namespace in kubernetes cluster. | `string` | n/a | yes |

## Outputs

No outputs.
