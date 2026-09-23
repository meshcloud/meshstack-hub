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

So this block asks only for the robot's **name**, never its password: the name is how an operator
says the link exists, which nothing in the API reports.

The linked robot needs only **robot account management**. It cannot read the project or its
repositories — `GET /api/v2.0/projects/{id}` answers `403` — and does not need to, because minting
the push and pull robots is a `POST /api/v2.0/robots`.

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

The copy pushes as the push robot, so it starts only once the bootstrap robot is set. An image is
copied again when its reference or the registry name changes. Removing an image from the list leaves
it in the registry. The default is an empty list, which mirrors nothing.
