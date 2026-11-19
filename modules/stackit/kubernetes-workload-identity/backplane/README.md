# STACKIT Kubernetes Workload Identity Backplane

Sets up the two STACKIT identities of the STACKIT Kubernetes Workload Identity building block. Neither
has a key.

## What it provisions

- **Workload service account** (`service_account_name`) with `organization_roles` on the organization
  and `project_roles` on `project_id`. Kubernetes workloads act as it: each building block federates
  it with the token of one Kubernetes service account.
- **Building block service account** (`<service_account_name>-bb`) that the building block runs act as
  through workload identity federation with the meshStack runner. It holds `editor` on the workload
  service account only, which carries the permissions to add and remove that account's federations
  and nothing in the rest of the project.

## Running it

The caller configures the `stackit` provider with the `iam` experiment and an identity that may
create service accounts in `project_id` and assign the requested roles, for example an organization
owner for organization roles. Run it from `meshstack_integration.tf`, which wires the runner's
issuer, audience and subject.

Role assignments in STACKIT take effect asynchronously, so the first building block run right after
the backplane may still see a 403 and needs a retry.
