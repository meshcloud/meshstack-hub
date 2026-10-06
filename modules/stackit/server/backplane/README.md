# STACKIT Server Backplane

Creates the automation identity the **STACKIT Server** building block runs as. It provisions a
dedicated STACKIT service account, federates it with meshStack via Workload Identity Federation
(WIF), and grants it the `editor` role on the target project.

## What it provisions

- `stackit_service_account` — the automation principal the building block authenticates as.
- `stackit_service_account_federated_identity_provider` (one per WIF subject) — trusts the
  meshStack-issued OIDC token for the building block definition's resolved identity, so no
  long-lived key is ever created.
- `stackit_authorization_project_role_assignment` — grants the service account `editor` on
  `project_id`.

## Required permissions

The identity used to **apply this backplane** needs, on the target STACKIT project:

- rights to create and delete service accounts and their federated identity providers
  (`iam.service-account-admin` or broader), and
- rights to assign project roles (`iam.member-admin` or broader).

A project `owner` or `editor` with member-admin covers this.

## Why `editor`

`editor` is the broadest predefined STACKIT project role and the only single role that spans every
IaaS resource the building block creates — servers, networks, network interfaces, public IPs,
security groups, security group rules and key pairs. Because no narrower predefined role covers all
of these, least privilege is applied through **scope** (one project via `resource_id`) rather than
through a narrower role: a tenant-level block only ever touches the project it is ordered in.

## Outputs

- `service_account_email` — wired into the building block definition's `STACKIT_SERVICE_ACCOUNT_EMAIL`
  environment input.
- `project_id` — passed through as the building block's `stackit_project_id`.
