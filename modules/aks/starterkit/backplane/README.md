# AKS Starterkit Backplane

The AKS Starterkit backplane registers the child building block definitions
(GitHub Repository, GitHub Actions Connector, and optionally Azure PostgreSQL)
that compose the starterkit.

The backplane references other Hub modules via git URLs.
The `meshstack_integration.tf` includes this backplane using a local `./backplane` source.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.19.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_github_connector_bbd"></a> [github\_connector\_bbd](#module\_github\_connector\_bbd) | github.com/meshcloud/meshstack-hub//modules/aks/github-connector | feature/aks-starter-kit-refactoring |
| <a name="module_github_repo_bbd"></a> [github\_repo\_bbd](#module\_github\_repo\_bbd) | github.com/meshcloud/meshstack-hub//modules/github/repository | feature/aks-starter-kit-refactoring |
| <a name="module_postgresql_bbd"></a> [postgresql\_bbd](#module\_postgresql\_bbd) | github.com/meshcloud/meshstack-hub//modules/azure/postgresql | feature/aks-starter-kit-refactoring |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_github"></a> [github](#input\_github) | GitHub App credentials and connector configuration. | <pre>object({<br>    org                        = string<br>    app_id                     = string<br>    app_installation_id        = string<br>    app_pem_file               = string<br>    connector_config_tf_base64 = string<br>  })</pre> | n/a | yes |
| <a name="input_hub"></a> [hub](#input\_hub) | Hub release reference. Set git\_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo. | <pre>object({<br>    git_ref = string<br>  })</pre> | n/a | yes |
| <a name="input_meshstack"></a> [meshstack](#input\_meshstack) | Shared meshStack context passed down from the IaC runtime. | <pre>object({<br>    owning_workspace_identifier = string<br>  })</pre> | n/a | yes |
| <a name="input_postgresql"></a> [postgresql](#input\_postgresql) | When non-null, registers the azure/postgresql BBD as part of the starterkit composition. Omit/null for deployments that don't need PostgreSQL. | `object({})` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_github_connector_bbd_version_uuid"></a> [github\_connector\_bbd\_version\_uuid](#output\_github\_connector\_bbd\_version\_uuid) | UUID of the latest version of the GitHub Actions connector building block definition. |
| <a name="output_github_repo_bbd_uuid"></a> [github\_repo\_bbd\_uuid](#output\_github\_repo\_bbd\_uuid) | UUID of the GitHub repository building block definition. |
| <a name="output_github_repo_bbd_version_uuid"></a> [github\_repo\_bbd\_version\_uuid](#output\_github\_repo\_bbd\_version\_uuid) | UUID of the latest version of the GitHub repository building block definition. |
<!-- END_TF_DOCS -->