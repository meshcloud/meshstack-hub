# T Cloud Public CCE – Backplane

Lets the CCE building block sign in through workload identity federation instead of an
access key, with [`otc/workload-identity`](../../workload-identity): an identity provider that trusts
only this definition's runs, and an IAM group holding what the building block needs:

- read access to IAM on the domain;
- on all projects, by IAM name: CCE FullAccess (`system_all_27`), ECS FullAccess (`system_all_51`)
  for the nodes and key pair, and VPC Administrator (`vpc_netadm`) for the API server's elastic IP.

It also creates the `cce_admin_trust` agency CCE acts through, delegated to CCE's service account
with Tenant Administrator in the region, unless `create_cce_admin_trust` is false. The CCE console
would otherwise create it on a user's first visit; the agency is one per domain.

Apply it with credentials holding Security Administrator, with the provider targeting the region's
own project (`tenant_name = "eu-de"`).
