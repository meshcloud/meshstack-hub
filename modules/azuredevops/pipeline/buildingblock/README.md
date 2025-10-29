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
