## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.35.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role.clusterissuer_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/cluster_role) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_client_certificate"></a> [client\_certificate](#input\_client\_certificate) | n/a | `string` | n/a | yes |
| <a name="input_client_key"></a> [client\_key](#input\_client\_key) | n/a | `string` | n/a | yes |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | n/a | `string` | n/a | yes |
| <a name="input_cluster_host"></a> [cluster\_host](#input\_cluster\_host) | The endpoint of the Kubernetes cluster. | `string` | n/a | yes |
| <a name="input_cluster_kubeconfig"></a> [cluster\_kubeconfig](#input\_cluster\_kubeconfig) | n/a | `string` | n/a | yes |
| <a name="input_forgejo_api_token"></a> [forgejo\_api\_token](#input\_forgejo\_api\_token) | The API token for accessing the Forgejo instance. | `string` | n/a | yes |
| <a name="input_forgejo_host"></a> [forgejo\_host](#input\_forgejo\_host) | The URL of the Forgejo instance. | `string` | n/a | yes |
| <a name="input_forgejo_repository_name"></a> [forgejo\_repository\_name](#input\_forgejo\_repository\_name) | The name of the Forgejo repository where the action secrets will be created. | `string` | n/a | yes |
| <a name="input_forgejo_repository_owner"></a> [forgejo\_repository\_owner](#input\_forgejo\_repository\_owner) | The owner of the Forgejo repository where the action secrets will be created. | `string` | n/a | yes |
| <a name="input_harbor_host"></a> [harbor\_host](#input\_harbor\_host) | n/a | `string` | `"https://registry.onstackit.cloud"` | no |
| <a name="input_harbor_password"></a> [harbor\_password](#input\_harbor\_password) | n/a | `string` | n/a | yes |
| <a name="input_harbor_username"></a> [harbor\_username](#input\_harbor\_username) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_tf"></a> [config\_tf](#output\_config\_tf) | Generates a config.tf that can be dropped into meshStack's BuildingBlockDefinition as an encrypted file input to configure this building block. |
