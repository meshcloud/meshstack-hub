---
name: STACKIT Git Repository
supportedPlatforms:
  - stackit
description: Provisions a Git repository on STACKIT Git (Forgejo) with optional template initialization, webhook configuration, and CI/CD integration.
---

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.4.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | 3.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [restapi_object.repository](https://registry.terraform.io/providers/Mastercard/restapi/3.0.0/docs/resources/object) | resource |
| [restapi_object.webhook](https://registry.terraform.io/providers/Mastercard/restapi/3.0.0/docs/resources/object) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_default_branch"></a> [default\_branch](#input\_default\_branch) | Default branch name | `string` | `"main"` | no |
| <a name="input_description"></a> [description](#input\_description) | Short description of the repository | `string` | `""` | no |
| <a name="input_forgejo_base_url"></a> [forgejo\_base\_url](#input\_forgejo\_base\_url) | STACKIT Git base URL | `string` | `"https://git-service.git.onstackit.cloud"` | no |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | STACKIT Git organization where the repository will be created | `string` | n/a | yes |
| <a name="input_forgejo_token"></a> [forgejo\_token](#input\_forgejo\_token) | STACKIT Git API token (from backplane) | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | Name of the Git repository to create | `string` | n/a | yes |
| <a name="input_private"></a> [private](#input\_private) | Whether the repository should be private | `bool` | `true` | no |
| <a name="input_template_repo_path"></a> [template\_repo\_path](#input\_template\_repo\_path) | Path (owner/name) to the template repository. | `string` | `""` | no |
| <a name="input_use_template"></a> [use\_template](#input\_use\_template) | Create repository from a template repository given by template\_repo\_path instead of creating an empty one. | `bool` | `false` | no |
| <a name="input_webhook_events"></a> [webhook\_events](#input\_webhook\_events) | List of Forgejo events that trigger the webhook | `list(string)` | <pre>[<br/>  "push",<br/>  "create"<br/>]</pre> | no |
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
