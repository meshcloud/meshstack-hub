---
name: Kubernetes CronJob
supportedPlatforms:
  - kubernetes
description: Runs a container image on a cron schedule in a Kubernetes namespace, with plain and secret environment variables and an optional service account token for workload identity federation.
---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.38.0, < 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cron_job_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/cron_job_v1) | resource |
| [kubernetes_secret_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret_v1) | resource |
| [kubernetes_service_account_v1.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env"></a> [env](#input\_env) | Environment variables of the container. | `map(string)` | n/a | yes |
| <a name="input_image"></a> [image](#input\_image) | Container image the job runs, e.g. `ghcr.io/example/report:1.2.3`. It is pulled on every run. | `string` | n/a | yes |
| <a name="input_kubeconfig"></a> [kubeconfig](#input\_kubeconfig) | Kubeconfig (YAML) of a service account that may manage service accounts, Secrets and CronJobs in `namespace`. | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the CronJob and of the Kubernetes service account its pods run as. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Kubernetes namespace of the tenant the CronJob runs in. | `string` | n/a | yes |
| <a name="input_resources"></a> [resources](#input\_resources) | CPU and memory requests and limits of the container. | <pre>object({<br/>    cpu_request    = string<br/>    memory_request = string<br/>    cpu_limit      = string<br/>    memory_limit   = string<br/>  })</pre> | n/a | yes |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Cron schedule of the job, e.g. `0 * * * *`. | `string` | n/a | yes |
| <a name="input_secret_env"></a> [secret\_env](#input\_secret\_env) | Environment variables of the container that are kept in a Kubernetes secret. | `map(string)` | `null` | no |
| <a name="input_secret_env_revision"></a> [secret\_env\_revision](#input\_secret\_env\_revision) | Increase to write a changed `secret_env` to the Kubernetes secret. | `number` | n/a | yes |
| <a name="input_service_account_token"></a> [service\_account\_token](#input\_service\_account\_token) | Mounts a token of the job's Kubernetes service account with this audience at `<mount_path>/token`, for workload identity federation with a cloud. | <pre>object({<br/>    audience   = string<br/>    mount_path = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cron_job_name"></a> [cron\_job\_name](#output\_cron\_job\_name) | Name of the CronJob in the tenant namespace. |
| <a name="output_service_account_subject"></a> [service\_account\_subject](#output\_service\_account\_subject) | Subject of the tokens of the job's Kubernetes service account, which a cloud's workload identity federation trusts. |
| <a name="output_summary"></a> [summary](#output\_summary) | Markdown summary shown in meshPanel after the run. |
<!-- END_TF_DOCS -->
