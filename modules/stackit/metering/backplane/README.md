# STACKIT Metering Backplane

Sets up the two STACKIT identities of the STACKIT Metering building block. Neither has a key.

## What it provisions

- **Metering service account** (`mesh-metering` by default) with `cost-management.cost.reader` on the
  organization. Every metering CronJob acts as it: each building block federates it with the
  Kubernetes service account token of its own namespace.
- **Building block service account** (`mesh-metering-bb`) that the building block runs act as through
  workload identity federation with the meshStack runner. It holds `editor` on the metering service
  account only, which carries the permissions to add and remove that account's federations and
  nothing in the rest of the project.

## Running it

The caller configures the `stackit` provider with the `iam` experiment and an identity that may
create service accounts in `project_id` and assign roles on the organization, for example an
organization owner. Run it from `meshstack_integration.tf`, which wires the runner's issuer, audience
and subject.

Role assignments in STACKIT take effect asynchronously, so the first building block run right after
the backplane may still see a 403 and needs a retry.
