# Ansible VM Hardening Backplane

Commits the GitHub Actions workflow and the Ansible playbook of the `ansible/vm-hardening`
building block to the repository meshStack dispatches the workflow on.

## What this backplane provisions

- `.github/workflows/ansible-vm-hardening.yml`, from `buildingblock/workflow.yml`
- `ansible-vm-hardening/**`, from `buildingblock/ansible/**`

Each file is a `github_repository_file`, so the repository always holds the playbook of the hub
version the definition was deployed from.

## Required access

The GitHub App needs these repository permissions on the target repository:

- **Contents: write** — to commit the playbook
- **Workflows: write** — GitHub refuses changes under `.github/workflows/` without it
- **Actions: write** — meshStack dispatches the workflow with the same app

## Operational notes

- The branch has to exist, so an empty repository needs one commit first.
- Hand edits to the committed files are overwritten on the next apply. Change them in the hub module.
- Destroying the backplane deletes the committed files.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_github"></a> [github](#requirement\_github) | >= 6.0.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [github_repository_file.this](https://registry.terraform.io/providers/integrations/github/latest/docs/resources/repository_file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_github_app_id"></a> [github\_app\_id](#input\_github\_app\_id) | GitHub App ID used to authenticate the GitHub provider. | `string` | n/a | yes |
| <a name="input_github_app_installation_id"></a> [github\_app\_installation\_id](#input\_github\_app\_installation\_id) | GitHub App installation ID for the owner. Found under GitHub App settings → Install App → your org. | `string` | n/a | yes |
| <a name="input_github_app_private_key"></a> [github\_app\_private\_key](#input\_github\_app\_private\_key) | PEM-encoded private key of the GitHub App. | `string` | n/a | yes |
| <a name="input_github_branch"></a> [github\_branch](#input\_github\_branch) | Branch the files are committed to and the workflow is dispatched on. | `string` | `"main"` | no |
| <a name="input_github_owner"></a> [github\_owner](#input\_github\_owner) | GitHub organization or user that owns the repository. | `string` | n/a | yes |
| <a name="input_github_repository_name"></a> [github\_repository\_name](#input\_github\_repository\_name) | Repository (without owner) the workflow and the Ansible playbook are committed to. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_branch"></a> [branch](#output\_branch) | Branch the workflow is dispatched on. |
| <a name="output_workflow"></a> [workflow](#output\_workflow) | Workflow file meshStack dispatches. |
<!-- END_TF_DOCS -->