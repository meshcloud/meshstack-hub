---
name: Azure DevOps Git Repository
supportedPlatforms:
  - azuredevops
description: Provides a Git repository in Azure DevOps with optional branch protection policies
---

# Azure DevOps Repository Building Block

Creates and manages Git repositories in Azure DevOps projects with optional branch protection policies.

## Prerequisites

- Deployed Azure DevOps Repository backplane
- Azure DevOps project ID where the repository will be created
- Azure DevOps PAT stored in Key Vault with `Code (Read & Write)` scope

## Features

- Creates Git repositories with configurable initialization
- Optional branch protection policies:
  - Minimum number of reviewers for pull requests
  - Work item linking requirements
  - No self-approval on PRs
- Supports clean initialization or uninitialized repositories

## Usage

```hcl
module "azuredevops_repository" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-repo-prod"
  resource_group_name           = "rg-azdo-repo-prod"
  pat_secret_name               = "azdo-pat"

  project_id      = "12345678-1234-1234-1234-123456789012"
  repository_name = "my-app-repo"

  init_type              = "Clean"
  enable_branch_policies = true
  minimum_reviewers      = 2
}
```

## Branch Protection Policies

When `enable_branch_policies` is set to `true`, the following policies are applied to the default branch:

- **Minimum Reviewers**: Requires the specified number of reviewers
- **No Self-Approval**: Submitter cannot approve their own PR
- **Last Pusher Cannot Approve**: The last person to push changes cannot approve
- **Reset Votes on Push**: Approvals are reset when new changes are pushed
- **Work Item Linking**: PRs should link to work items (non-blocking)

## Repository Initialization Options

- `Clean`: Creates a repository with an initial commit and README
- `Uninitialized`: Creates an empty repository without any commits
- `Import`: Requires additional configuration for importing from another repository

## Integration with Azure DevOps Project Module

This building block is designed to work with repositories created in projects managed by the Azure DevOps Project building block:

```hcl
module "azuredevops_project" {
  source = "../project/buildingblock"
  # ... project configuration
}

module "app_repository" {
  source = "./buildingblock"

  project_id = module.azuredevops_project.project_id
  # ... repository configuration
}
```

## Security Considerations

- Branch policies help enforce code review standards
- Minimum reviewers prevent unreviewed code from being merged
- Work item linking ensures traceability
- PAT should have minimal required scopes (`Code (Read & Write)`)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | ~> 1.1.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 4.51.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuredevops_branch_policy_min_reviewers.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/branch_policy_min_reviewers) | resource |
| [azuredevops_branch_policy_work_item_linking.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/branch_policy_work_item_linking) | resource |
| [azuredevops_git_repository.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/git_repository) | resource |
| [azurerm_key_vault.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.azure_devops_pat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#input\_azure\_devops\_organization\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_enable_branch_policies"></a> [enable\_branch\_policies](#input\_enable\_branch\_policies) | Enable branch protection policies on the default branch | `bool` | `true` | no |
| <a name="input_init_type"></a> [init\_type](#input\_init\_type) | Type of repository initialization. Options: Clean, Import, Uninitialized | `string` | `"Clean"` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault containing the Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_minimum_reviewers"></a> [minimum\_reviewers](#input\_minimum\_reviewers) | Minimum number of reviewers required for pull requests | `number` | `2` | no |
| <a name="input_pat_secret_name"></a> [pat\_secret\_name](#input\_pat\_secret\_name) | Name of the secret in Key Vault that contains the Azure DevOps PAT | `string` | `"azdo-pat"` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Azure DevOps Project ID where the repository will be created | `string` | n/a | yes |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Name of the Git repository to create | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group containing the Key Vault | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_branch_policies_enabled"></a> [branch\_policies\_enabled](#output\_branch\_policies\_enabled) | Whether branch policies are enabled |
| <a name="output_default_branch"></a> [default\_branch](#output\_default\_branch) | Default branch of the repository |
| <a name="output_repository_id"></a> [repository\_id](#output\_repository\_id) | ID of the created repository |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Name of the created repository |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | URL of the created repository |
| <a name="output_ssh_url"></a> [ssh\_url](#output\_ssh\_url) | SSH URL of the repository |
| <a name="output_web_url"></a> [web\_url](#output\_web\_url) | Web URL of the repository |
<!-- END_TF_DOCS -->