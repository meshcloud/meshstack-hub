# STACKIT Git Repository – Backplane

This module sets up the shared backplane configuration for the STACKIT Git Repository building block.
It validates that the configured organization exists via the HTTP data source during plan/apply.
The validated organization is exposed as output for use by individual building block instances.

## Prerequisites

A Personal Access Token from STACKIT Git is required:

1. Log in to [STACKIT Git](https://git-service.git.onstackit.cloud)
2. Go to **Settings → Applications → Manage Access Tokens**
3. Generate a new token with the following scopes:
   - `write:repository` – create and manage repositories
   - `write:organization` – manage organization repositories
4. Copy the token (shown only once)

## Usage

```hcl
module "git_repo_backplane" {
  source = "./backplane"

  forgejo_base_url     = "https://git-service.git.onstackit.cloud"
  forgejo_token        = var.stackit_git_token
  forgejo_organization = "my-platform-org"
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `forgejo_base_url` | STACKIT Git base URL | `string` | no (default provided) |
| `forgejo_token` | STACKIT Git Personal Access Token | `string` | yes |
| `forgejo_organization` | Default organization for repository creation | `string` | yes |

## Outputs

| Name | Description |
|------|-------------|
| `forgejo_base_url` | STACKIT Git base URL |
| `forgejo_token` | STACKIT Git API token (sensitive) |
| `forgejo_organization` | Default STACKIT Git organization |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | ~> 3.4 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [http_http.org_lookup](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_forgejo_base_url"></a> [forgejo\_base\_url](#input\_forgejo\_base\_url) | STACKIT Git base URL | `string` | `"https://git-service.git.onstackit.cloud"` | no |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | Default STACKIT Git organization where repositories will be created | `string` | n/a | yes |
| <a name="input_forgejo_token"></a> [forgejo\_token](#input\_forgejo\_token) | STACKIT Git Personal Access Token with write:repository and write:organization scopes | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_forgejo_organization"></a> [forgejo\_organization](#output\_forgejo\_organization) | Default STACKIT Git organization for repository creation |
<!-- END_TF_DOCS -->
