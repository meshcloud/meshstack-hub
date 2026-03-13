# Backplane module for stackit connector Building Block

This backplane does not create any new resources. It simply transforms input variables
into a `config_tf` output that can be dropped into meshStack's BuildingBlockDefinition
as an encrypted file input to configure the access to the kubernetes cluster.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_client_certificate"></a> [client\_certificate](#input\_client\_certificate) | Base64-encoded client certificate used for authenticating to the Kubernetes API server. | `string` | n/a | yes |
| <a name="input_client_key"></a> [client\_key](#input\_client\_key) | Base64-encoded private key corresponding to the client certificate, used for authentication with the Kubernetes API server. | `string` | n/a | yes |
| <a name="input_cluster_ca_certificate"></a> [cluster\_ca\_certificate](#input\_cluster\_ca\_certificate) | Base64-encoded certificate authority (CA) certificate used to verify the Kubernetes API server's identity. | `string` | n/a | yes |
| <a name="input_cluster_host"></a> [cluster\_host](#input\_cluster\_host) | The endpoint of the Kubernetes cluster. | `string` | n/a | yes |
| <a name="input_cluster_kubeconfig"></a> [cluster\_kubeconfig](#input\_cluster\_kubeconfig) | Raw kubeconfig content containing the configuration required to access and authenticate to the Kubernetes cluster. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_config_tf"></a> [config\_tf](#output\_config\_tf) | Generates a config.tf that can be dropped into meshStack's BuildingBlockDefinition as an encrypted file input to configure this building block. |
<!-- END_TF_DOCS -->