# STACKIT SKE Cluster — Backplane

Provisions the automation identity the SKE Cluster building block runs as, using **Workload Identity
Federation** (no long-lived key).

It creates:

- a **STACKIT service account** in an existing project (`project_id` — e.g. a foundation project),
- a **federated identity provider** trusting the meshStack building block's OIDC subject, and
- **organization-level role assignments** (`roles`, default `ske.admin`).

The roles are granted on the **organization** on purpose: the SKE cluster's own project is provisioned
at order time and does not exist when this backplane runs, so the grant must inherit down to it. Adjust
`roles` to the exact STACKIT role names your organization uses for SKE management.

## Permissions required to apply

Whoever applies this backplane needs to create a service account in `project_id` and assign
organization-level roles (organization owner / `resource-manager.admin` + `iam.member-admin`).
