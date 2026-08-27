---
name: GitHub Workflow Building Block
supportedPlatforms:
  - meshstack
description: |
  Reference building block demonstrating meshStack's GITHUB_WORKFLOW implementation type:
  triggers a GitHub Actions workflow on apply and captures the run URL as output.
---
# GitHub Workflow Building Block

This building block is a reference implementation demonstrating how meshStack triggers GitHub Actions workflows as building block automation. It exercises the `GITHUB_WORKFLOW` implementation type with a user-provided environment input and a workflow run URL output.

Use it to:

- Understand how meshStack wires a `meshstack_integration` (GitHub App) to a `meshstack_building_block_definition`
- See how workflow inputs are passed and the run URL is captured as a `RESOURCE_URL` output
- Validate GitHub App credentials and integration configuration

## Inputs / Outputs

| Name | Direction | Type | Assignment | Description |
| ---- | --------- | ---- | ---------- | ----------- |
| `environment` | Input | `STRING` | `USER_INPUT` | Target environment passed to the workflow |
| `run_url` | Output | `STRING` | `RESOURCE_URL` | URL of the triggered GitHub Actions workflow run |

## Prerequisites

- A GitHub App installed on the target organization/repository with permissions to trigger workflows.
- The App ID and PEM-encoded private key are required as `github_app_id` and `github_app_private_key` variables.

## Backplane Workflow Bootstrap

This module includes a backplane at `modules/meshstack/github-workflow/backplane` that provisions reference workflow files directly into your target repository.

Use it as a starting point for your dedicated test repository:

- Configure Terraform GitHub provider authentication with access to the target repository.
- Set `github_repository` in `owner/repo` format.
- Keep `github_apply_workflow` / `github_destroy_workflow` aligned with filenames in your repository (defaults: `apply.yml`, `destroy.yml`).
- Customize the generated workflow templates in `backplane/dotgithub/workflows/` to add real provisioning logic.
