---
name: STACKIT Kubernetes Workload Identity
supportedPlatforms:
  - kubernetes
description: Lets a Kubernetes service account in a namespace act as a STACKIT service account through workload identity federation, so the workload needs no STACKIT key.
---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [stackit_service_account_federated_identity_provider.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_audience"></a> [audience](#input\_audience) | Audience the workload requests for its service account token. | `string` | n/a | yes |
| <a name="input_kubernetes_oidc_issuer"></a> [kubernetes\_oidc\_issuer](#input\_kubernetes\_oidc\_issuer) | OIDC issuer of the cluster's service account tokens, which STACKIT must be able to reach. | `string` | n/a | yes |
| <a name="input_kubernetes_service_account_name"></a> [kubernetes\_service\_account\_name](#input\_kubernetes\_service\_account\_name) | Kubernetes service account in `namespace` whose tokens may act as the STACKIT service account. It need not exist yet. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace of the tenant. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project of the workload service account. | `string` | n/a | yes |
| <a name="input_workload_service_account_email"></a> [workload\_service\_account\_email](#input\_workload\_service\_account\_email) | STACKIT service account the Kubernetes workload acts as. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_service_account_email"></a> [service\_account\_email](#output\_service\_account\_email) | STACKIT service account the Kubernetes workload acts as, e.g. for `STACKIT_SERVICE_ACCOUNT_EMAIL`. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
