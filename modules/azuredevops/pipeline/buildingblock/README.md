---
name: Azure DevOps Pipeline
supportedPlatforms:
  - azuredevops
description: Provides a CI/CD pipeline in Azure DevOps linked to a repository with YAML-based configuration
category: devops
---

# Azure DevOps Pipeline Building Block

Creates and manages Azure DevOps pipelines (build definitions) linked to repositories with YAML-based pipeline definitions.

## Prerequisites

- Deployed Azure DevOps Pipeline backplane
- Azure DevOps project ID where the pipeline will be created
- Repository with a YAML pipeline definition file
- Azure DevOps PAT stored in Key Vault with `Build (Read & Execute)` scope

## Features

- Creates YAML-based CI/CD pipelines
- Supports multiple repository types (Azure Repos, GitHub, Bitbucket)
- Links variable groups to pipelines
- Supports pipeline-specific variables (including secrets)
- Configurable branch and YAML file path

## Usage

### Basic Pipeline

```hcl
module "azuredevops_pipeline" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-pipeline-prod"
  resource_group_name           = "rg-azdo-pipeline-prod"
  pat_secret_name               = "azdo-pat"

  project_id    = "12345678-1234-1234-1234-123456789012"
  pipeline_name = "my-app-ci-cd"
  repository_id = "my-app-repo"
  yaml_path     = "azure-pipelines.yml"
}
```

### Pipeline with Variables

```hcl
module "azuredevops_pipeline" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-pipeline-prod"
  resource_group_name           = "rg-azdo-pipeline-prod"

  project_id    = "12345678-1234-1234-1234-123456789012"
  pipeline_name = "my-app-ci-cd"
  repository_id = "my-app-repo"
  yaml_path     = "ci/azure-pipelines.yml"

  pipeline_variables = [
    {
      name  = "environment"
      value = "production"
    },
    {
      name      = "api_key"
      value     = "secret-value"
      is_secret = true
    }
  ]

  variable_group_ids = [10, 20]
}
```

### GitHub Repository Pipeline

```hcl
module "github_pipeline" {
  source = "./buildingblock"

  azure_devops_organization_url = "https://dev.azure.com/myorg"
  key_vault_name                = "kv-azdo-pipeline-prod"
  resource_group_name           = "rg-azdo-pipeline-prod"

  project_id      = "12345678-1234-1234-1234-123456789012"
  pipeline_name   = "github-app-ci"
  repository_type = "GitHub"
  repository_id   = "myorg/my-repo"
  branch_name     = "refs/heads/main"
  yaml_path       = ".azuredevops/pipeline.yml"
}
```

## Repository Types

- **TfsGit** (default): Azure Repos Git repositories
- **GitHub**: GitHub repositories (requires service connection)
- **GitHubEnterprise**: GitHub Enterprise repositories
- **Bitbucket**: Bitbucket Cloud repositories

## Pipeline Variables

Variables can be defined with the following properties:

- `name` (required): Variable name
- `value` (required): Variable value
- `is_secret` (optional): Mark as secret (default: false)
- `allow_override` (optional): Allow override at queue time (default: true)

## Variable Groups

Link existing variable groups to the pipeline using their IDs:

```hcl
variable_group_ids = [10, 20, 30]
```

## Integration with Other Modules

This building block works with repositories and projects:

```hcl
module "azuredevops_project" {
  source = "../project/buildingblock"
  # ... project configuration
}

module "app_repository" {
  source = "../repository/buildingblock"
  project_id = module.azuredevops_project.project_id
  # ... repository configuration
}

module "ci_pipeline" {
  source = "./buildingblock"
  project_id    = module.azuredevops_project.project_id
  repository_id = module.app_repository.repository_id
  # ... pipeline configuration
}
```

## YAML Pipeline Requirements

The pipeline expects a YAML file in the repository at the specified path. Example:

```yaml
trigger:
  - main

pool:
  vmImage: 'ubuntu-latest'

steps:
  - script: echo Hello, world!
    displayName: 'Run a one-line script'

  - script: |
      echo Add other tasks to build, test, and deploy your project.
    displayName: 'Run a multi-line script'
```

