---
name: STACKIT Metering
supportedPlatforms:
  - kubernetes
description: Runs the STACKIT custom metering of meshcloud/mesh-custom-metering as a CronJob in a Kubernetes namespace, which reads STACKIT costs through workload identity federation and submits them as usage reports to meshStack.
---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0, < 3.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [kubernetes_cron_job_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job_v1) | resource |
| [kubernetes_secret_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |
| [stackit_service_account_federated_identity_provider.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/service_account_federated_identity_provider) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_credentials_revision"></a> [credentials\_revision](#input\_credentials\_revision) | Increase to write a changed API user password to the Kubernetes secret. | `number` | n/a | yes |
| <a name="input_image_tag"></a> [image\_tag](#input\_image\_tag) | Tag of the `ghcr.io/meshcloud/mesh-custom-metering/mesh-metering-stackit` image. | `string` | n/a | yes |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Kubeconfig (YAML) of a service account that may manage service accounts, Secrets and CronJobs in `namespace`. | `string` | n/a | yes |
| <a name="input_kubernetes_oidc_issuer"></a> [kubernetes\_oidc\_issuer](#input\_kubernetes\_oidc\_issuer) | OIDC issuer of the cluster's service account tokens, which STACKIT must be able to reach. | `string` | n/a | yes |
| <a name="input_meshstack_api_secret"></a> [meshstack\_api\_secret](#input\_meshstack\_api\_secret) | Password of the meshStack API user. | `string` | n/a | yes |
| <a name="input_meshstack_api_user"></a> [meshstack\_api\_user](#input\_meshstack\_api\_user) | Username of the meshStack API user that reads meshTenants and writes usage reports. The metering API accepts only API users, no API keys. | `string` | n/a | yes |
| <a name="input_meshstack_kraken_url"></a> [meshstack\_kraken\_url](#input\_meshstack\_kraken\_url) | Kraken API endpoint of the same meshStack. | `string` | n/a | yes |
| <a name="input_meshstack_meshfed_url"></a> [meshstack\_meshfed\_url](#input\_meshstack\_meshfed\_url) | meshfed API endpoint of the meshStack that receives the usage reports. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace of the tenant the CronJob runs in. | `string` | n/a | yes |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | Full identifier `<platform>.<location>` of the STACKIT meshPlatform whose tenants receive the usage reports, e.g. `stackit.global`. | `string` | n/a | yes |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Cron schedule of the metering job. Each run re-submits the full current month. | `string` | n/a | yes |
| <a name="input_stackit_metering_service_account_email"></a> [stackit\_metering\_service\_account\_email](#input\_stackit\_metering\_service\_account\_email) | STACKIT service account with read access to the organization's costs, which the CronJob acts as. | `string` | n/a | yes |
| <a name="input_stackit_organization_id"></a> [stackit\_organization\_id](#input\_stackit\_organization\_id) | STACKIT organization whose project costs are collected. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project of the metering service account. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_cron_job_name"></a> [cron\_job\_name](#output\_cron\_job\_name) | Name of the metering CronJob in the tenant namespace. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
