---
name: Role Assignments for GitHub Actions Terraform Setup
supportedPlatforms:
  - azure
description: |
  Helper building block used to assign the necessary Azure roles
---

# Role Assignments for GitHub Actions Terraform Setup

This Terraform module is a helper building block used to assign the necessary Azure roles to the GitHub Actions pipeline **before** the main starter kit
module is executed.

## Purpose

The GitHub Actions pipeline requires specific permissions to deploy resources. Since these permissions must exist prior to running the main automation,
this module ensures that the correct `role_assignment` is created in advance.

## Usage Context

Due to changes in the access context after assigning roles, the automation must **re-authenticate** with a fresh login before proceeding with the main building block.
This module should therefore be executed as a separate step at the beginning of the deployment flow.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | 3.0.2 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 4.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_role_assignment.starterkit_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_assignment) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/3.0.2/docs/data-sources/client_config) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deploy_role_definition_id"></a> [deploy\_role\_definition\_id](#input\_deploy\_role\_definition\_id) | Role definition ID to assign to the GitHub Actions App Service Managed Identity. This is used to deploy resources via Terraform. | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
