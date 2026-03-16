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

## Features

- Secure authentication using a Kubernetes service account and Forgejo action secrets
- STACKIT Container Registry integration for image building and pushing

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
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [forgejo_repository_action_secret.additional](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [forgejo_repository_action_secret.container_registry](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [forgejo_repository_action_secret.kubeconfig](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [forgejo_repository_action_secret.namespace](https://registry.terraform.io/providers/svalabs/forgejo/latest/docs/resources/repository_action_secret) | resource |
| [kubernetes_cluster_role_binding.forgejo_actions_clusterissuer_access](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/cluster_role_binding) | resource |
| [kubernetes_role_binding.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/role_binding) | resource |
| [kubernetes_secret.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_secret.image_pull](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_service_account.forgejo_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_environment_variables"></a> [additional\_environment\_variables](#input\_additional\_environment\_variables) | Map of additional environment variable key/value pairs to set as Forgejo repository action secrets. | `map(string)` | `{}` | no |
| <a name="input_harbor_host"></a> [harbor\_host](#input\_harbor\_host) | The URL of the Harbor registry. | `string` | `"https://registry.onstackit.cloud"` | no |
| <a name="input_harbor_password"></a> [harbor\_password](#input\_harbor\_password) | The password for the Harbor registry. | `string` | n/a | yes |
| <a name="input_harbor_username"></a> [harbor\_username](#input\_harbor\_username) | The username for the Harbor registry. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Associated namespace in kubernetes cluster. | `string` | n/a | yes |
| <a name="input_repository_id"></a> [repository\_id](#input\_repository\_id) | The ID of the Forgejo repository. | `string` | n/a | yes |
| <a name="input_stage"></a> [stage](#input\_stage) | Deployment stage used for secret suffixing (`dev` or `prod`). | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
