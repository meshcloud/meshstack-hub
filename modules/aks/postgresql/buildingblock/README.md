---
name: GitHub Actions Integration with AKS
description: |
  Building block module for integrating GitHub Actions with Azure Kubernetes Service (AKS)
---

# GitHub Actions Integration with AKS

This Terraform module provisions the necessary resources to integrate GitHub Actions with an AKS cluster. It sets up service accounts, secrets, and workflows for seamless CI/CD.

## How to Use

1. Define the required variables in your Terraform configuration.
2. Include this module in your Terraform code.
3. Apply the Terraform plan to provision the resources.
4. Use the generated GitHub Actions secrets and files to enable CI/CD workflows.
5. Customize the workflow file as needed for your application.

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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 4.4.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.35.1 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_postgresql_flexible_server.db_instance](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/postgresql_flexible_server) | resource |
| [kubernetes_secret.credentials](https://registry.terraform.io/providers/hashicorp/kubernetes/2.35.1/docs/resources/secret) | resource |
| [random_password.administrator_password](https://registry.terraform.io/providers/hashicorp/random/3.6.3/docs/resources/password) | resource |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_name"></a> [name](#input\_name) | User selected part of the name. | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Associated namespace in AKS. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | The meshStack project identifier. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | The meshStack workspace identifier. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_secret_name"></a> [secret\_name](#output\_secret\_name) | n/a |
<!-- END_TF_DOCS -->