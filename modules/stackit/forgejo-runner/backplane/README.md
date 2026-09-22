# STACKIT Forgejo Runner — Backplane

Provisions the automation identity the Forgejo Runner building block runs as: a STACKIT service
account with a Workload Identity Federation provider trusting the meshStack building block runtime.

## What it provisions

- A `stackit_service_account` in the target project.
- A `stackit_service_account_federated_identity_provider` per WIF subject, so meshStack can exchange
  its short-lived OIDC token for a STACKIT access token at building block run time — no static key.
- A project-scoped `editor` role assignment, the narrowest built-in role carrying IaaS write
  (server, network, network interface, public IP, key pair).

## Operational notes

- The grant is **project-scoped**: the runner always lives in a project the platform team knows when
  deploying this backplane.
- Compute (IaaS) is enabled by default on STACKIT projects, so no service-enablement role is granted.
- The Forgejo PAT the building block uses to mint runner registration tokens is **not** created here.
  It is a Forgejo credential supplied to the building block as a static input by the platform team
  (org-admin scope on the target organization).