## Outputs

- `pipeline_id` - Unique identifier for the pipeline
- `pipeline_name` - Name of the pipeline
- `pipeline_revision` - Current revision number
- `project_id` - Project where pipeline is created
- `repository_id` - Linked repository
- `yaml_path` - Path to YAML definition

## Security Considerations

- Use secret variables for sensitive data
- Secret variables are masked in pipeline logs
- Link variable groups for shared secrets across pipelines
- PAT should have minimal required scopes (`Build (Read & Execute)`)
- Use service connections for external repository access

## Limitations

- Pipeline definition must be YAML-based (classic pipelines not supported)
- YAML file must exist in the repository before pipeline creation
- Repository must be accessible with the provided credentials

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | ~> 1.1.1 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.116.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuredevops_build_definition.main](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/build_definition) | resource |
| [azurerm_key_vault.devops](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |
| [azurerm_key_vault_secret.azure_devops_pat](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault_secret) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azure_devops_organization_url"></a> [azure\_devops\_organization\_url](#input\_azure\_devops\_organization\_url) | Azure DevOps organization URL (e.g., https://dev.azure.com/myorg) | `string` | n/a | yes |
| <a name="input_branch_name"></a> [branch\_name](#input\_branch\_name) | Default branch for the pipeline | `string` | `"refs/heads/main"` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Name of the Key Vault containing the Azure DevOps PAT | `string` | n/a | yes |
| <a name="input_pat_secret_name"></a> [pat\_secret\_name](#input\_pat\_secret\_name) | Name of the secret in Key Vault that contains the Azure DevOps PAT | `string` | `"azdo-pat"` | no |
| <a name="input_pipeline_name"></a> [pipeline\_name](#input\_pipeline\_name) | Name of the pipeline to create | `string` | n/a | yes |
| <a name="input_pipeline_variables"></a> [pipeline\_variables](#input\_pipeline\_variables) | List of pipeline variables to create | <pre>list(object({<br>    name           = string<br>    value          = string<br>    is_secret      = optional(bool, false)<br>    allow_override = optional(bool, true)<br>  }))</pre> | `[]` | no |
| <a name="input_project_id"></a> [project\_id](#input\_project\_id) | Azure DevOps Project ID where the pipeline will be created | `string` | n/a | yes |
| <a name="input_repository_id"></a> [repository\_id](#input\_repository\_id) | Repository ID or name where the pipeline YAML file is located | `string` | n/a | yes |
| <a name="input_repository_type"></a> [repository\_type](#input\_repository\_type) | Type of repository. Options: TfsGit, GitHub, GitHubEnterprise, Bitbucket | `string` | `"TfsGit"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the resource group containing the Key Vault | `string` | n/a | yes |
| <a name="input_variable_group_ids"></a> [variable\_group\_ids](#input\_variable\_group\_ids) | List of variable group IDs to link to this pipeline | `list(number)` | `[]` | no |
| <a name="input_yaml_path"></a> [yaml\_path](#input\_yaml\_path) | Path to the YAML pipeline definition file in the repository | `string` | `"azure-pipelines.yml"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pipeline_id"></a> [pipeline\_id](#output\_pipeline\_id) | ID of the created pipeline |
| <a name="output_pipeline_name"></a> [pipeline\_name](#output\_pipeline\_name) | Name of the created pipeline |
| <a name="output_pipeline_revision"></a> [pipeline\_revision](#output\_pipeline\_revision) | Revision number of the pipeline |
| <a name="output_pipeline_url"></a> [pipeline\_url](#output\_pipeline\_url) | Deep link URL to the pipeline in Azure DevOps |
| <a name="output_project_id"></a> [project\_id](#output\_project\_id) | Project ID where the pipeline was created |
| <a name="output_repository_id"></a> [repository\_id](#output\_repository\_id) | Repository ID linked to the pipeline |
| <a name="output_yaml_path"></a> [yaml\_path](#output\_yaml\_path) | Path to the YAML pipeline definition |
<!-- END_TF_DOCS -->