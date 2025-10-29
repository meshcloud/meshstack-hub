---
name: Azure DevOps Git Repository
supportedPlatforms:
  - azuredevops
description: Provides a Git repository in Azure DevOps with optional branch protection policies
category: devops
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

## Outputs

- `repository_id` - Unique identifier for the repository
- `repository_url` - Git clone URL (HTTPS)
- `ssh_url` - Git clone URL (SSH)
- `web_url` - Browser URL for the repository
- `default_branch` - Name of the default branch

## Security Considerations

- Branch policies help enforce code review standards
- Minimum reviewers prevent unreviewed code from being merged
- Work item linking ensures traceability
- PAT should have minimal required scopes (`Code (Read & Write)`)
