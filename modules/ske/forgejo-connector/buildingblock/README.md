---
name: Forgejo Actions Integration with STACKIT Kubernetes
supportedPlatforms:
  - kubernetes
description: |
  CI/CD pipeline using Forgejo Actions for secure, scalable Kubernetes deployment.
---

# Forgejo Actions Integration with STACKIT Kubernetes

This Terraform module provisions the necessary resources to integrate Forgejo Actions with a STACKIT Kubernetes cluster.
It sets up a service account and repository action secrets for seamless CI/CD.

## Why `restapi` is used for Action secrets

`forgejo_repository_action_secret` currently lacks delete support in the Forgejo provider, which can leave stale secrets in Forgejo after Terraform destroy.
This module therefore uses `restapi_object` for Action secrets so destroy performs an actual `DELETE` request against the Forgejo API.

## Features

- Secure authentication using a Kubernetes service account and Forgejo action secrets
- STACKIT Container Registry integration for image building and pushing
- Stage-scoped user permission output derived from meshStack project members

## Stage user permissions output

This module derives and outputs stage-scoped Forgejo user permissions from the `users` input (meshStack User Permissions input).

- Input schema follows the standard authoritative user object (`username`, `email`, `roles`, ...).
- Role mapping is:
  - `reader -> read`
  - `user -> write`
  - `admin -> admin`
- If a user has multiple roles, highest privilege wins: `admin > user > reader`.

## Providers

```hcl
terraform {
  required_providers {
    forgejo = {
      source  = "svalabs/forgejo"
      version = "1.3.1"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}
```

To setup the Forgejo provider make sure to set these environment variables for this Building Block:
`FORGEJO_HOST`, `FORGEJO_API_TOKEN`.

The Kubernetes provider should be set up with a static file input `config.tf` with the contents of
the backplane module's `config_tf` output.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_external"></a> [external](#requirement\_external) | ~> 2.3.0 |
| <a name="requirement_forgejo"></a> [forgejo](#requirement\_forgejo) | ~> 1.3.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.8.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [kubernetes_cluster_role.clusterissuer_reader](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/cluster_role) | resource |
| [kubernetes_cluster_role_binding.forgejo_actions_clusterissuer_access](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/cluster_role_binding) | resource |
| [kubernetes_default_service_account.namespace_default](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/default_service_account) | resource |
| [kubernetes_role_binding.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/role_binding) | resource |
| [kubernetes_secret.additional](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_secret.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_secret.image_pull](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_service_account.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/service_account) | resource |
| [random_string.resource_name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [restapi_object.action_secret](https://registry.terraform.io/providers/Mastercard/restapi/3.0.0/docs/resources/object) | resource |
| [restapi_object.action_variable](https://registry.terraform.io/providers/Mastercard/restapi/3.0.0/docs/resources/object) | resource |
| [terraform_data.await_pipeline_workflow](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [external_external.repository_context](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_kubernetes_secrets"></a> [additional\_kubernetes\_secrets](#input\_additional\_kubernetes\_secrets) | Additional Kubernetes secrets to create in the tenant namespace. Map keys are secret names, values are secret data maps. | `map(map(string))` | `{}` | no |
| <a name="input_app_hostname"></a> [app\_hostname](#input\_app\_hostname) | Public application hostname for this stage (used by deploy workflow and ingress). | `string` | n/a | yes |
| <a name="input_harbor_host"></a> [harbor\_host](#input\_harbor\_host) | The URL of the Harbor registry. | `string` | `"https://registry.onstackit.cloud"` | no |
| <a name="input_harbor_password"></a> [harbor\_password](#input\_harbor\_password) | The password for the Harbor registry. | `string` | n/a | yes |
| <a name="input_harbor_username"></a> [harbor\_username](#input\_harbor\_username) | The username for the Harbor registry. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Associated namespace in kubernetes cluster. | `string` | n/a | yes |
| <a name="input_repository_id"></a> [repository\_id](#input\_repository\_id) | The ID of the Forgejo repository. | `number` | n/a | yes |
| <a name="input_stage"></a> [stage](#input\_stage) | Deployment stage used for Forgejo workflow dispatch and action secret naming. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | List of users from authoritative system to derive stage user permissions. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_app_link"></a> [app\_link](#output\_app\_link) | Public URL for this stage application. |
| <a name="output_user_permissions"></a> [user\_permissions](#output\_user\_permissions) | Stage-scoped Forgejo user permissions derived from meshStack project members. |
<!-- END_TF_DOCS -->
