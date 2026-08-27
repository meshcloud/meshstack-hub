# GitHub Workflow Backplane

This backplane manages workflow files in a target GitHub repository for the meshStack GitHub Workflow building block.
It provisions a reference apply workflow and a reference destroy workflow into `.github/workflows/`.
Both workflows are intentionally no-op regarding cloud resources and are meant for local testing, smoke tests, and as a starting point for real automation.

## What this backplane provisions

- `github_repository_file.workflow["<apply-workflow>"]` writing `.github/workflows/<apply-workflow>`
- `github_repository_file.workflow["<destroy-workflow>"]` writing `.github/workflows/<destroy-workflow>`

## Required access

The GitHub provider identity used to run this backplane needs repository permissions that allow writing workflow files, for example:

- Repository contents: write
- Workflows: write

If using GitHub App authentication for the provider, make sure the app is installed on the target repository.

## Operational notes

- The backplane commits workflow files to `github_branch`.
- Workflow file content is rendered from templates in `backplane/dotgithub/workflows/`.
- `overwrite_on_create = true` is used so first creation is idempotent when files already exist.
- Destroying this backplane will remove the managed workflow files from the target repository.
