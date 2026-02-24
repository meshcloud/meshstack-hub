---
name: STACKIT Git Repository
supportedPlatforms:
  - stackit
description: Provisions a Git repository on STACKIT Git (Forgejo/Gitea) with optional template initialization, webhook configuration, and CI/CD integration.
---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_gitea"></a> [gitea](#requirement\_gitea) | ~> 0.16.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2.3 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [gitea_repository.repo](https://registry.terraform.io/providers/Lerentis/gitea/latest/docs/resources/repository) | resource |
| [null_resource.template_repo](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.webhook](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_branch"></a> [default\_branch](#input\_default\_branch) | Default branch name | `string` | `"main"` | no |
| <a name="input_gitea_base_url"></a> [gitea\_base\_url](#input\_gitea\_base\_url) | STACKIT Git base URL | `string` | `"https://git-service.git.onstackit.cloud"` | no |
| <a name="input_gitea_organization"></a> [gitea\_organization](#input\_gitea\_organization) | STACKIT Git organization where the repository will be created | `string` | n/a | yes |
| <a name="input_gitea_token"></a> [gitea\_token](#input\_gitea\_token) | STACKIT Git API token (from backplane) | `string` | n/a | yes |
| <a name="input_repository_auto_init"></a> [repository\_auto\_init](#input\_repository\_auto\_init) | Auto-initialize the repository with a README | `bool` | `true` | no |
| <a name="input_repository_description"></a> [repository\_description](#input\_repository\_description) | Short description of the repository | `string` | `""` | no |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Name of the Git repository to create | `string` | n/a | yes |
| <a name="input_repository_private"></a> [repository\_private](#input\_repository\_private) | Whether the repository should be private | `bool` | `true` | no |
| <a name="input_template_name"></a> [template\_name](#input\_template\_name) | Name of the template repository | `string` | `"app-template-python"` | no |
| <a name="input_template_namespace"></a> [template\_namespace](#input\_template\_namespace) | Value for the NAMESPACE variable used during template substitution | `string` | `""` | no |
| <a name="input_template_owner"></a> [template\_owner](#input\_template\_owner) | Owner/organization of the template repository | `string` | `"stackit"` | no |
| <a name="input_template_repo_name"></a> [template\_repo\_name](#input\_template\_repo\_name) | Value for the REPO\_NAME variable used during template substitution | `string` | `""` | no |
| <a name="input_use_template"></a> [use\_template](#input\_use\_template) | Create repository from a template repository instead of creating an empty one | `bool` | `false` | no |
| <a name="input_webhook_events"></a> [webhook\_events](#input\_webhook\_events) | List of Gitea events that trigger the webhook | `list(string)` | <pre>[<br>  "push",<br>  "create"<br>]</pre> | no |
| <a name="input_webhook_secret"></a> [webhook\_secret](#input\_webhook\_secret) | Secret for webhook authentication | `string` | `""` | no |
| <a name="input_webhook_url"></a> [webhook\_url](#input\_webhook\_url) | Webhook URL to configure (e.g., Argo Workflows EventSource URL). Leave empty to skip. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repository_clone_url"></a> [repository\_clone\_url](#output\_repository\_clone\_url) | HTTPS clone URL |
| <a name="output_repository_html_url"></a> [repository\_html\_url](#output\_repository\_html\_url) | Web URL of the repository |
| <a name="output_repository_id"></a> [repository\_id](#output\_repository\_id) | The ID of the created repository |
| <a name="output_repository_name"></a> [repository\_name](#output\_repository\_name) | Name of the created repository |
| <a name="output_repository_ssh_url"></a> [repository\_ssh\_url](#output\_repository\_ssh\_url) | SSH clone URL |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary with next steps and links for the created repository |
<!-- END_TF_DOCS -->
