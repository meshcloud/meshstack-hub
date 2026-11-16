---
name: meshStack Temporary Group Access
supportedPlatforms:
  - meshstack
description: Grants a meshStack group a role on a workspace for a limited number of days, then deletes itself.
---

# meshStack Temporary Group Access

This building block binds one meshStack group, chosen by the platform team, to the workspace it is
ordered in, with a workspace role and for a number of days the orderer chooses. Typical uses are a
support or audit team that needs access to a workspace for a limited time.

## How the access ends

Two mechanisms end the access, so it never depends on one of them alone:

- The binding carries meshStack's own `expiry_date`, so meshStack stops honouring it after that
  date.
- The [backplane](../backplane/README.md) runs a sweeper once a day. It deletes every building block
  of this definition whose `expires_at` output lies in the past, and the destroy run of the deleted
  block removes the binding.

## Permissions

The run uses the ephemeral token meshStack hands it, with the `WORKSPACEPRINCIPALBINDING_*`
permissions the definition declares. It needs no API key of its own. Only the sweeper does.

## Roles with recertification or approval

- If recertification is enabled for the role, meshStack rejects an expiry date beyond its
  recertification maximum. Keep `max_duration_days` within it.
- If the role needs four-eyes approval, the binding stays `PENDING` until someone approves it in
  meshPanel, and the duration counts from the first run regardless.
<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
