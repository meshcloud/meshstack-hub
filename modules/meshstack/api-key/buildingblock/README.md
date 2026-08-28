---
name: meshStack API Key
supportedPlatforms:
  - meshstack
description: Issues a workspace-scoped meshStack API key with a chosen set of permissions and an optional expiry.
# No cloud-side setup: the run authenticates with its own ephemeral, workspace-scoped meshStack token.
requiresBackplane: false
---
# meshStack API Key Building Block

Creates a `meshstack_api_key` owned by a workspace, granting a selectable subset of workspace
permissions and an optional expiry date. The generated client ID and client secret are returned as
outputs so automation (CI pipelines, scripts, integrations) can authenticate against the meshStack
API.

The building block run authenticates with the ephemeral, workspace-scoped token meshStack injects
for the run — no admin credentials are stored. The token carries exactly the permissions declared in
the building block definition (`APIKEY_SAVE` plus the grantable permission catalog), so any subset a
user selects can be minted, but nothing beyond what the platform team allows.

## Inputs

| Input | Type | Description |
|-------|------|-------------|
| `owned_by_workspace` | `STRING` | Workspace that owns the key. |
| `display_name` | `STRING` | Human-readable name of the key. |
| `permissions` | `MULTI_SELECT` | Subset of the grantable permissions to assign. |
| `expires_at` | `STRING` | Optional ISO expiry date; empty means the key never expires. |

## Outputs

| Output | Description |
|--------|-------------|
| `client_id` | Client ID used to authenticate. |
| `client_secret` | Client secret (sensitive). |
| `uuid` | Server-generated UUID of the key. |
