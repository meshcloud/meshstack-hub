---
name: STACKIT Git Instance
supportedPlatforms:
  - stackit
description: Provisions a STACKIT Git (Forgejo) instance in a STACKIT project and, once a bot token exists, the Forgejo organization repositories are created in.
---

# STACKIT Git Instance Building Block

This building block provisions a **STACKIT Git** instance — a managed Forgejo — in a STACKIT
project, and creates the Forgejo **organization** that the `stackit/git-repository` building block
later creates application repositories in.

## Two phases, because the token is handed in today

A fresh instance has no credential yet, so the instance and the organization are created in two
runs:

1. **Without `forgejo_token`** the run creates only the instance and reports its URL. Nothing else
   happens; the organization resource is switched off.
2. A platform engineer opens that URL, signs in, creates (or reuses) a bot account and mints a
   Personal Access Token with the `write:organization` scope.
3. **With `forgejo_token` set** the next run creates the organization through the Forgejo REST API.

The [STACKIT Kubernetes Platform](../../../../reference-architectures/stackit-kubernetes) reference
architecture drives both phases from a single building block that is ordered once and then updated
with the token.

### The manual step is not required — it is just not wired yet

Step 2 can be automated. The STACKIT Git API (`v1beta`, `https://git.api.stackit.cloud`,
[spec](https://docs.api.eu01.stackit.cloud/oas/git/version/v1beta)) can create a local/technical
user in an instance:

- `POST /v1beta/projects/{projectId}/instances/{instanceId}/users` with
  `{name, username, email, password, force_send_reset_password}` (permission
  `git.instance.users.create`)
- `PATCH /v1beta/projects/{projectId}/instances/{instanceId}` with
  `{acl, admin_login, feature_toggle{enable_local_login}, labels}`

With that user's password, Forgejo's `POST {instance_url}/api/v1/users/{username}/tokens` returns
the PAT in its `sha1` field. That route accepts HTTP Basic auth only — an existing API token cannot
mint another — which is why a local user with a password is what unlocks it.

Neither call exists in the STACKIT Terraform provider or Go SDK yet, and `stackit_git` has no update
support and no `feature_toggle` attribute, so both would have to go out of band (`restapi`/`http`).
The flow is verified against the published spec, not against a live instance. The TODO in `main.tf`
marks the single expression an automatic mint has to feed: everything branches on
`local.forgejo_token`, so the token can come from the input or from a future mint without touching
anything else.

The backplane is already scoped for it: `git.admin` carries `git.instance.users.create` and
`git.instance.update`, the two permissions those calls need. A live instance reports Forgejo
`16.0.3+gitea-1.22.0` with `enable_local_login: false` and `admin_login: false` — so local login
has to be switched on first, and that version is past the route's v16.0.0 gate.

### Not wired yet either: the Actions runner

A freshly created instance has **no Forgejo Actions runner**, so every workflow queues forever and
nothing in CI runs. The API has `POST`/`GET`/`DELETE`
`/v1beta/projects/{projectId}/instances/{instanceId}/runner`, and the backplane's `git.admin` role
already carries `git.runner.create`; a live instance answers that `GET` with a runner labelled
`stackit-alpine`, `stackit-docker`, `stackit-ubuntu-22` and friends, which is what a workflow's
`runs-on` selects. `stackit_git` has no runner attribute, so this is another out-of-band call. See
the TODO next to the instance resource in `main.tf`.

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
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.83.0, < 1.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [restapi_object.forgejo_organization](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [stackit_git.this](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/git) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_forgejo_organization"></a> [forgejo\_organization](#input\_forgejo\_organization) | Forgejo organization to create inside the instance. Created only when `forgejo_token` is also set; leave null to provision the bare instance (phase 1 of the bootstrap, see README). | `string` | `null` | no |
| <a name="input_forgejo_token"></a> [forgejo\_token](#input\_forgejo\_token) | Personal Access Token of a bot account in this Forgejo instance, with `write:organization` scope. Leave null on the first run: the instance has to exist before a token can be minted in it. | `string` | `null` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name of the STACKIT Git instance. It becomes the first label of the instance hostname `<name>.git.onstackit.cloud`, so it is globally unique across all of STACKIT — derive it from something already unique, e.g. a platform identifier carrying a random suffix. | `string` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project the Git instance is created in — the platform-native tenant id of the tenant this building block is added to. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the Git instance is placed in. | `string` | `"eu01"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_forgejo_organization"></a> [forgejo\_organization](#output\_forgejo\_organization) | Name of the Forgejo organization created in the instance, or null while no token has been supplied. |
| <a name="output_forgejo_token_provided"></a> [forgejo\_token\_provided](#output\_forgejo\_token\_provided) | Whether a Forgejo Personal Access Token is available, i.e. whether this instance is past the token bootstrap step. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | STACKIT Git instance id. |
| <a name="output_instance_name"></a> [instance\_name](#output\_instance\_name) | Name of the STACKIT Git instance. |
| <a name="output_instance_url"></a> [instance\_url](#output\_instance\_url) | URL of the Forgejo instance. Sign in here to create the bot account and mint the Personal Access Token the second run needs. |
<!-- END_TF_DOCS -->
