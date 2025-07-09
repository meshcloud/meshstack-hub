---
name: Azure GitHub Actions Terraform Setup
supportedPlatforms:
  - azure
description: |
  Deploy directly to Azure using GitHub Actions and Terraform brought to you by meshStack
---

# Azure GitHub Actions Terraform Setup

## Structure of this Kit module
This kit module consists of three components, each enabling the deployment of the next. It serves as the foundational building block — a Terraform module that defines an instance of the starter kit for a specific application team. This includes setting up a GitHub repository and a GitHub Actions pipeline.

For more information, refer to the backplane documentation of the [Azure GitHub Actions Terraform Setup Module](https://github.com/meshcloud/meshstack-hub/modules/azure/github-actions-terraform-setup/backplane/README.md).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | 3.0.2 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 4.4.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | 6.3.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | 3.6.3 |
| <a name="requirement_time"></a> [time](#requirement\_time) | 0.11.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azurerm_federated_identity_credential.ghactions](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/federated_identity_credential) | resource |
| [azurerm_resource_group.app](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/resource_group) | resource |
| [azurerm_resource_group.cicd](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/resource_group) | resource |
| [azurerm_role_assignment.ghaction_tfstate](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.ghactions_app](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.ghactions_register](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.project_admins_blobs](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.starterkit_deploy](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_assignment) | resource |
| [azurerm_role_definition.ghactions](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_definition) | resource |
| [azurerm_role_definition.ghactions_register](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/role_definition) | resource |
| [azurerm_storage_account.tfstates](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/storage_account) | resource |
| [azurerm_storage_container.tfstates](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/storage_container) | resource |
| [azurerm_user_assigned_identity.ghactions](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/resources/user_assigned_identity) | resource |
| [github_actions_secret.arm_client_id](https://registry.terraform.io/providers/integrations/github/6.3.0/docs/resources/actions_secret) | resource |
| [github_repository_environment.sandbox](https://registry.terraform.io/providers/integrations/github/6.3.0/docs/resources/repository_environment) | resource |
| [github_repository_environment_deployment_policy.sandbox_all](https://registry.terraform.io/providers/integrations/github/6.3.0/docs/resources/repository_environment_deployment_policy) | resource |
| [github_repository_file.backend_tf](https://registry.terraform.io/providers/integrations/github/6.3.0/docs/resources/repository_file) | resource |
| [github_repository_file.provider_tf](https://registry.terraform.io/providers/integrations/github/6.3.0/docs/resources/repository_file) | resource |
| [random_string.resource_code](https://registry.terraform.io/providers/hashicorp/random/3.6.3/docs/resources/string) | resource |
| [time_sleep.wait](https://registry.terraform.io/providers/hashicorp/time/0.11.1/docs/resources/sleep) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/3.0.2/docs/data-sources/client_config) | data source |
| [azuread_group.project_admins](https://registry.terraform.io/providers/hashicorp/azuread/3.0.2/docs/data-sources/group) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/4.4.0/docs/data-sources/subscription) | data source |
| [github_repository.repository](https://registry.terraform.io/providers/integrations/github/6.3.0/docs/data-sources/repository) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_deploy_role_definition_id"></a> [deploy\_role\_definition\_id](#input\_deploy\_role\_definition\_id) | Role definition ID to assign to the GitHub Actions App Service Managed Identity. This is used to deploy resources via Terraform. | `string` | n/a | yes |
| <a name="input_location"></a> [location](#input\_location) | n/a | `string` | `"westeurope"` | no |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | n/a | `string` | n/a | yes |
| <a name="input_repo_name"></a> [repo\_name](#input\_repo\_name) | Name of the repository to connect. | `string` | n/a | yes |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | n/a | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repository_html_url"></a> [repository\_html\_url](#output\_repository\_html\_url) | n/a |
<!-- END_TF_DOCS -->
