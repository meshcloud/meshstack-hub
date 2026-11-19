---
name: Kubernetes Manifest (Helm)
supportedPlatforms:
  - kubernetes
description: Deploys arbitrary Kubernetes manifests into a tenant namespace via a local Helm chart, with operator-supplied templates and user-provided values.
---

## Values

Helm merges `values_yaml` and then `secret_values_yaml`, so a key in the secret values overrides the
same key in the plain ones. Put passwords, tokens and other secrets into `secret_values_yaml`: the
definition declares it as a sensitive input, which meshStack stores encrypted and masks in meshPanel.
The values still reach the state and the plan of the run, like every value Helm gets.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.17.0, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.this](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace to deploy the Helm release into. | `string` | n/a | yes |
| <a name="input_release_name"></a> [release\_name](#input\_release\_name) | Name of the Helm release. | `string` | n/a | yes |
| <a name="input_secret_values_yaml"></a> [secret\_values\_yaml](#input\_secret\_values\_yaml) | Helm values that hold secrets, merged after `values_yaml` so they override it. | `string` | `"{}"` | no |
| <a name="input_values_yaml"></a> [values\_yaml](#input\_values\_yaml) | Helm values as a JSON-encoded string (YAML is also accepted by Helm). | `string` | `"{}"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_release_name"></a> [release\_name](#output\_release\_name) | Name of the deployed Helm release. |
| <a name="output_release_status"></a> [release\_status](#output\_release\_status) | Status of the Helm release. |
<!-- END_TF_DOCS -->
