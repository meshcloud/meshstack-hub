---
name: GitHub Repository Creation
supportedPlatforms:
  - github
description: |
  Automates GitHub repository setup with predefined configurations and access control.
---

# GitHub Repository Building Block

This documentation is intended as a reference documentation for cloud foundation or platform engineers using this module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | 3.116.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | 5.42.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [github_repository.repository](https://registry.terraform.io/providers/integrations/github/5.42.0/docs/resources/repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_repo_description"></a> [repo\_description](#input\_repo\_description) | Description of the GitHub repository | `string` | `"created by github-repo-building-block"` | no |
| <a name="input_repo_name"></a> [repo\_name](#input\_repo\_name) | Name of the GitHub repository | `string` | `"github-repo"` | no |
| <a name="input_repo_visibility"></a> [repo\_visibility](#input\_repo\_visibility) | Visibility of the GitHub repository | `string` | `"private"` | no |
| <a name="input_template_owner"></a> [template\_owner](#input\_template\_owner) | Owner of the template repository | `string` | `"template-owner"` | no |
| <a name="input_template_repo"></a> [template\_repo](#input\_template\_repo) | Name of the template repository | `string` | `"github-repo"` | no |
| <a name="input_use_template"></a> [use\_template](#input\_use\_template) | Flag to indicate whether to create a repo based on a Template Repository | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repo_full_name"></a> [repo\_full\_name](#output\_repo\_full\_name) | n/a |
| <a name="output_repo_git_clone_url"></a> [repo\_git\_clone\_url](#output\_repo\_git\_clone\_url) | n/a |
| <a name="output_repo_html_url"></a> [repo\_html\_url](#output\_repo\_html\_url) | n/a |
| <a name="output_repo_name"></a> [repo\_name](#output\_repo\_name) | n/a |
<!-- END_TF_DOCS -->
