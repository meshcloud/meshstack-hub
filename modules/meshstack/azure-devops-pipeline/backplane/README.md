# Azure DevOps Pipeline Backplane

This backplane commits the reference pipeline file into an **existing** Azure DevOps Git repository,
for the meshStack Azure DevOps Pipeline building block. The pipeline provisions nothing: it checks
that every template parameter meshStack sent arrived, and fails the run if one did not.

## What this backplane provisions

- `azuredevops_git_repository_file.pipeline` writing `azuredevops_pipeline_yaml_path` (default
  `azure-pipelines.yml`) onto `azuredevops_ref_name` in `azuredevops_repository_id`.

Content comes from [`pipelines/azure-pipelines.yml`](pipelines/azure-pipelines.yml).

## Required access

The personal access token needs **Code (Read & write)** on the target repository. Note that the
token meshStack itself stores — `azuredevops_personal_access_token` in `meshstack_integration.tf` —
is the same variable, so as written it also carries write access to the repository. meshStack only
ever needs **Build (Read & execute)**: to queue a pipeline run and read its timeline. Split the two
by applying this backplane with a write-scoped token and registering the integration with a
read-and-execute one if that difference matters to you.

Azure DevOps personal access tokens expire — a year at most — and there is no federated alternative:
meshStack's Azure DevOps integration config is base URL, organization and PAT, and the runner sends
that PAT as HTTP Basic.

## Operational notes

- `overwrite_on_create = true`, so a first apply adopts a pipeline file that is already on the branch
  instead of failing.
- Destroying the backplane deletes the pipeline file from the branch. Destroy it only after every
  building block of the definition is gone — a delete run queues the same pipeline, so it needs the
  file to still be there.
- `ref_name` and `pipeline_yaml_path` are re-exported as outputs that depend on the commit. Build the
  building block definition's `ref_name` from the output rather than from the variable, so the
  definition can never point at a ref that does not carry the file yet.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_azuredevops"></a> [azuredevops](#requirement\_azuredevops) | >= 1.1.1, < 2.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuredevops_git_repository_file.pipeline](https://registry.terraform.io/providers/microsoft/azuredevops/latest/docs/resources/git_repository_file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_azuredevops_base_url"></a> [azuredevops\_base\_url](#input\_azuredevops\_base\_url) | Base URL of the Azure DevOps instance. Override for Azure DevOps Server. | `string` | `"https://dev.azure.com"` | no |
| <a name="input_azuredevops_organization"></a> [azuredevops\_organization](#input\_azuredevops\_organization) | Azure DevOps organization name, as it appears in the URL after the base URL. | `string` | n/a | yes |
| <a name="input_azuredevops_personal_access_token"></a> [azuredevops\_personal\_access\_token](#input\_azuredevops\_personal\_access\_token) | Personal access token used to commit the pipeline file. Needs Code (Read & write) on the repository below. | `string` | n/a | yes |
| <a name="input_azuredevops_pipeline_yaml_path"></a> [azuredevops\_pipeline\_yaml\_path](#input\_azuredevops\_pipeline\_yaml\_path) | Repository path the pipeline file is committed to. Must match the YAML path the pipeline definition was created with — Azure DevOps reads that path and nothing else. | `string` | `"azure-pipelines.yml"` | no |
| <a name="input_azuredevops_ref_name"></a> [azuredevops\_ref\_name](#input\_azuredevops\_ref\_name) | Full git ref the pipeline file is committed to and the pipeline runs on, for example 'refs/heads/main'. The branch must already exist — this backplane commits onto it, it does not create it. | `string` | `"refs/heads/main"` | no |
| <a name="input_azuredevops_repository_id"></a> [azuredevops\_repository\_id](#input\_azuredevops\_repository\_id) | UUID of the Azure DevOps Git repository holding the pipeline file. Found under Project settings → Repositories → the repository, as the `repo` query parameter. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pipeline_yaml_path"></a> [pipeline\_yaml\_path](#output\_pipeline\_yaml\_path) | Repository path the pipeline file was committed to. |
| <a name="output_ref_name"></a> [ref\_name](#output\_ref\_name) | Full git ref the pipeline runs on, for the building block definition's `ref_name`. |
<!-- END_TF_DOCS -->
