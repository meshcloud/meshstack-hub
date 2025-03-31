---
name: GitHub Actions Integration with AKS
supportedPlatforms:
  - aks
description: |
  Provides an automated CI/CD pipeline using GitHub Actions to deploy applications to Azure Kubernetes Service (AKS). It enables application teams to build, test, and deploy containerized applications seamlessly while following best practices for security and scalability.
---

# GitHub Actions Integration with AKS

This Terraform module provisions the necessary resources to integrate GitHub Actions with an AKS cluster. It sets up service accounts, secrets, and workflows for seamless CI/CD.

## Requirements
- Terraform `>= 1.0`
- GitHub Provider `6.5.0`
- Kubernetes Provider `2.35.1`

## Providers

```hcl
terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "6.5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.35.1"
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_github"></a> [github](#requirement\_github) | 6.5.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_actions_secret.container_registry](https://registry.terraform.io/providers/integrations/github/6.5.0/docs/resources/actions_secret) | resource |
| [github_actions_secret.kubeconfig](https://registry.terraform.io/providers/integrations/github/6.5.0/docs/resources/actions_secret) | resource |
| [github_repository_file.dockerfile](https://registry.terraform.io/providers/integrations/github/6.5.0/docs/resources/repository_file) | resource |
| [github_repository_file.workflow](https://registry.terraform.io/providers/integrations/github/6.5.0/docs/resources/repository_file) | resource |
| [kubernetes_role.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/role) | resource |
| [kubernetes_role_binding.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/role_binding) | resource |
| [kubernetes_secret.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_secret.image_pull](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [kubernetes_service_account.github_actions](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/service_account) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_github_repo"></a> [github\_repo](#input\_github\_repo) | n/a | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Associated namespace in AKS. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
