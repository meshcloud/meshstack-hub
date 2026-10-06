---
name: STACKIT Git Instance
supportedPlatforms:
  - stackit
description: Provisions a STACKIT Git (Forgejo) instance in a STACKIT project, the Forgejo organization repositories are created in, and the API token both are managed with.
---

# STACKIT Git Instance Building Block

This building block provisions a **STACKIT Git** instance — a managed Forgejo — in a STACKIT
project, and creates the Forgejo **organization** that the `stackit/git-repository` building block
later creates application repositories in.

## The token mints itself

A fresh instance carries no credential, so the building block makes one instead of asking for it:

1. **Create a technical user.** `POST /v1beta/projects/{projectId}/instances/{instanceId}/users`
   with `{name, username, email, password, force_send_reset_password}`, the password from
   `random_password`.
2. **Exchange that password for a token.** Forgejo's `POST
   {instance_url}/api/v1/users/{username}/tokens` returns the PAT in its `sha1` field. That route
   takes HTTP Basic auth only — a caller holding an API token cannot mint another — which is exactly
   why the local user exists.

With `output_to_vault` set, the token is written to that Vault KV v2 secret under the key
`forgejo_api_token`, where the building blocks that manage repositories, runners and organization
members read it. There is no token input and no token output.

Forgejo never returns a token's secret again, so the value is read from the `create_response` of the
`restapi_object`, which keeps the create body in state. A read addresses the list endpoint and picks
the token out by name, because Forgejo has no get-one-token route.

## The STACKIT-hosted shared runner

When `shared_runner_labels` is not empty, the building block orders the shared runner STACKIT hosts
for the instance through `POST /v1beta/projects/{projectId}/instances/{instanceId}/runner`, with
those labels. An instance has at most one runner, and the API cannot change its labels, so a change
of labels replaces the runner. The definition defaults the labels to empty, and then no runner is
ordered.

### The token is not an output

meshStack shows a building block's outputs in the clear to everyone who can view the block, even
an output OpenTofu marks `sensitive`. The token therefore goes to the Vault KV v2 secret only, and
consumers receive it as a `sensitive` input, which meshStack does protect.

### Verified against a live instance

Forgejo `16.0.3`, September 2026. The technical user came back `is_admin: false`, and with that
identity alone:

| Step | Result |
|---|---|
| `POST .../users` | `201`, user created |
| `POST /api/v1/users/{u}/tokens` over basic auth | `201` with a `sha1` |
| `POST /api/v1/orgs` with that token | `201` — a plain user may create an organization |
| `GET /orgs/{org}/actions/runners/registration-token` | `200` — its owner may mint runner tokens |

The last two are the reason this works without site-admin rights: the technical user owns the
organization it creates, so the same token administers it afterwards.

## Adopting an existing instance

With `imports` set, the building block takes over the existing instance with that `instance_id`
instead of creating one; its name must equal `instance_name`. It creates its own technical user,
named `local_user_username` plus a random suffix, because the instance's existing user has a password
this building block does not know. It orders no shared runner, because STACKIT allows one per
instance.

With `release_on_destroy` set, destroying the building block leaves the instance in place.
`release_on_destroy` cannot change once the instance is managed.

## Notes

- `<name>.git.onstackit.cloud` is **globally unique across all of STACKIT**, so `instance_name` must
  carry something unique — a platform identifier with a random suffix, not a product name.
- The instance does not support in-place updates: changing the name, flavor or ACL replaces it, and
  replacing it destroys every repository in it.
- The organization is created with the generic `restapi` provider rather than the gitea provider:
  with gitea, creating the organization works but refreshing the plan fails with a 403 against
  STACKIT Git, so every subsequent run breaks.
- An organization that already exists (for example one created by hand before this building block
  took over) has to be imported — the create call returns 422 otherwise.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.0, < 3.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5.0, < 4.0.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.83.0, < 1.0.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 5.12.0, < 6.0.0 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_instance"></a> [instance](#module\_instance) | ./modules/git-instance | n/a |
| <a name="module_organization_teams"></a> [organization\_teams](#module\_organization\_teams) | ./forgejo-teams | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [random_password.local_user](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_string.local_user_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [restapi_object.forgejo_organization](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.local_user](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.local_user_token](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.shared_runner](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [vault_kv_secret_v2.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kv_secret_v2) | resource |
| [external_external.instance_users](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.stackit_access_token](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | Forgejo organization to create inside the instance. Empty provisions the bare instance. | `string` | n/a | yes |
| <a name="input_imports"></a> [imports](#input\_imports) | Existing STACKIT Git instance this building block takes over instead of creating one. Its name must equal `instance_name`. The technical user then gets a random suffix, and no shared runner is ordered. Null creates a new instance. | <pre>object({<br/>    instance_id = string<br/>  })</pre> | `null` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | First label of the instance hostname `<name>.git.onstackit.cloud`, globally unique across all of STACKIT. | `string` | n/a | yes |
| <a name="input_local_user_email"></a> [local\_user\_email](#input\_local\_user\_email) | Email of the technical user. Leave empty to derive one from the instance hostname. | `string` | n/a | yes |
| <a name="input_local_user_token_name"></a> [local\_user\_token\_name](#input\_local\_user\_token\_name) | Name of the Personal Access Token the module mints. | `string` | n/a | yes |
| <a name="input_local_user_token_scopes"></a> [local\_user\_token\_scopes](#input\_local\_user\_token\_scopes) | Forgejo scopes of the minted token. | `list(string)` | n/a | yes |
| <a name="input_local_user_username"></a> [local\_user\_username](#input\_local\_user\_username) | Username of the technical user the module mints its token on. | `string` | n/a | yes |
| <a name="input_output_to_vault"></a> [output\_to\_vault](#input\_output\_to\_vault) | Vault KV v2 secret this building block writes its secrets to: the server `address`, the engine `mount`, a userpass `username` and `password`, and the secret `path`. Null writes none. | <pre>object({<br/>    address  = string<br/>    mount    = string<br/>    username = string<br/>    password = string<br/>    path     = string<br/>  })</pre> | `null` | no |
| <a name="input_release_on_destroy"></a> [release\_on\_destroy](#input\_release\_on\_destroy) | Leave the instance in place when this building block is destroyed. Cannot change once the instance is managed. | `bool` | `false` | no |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Maps meshStack roles from `users[*].roles` to Forgejo organization roles: `owner`, `writer` or `reader`. The highest one wins; unknown meshStack roles are ignored. | `map(list(string))` | n/a | yes |
| <a name="input_shared_runner_labels"></a> [shared\_runner\_labels](#input\_shared\_runner\_labels) | Labels of the STACKIT-hosted shared runner to order. Leave empty to order none. | `list(string)` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project the Git instance is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the Git instance is placed in. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | meshStack project members. Each user's `roles` are mapped to a Forgejo organization role via `role_mapping`. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_forgejo_organization"></a> [forgejo\_organization](#output\_forgejo\_organization) | Name of the Forgejo organization for this instance. Empty when none was asked for. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | STACKIT Git instance id. |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | Name of the STACKIT Git instance. |
| <a name="output_instance_url"></a> [instance\_url](#output\_instance\_url) | URL of the Forgejo instance. |
| <a name="output_local_user_username"></a> [local\_user\_username](#output\_local\_user\_username) | Username of the technical user the token belongs to. |
| <a name="output_organization_url"></a> [organization\_url](#output\_organization\_url) | URL of the Forgejo organization. Falls back to the instance URL when no organization was asked for. |
| <a name="output_vault_secret"></a> [vault\_secret](#output\_vault\_secret) | `{path, secret_hash}` of the secret written to `output_to_vault`, or `{}` when that is not set. `secret_hash` is the secret's KV version and changes with its content. |
<!-- END_TF_DOCS -->
