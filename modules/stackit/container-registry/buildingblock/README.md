---
name: STACKIT Container Registry
supportedPlatforms:
  - stackit
description: Provisions a STACKIT container registry (Harbor) in a project, so application images have somewhere to live.
---

# STACKIT Container Registry — Building Block

Enables `cloud.stackit.container-registry` on the tenant's STACKIT project and creates a registry
(an "artifactory" in STACKIT's API) inside it.

## Why this talks to the REST API

STACKIT ships no container registry resource in its Terraform provider — the request
(`stackitcloud/terraform-provider-stackit#1402`) was closed with nothing shipped, and the 0.116.0
schema carries none. Both calls therefore go through the `Mastercard/restapi` provider:

| Step | Call |
|---|---|
| Enable the service | `POST https://service-enablement.api.stackit.cloud/v2/projects/{p}/regions/{r}/services/cloud.stackit.container-registry` |
| Create the registry | `POST https://registry.api.stackit.cloud/v1/projects/{p}/regions/{r}/artifactories` `{"name": ...}` |
| Read back its Harbor project id | `GET https://registry.api.stackit.cloud/v1/projects/{p}/regions/{r}/artifactories/{id}` |

The read exists because Harbor addresses a project by a numeric id and the create response carries a
placeholder `0`. `read-artifactory.sh` polls until the artifactory is `Active` and reports a real id,
which is what turns the `registry_url` output into a link that opens the project.

`cloud.stackit.container-registry` is DISABLED by default on a fresh project, unlike
`cloud.stackit.git`, which is why the first call exists at all.

## Where the bearer token comes from

The STACKIT provider mints a token from Workload Identity Federation but exposes no way to read it
back — there is no token data source. `stackit-access-token.sh` therefore repeats the exchange and
returns the token through an `external` data source. It mirrors `WorkloadIdentityFederationFlow` in
`stackit-sdk-go`: a form POST to `https://accounts.stackit.cloud/oauth/v2/token` with
`grant_type=client_credentials`, the injected federated token as `client_assertion`, and the
service account email as `client_id`.

Only the WIF route is supported. The script needs `bash`, `curl` and `jq` in the runner image.

## How users reach the registry

Harbor's own member list is never touched. A `container-registry.artifactory.*` role on the **STACKIT
project** is what makes the Harbor project visible to a user, and STACKIT creates their Harbor
account on first sign-in. The module maps meshStack project roles onto those STACKIT roles:

| meshStack role | STACKIT role | Harbor role |
|---|---|---|
| `admin` | `container-registry.artifactory.admin` | Project Admin |
| `user` | `container-registry.artifactory.developer` | Developer |
| `reader` | `container-registry.artifactory.guest` | Guest |

`container-registry.artifactory.maintainer` and `.limited-guest` also exist and can be used through
`role_mapping`.

This was verified live: a user who saw no project in Harbor saw it as soon as
`container-registry.artifactory.admin` was granted on the STACKIT project. Organization-level admin
rights alone do **not** make the project visible.

## The one manual step

STACKIT grants no IAM role that opens the Harbor API to an identity Harbor does not already know —
verified against a service account holding all five `container-registry*` roles, which still got
`401` from `POST /api/v2.0/robots`. Harbor access comes from linking a robot account to a STACKIT
service account, and only the Harbor UI can create that first link.

Once linked, the credential is the **service account email as the basic-auth user and its STACKIT
access token as the password**. Harbor resolves that pair to the linked robot and names it back in a
`403` body. Three things that look like they should work do not, all verified live against a linked
robot: the robot's own secret (a request carrying it is answered exactly as an unauthenticated one),
a bearer header holding the same access token, and the robot name as the basic-auth user.

No API reports the link, so every run probes for it while planning. `read-harbor-link.sh` finds the
registry by its base name through `GET /v1/projects/{p}/regions/{r}/artifactories` — the suffixed
name is not known yet on the first plan — and asks Harbor for its project with the service account
pair:

| Harbor answers | Meaning |
|---|---|
| `401` | No robot is linked. The run mints no robots, and the summary says how to link one. With `require_robot_link` set, the run fails instead. |
| `200` or `403` | A robot is linked. The run mints the push and pull robots. |
| anything else | The run fails, rather than reading an outage as "not linked". |

After linking a robot, run the building block again with a manual trigger, or set
`require_robot_link`, which starts a run because an input changes. The script fetches the access token itself and returns only `{"linked": "true"|"false"}`, because an
`external` data source's query and result are stored in state.

The linked robot needs only **robot account management**. It cannot read the project or its
repositories — `GET /api/v2.0/projects/{id}` answers `403` — and does not need to, because minting
the push and pull robots is a `POST /api/v2.0/robots`.

With `output_to_vault` set, the robots are written to the Vault KV v2 secret
`<path_prefix>stackit/container-registry`. The key `pull-kubernetes-secret` holds the pull robot as
the data of a `kubernetes.io/dockerconfigjson` Secret, `{".dockerconfigjson"}`. The key
`push-action-secrets` holds the push robot as the CI secrets `HARBOR_REGISTRY`, `HARBOR_USERNAME`
and `HARBOR_PASSWORD`. Both are JSON objects inside the secret, so read them from `data_json`. They
are no building block output, because meshStack shows outputs in the clear.

## Mirrored base images

`mirrored_base_images` lists fully qualified upstream images, for example
`docker.io/library/python:3.12.9-slim-bookworm`. The block copies each one into the registry under
its last path segment, so that example lands at `<registry_host>/<registry_name>/python:3.12.9-slim-bookworm`.
Only the `linux/amd64` image is copied, because SKE nodes run on that architecture.

No Terraform provider copies images between registries with enough trust behind it, so the copy is
`crane copy` from [`google/go-containerregistry`](https://github.com/google/go-containerregistry).
`prerun.sh`, the definition's pre-run script, downloads a pinned `crane` release into `.crane/` and
checks it against a pinned SHA-256 before anything runs it. To update `crane`, change the version and
the checksum together, and take the checksum from the release's `checksums.txt`.

The copy pushes as the push robot, so it starts only once a robot is linked. An image is
copied again when its reference or the registry name changes. Removing an image from the list leaves
it in the registry. The default is an empty list, which mirrors nothing.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_external"></a> [external](#requirement\_external) | >= 2.3.0, < 3.0.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.5.0, < 4.0.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | >= 3.0.0, < 4.0.0 |
| <a name="requirement_stackit"></a> [stackit](#requirement\_stackit) | >= 0.98.0, < 1.0.0 |
| <a name="requirement_vault"></a> [vault](#requirement\_vault) | >= 5.12.0, < 6.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [random_string.name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [restapi_object.artifactory](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.pull_robot](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.push_robot](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [restapi_object.service_enablement](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs/resources/object) | resource |
| [stackit_authorization_project_role_assignment.registry_users](https://registry.terraform.io/providers/stackitcloud/stackit/latest/docs/resources/authorization_project_role_assignment) | resource |
| [terraform_data.mirrored_base_images](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.service_enabled](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [vault_kv_secret_v2.this](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/resources/kv_secret_v2) | resource |
| [external_external.artifactory](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.harbor_link](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |
| [external_external.stackit_access_token](https://registry.terraform.io/providers/hashicorp/external/latest/docs/data-sources/external) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_mirrored_base_images"></a> [mirrored\_base\_images](#input\_mirrored\_base\_images) | Fully qualified upstream images to mirror into the registry as `<registry>/<name>:<tag>`. | `list(string)` | n/a | yes |
| <a name="input_output_to_vault"></a> [output\_to\_vault](#input\_output\_to\_vault) | Vault KV v2 login this building block writes its secret with once the robots exist: the server `address`, the engine `mount`, a userpass `username` and `password`, and an optional `path_prefix`. The secret is `<path_prefix>stackit/container-registry`, with the keys `pull-kubernetes-secret` (`{".dockerconfigjson"}`) and `push-action-secrets` (`{HARBOR_REGISTRY, HARBOR_USERNAME, HARBOR_PASSWORD}`). Null writes none. | <pre>object({<br/>    address     = string<br/>    mount       = string<br/>    username    = string<br/>    password    = string<br/>    path_prefix = optional(string, "")<br/>  })</pre> | `null` | no |
| <a name="input_registry_name"></a> [registry\_name](#input\_registry\_name) | Base name of the registry, to which a random suffix is appended. | `string` | n/a | yes |
| <a name="input_require_robot_link"></a> [require\_robot\_link](#input\_require\_robot\_link) | Fail the run while no robot is linked to the service account, instead of minting no robots. | `bool` | `false` | no |
| <a name="input_role_mapping"></a> [role\_mapping](#input\_role\_mapping) | Maps meshStack project roles to STACKIT container registry roles. Unknown roles are ignored. | `map(list(string))` | n/a | yes |
| <a name="input_stackit_project_id"></a> [stackit\_project\_id](#input\_stackit\_project\_id) | STACKIT project the registry is created in. | `string` | n/a | yes |
| <a name="input_stackit_region"></a> [stackit\_region](#input\_stackit\_region) | STACKIT region the registry is placed in. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | Project users from meshStack, onboarded into the registry through `role_mapping`. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_registry_host"></a> [registry\_host](#output\_registry\_host) | Host applications pull images from and `docker login` targets. |
| <a name="output_registry_name"></a> [registry\_name](#output\_registry\_name) | Name of the STACKIT container registry created in the project. |
| <a name="output_registry_robot_url"></a> [registry\_robot\_url](#output\_registry\_robot\_url) | Robot Accounts tab of the Harbor project, where the robot linked to the service account is created. |
| <a name="output_registry_url"></a> [registry\_url](#output\_registry\_url) | URL of the registry in the STACKIT Harbor instance. |
| <a name="output_summary"></a> [summary](#output\_summary) | Summary of the created registry and, until a robot is linked, the one manual step it still needs. |
| <a name="output_vault_secret"></a> [vault\_secret](#output\_vault\_secret) | `{path, secret_hash}` of the secret written to `output_to_vault`, or `{}` when that is not set or no robots exist yet. `secret_hash` is the secret's KV version and changes with its content. |
<!-- END_TF_DOCS -->