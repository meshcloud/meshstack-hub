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

## The one manual step

STACKIT grants no IAM role that opens the Harbor API to an identity Harbor does not already know —
verified against a service account holding all five `container-registry*` roles, which still got
`401` from `POST /api/v2.0/robots`. Harbor access comes from linking a robot account to a STACKIT
service account, and only the portal can create that first link. After that, the service account's
token authenticates as the robot and further robots can be created through the Harbor API.

This module stops at creating the registry. Robot management is not implemented.
