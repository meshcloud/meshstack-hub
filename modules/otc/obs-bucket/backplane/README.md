# T Cloud Public OBS bucket – Backplane

Lets the OBS bucket building block sign in through workload identity federation instead of an
access key, with [`otc/workload-identity`](../../workload-identity): an identity provider that trusts
only this definition's runs, and an IAM group holding what the building block needs:

- Security Administrator on the domain, because the upstream module creates an IAM user, a group
  and custom roles for every bucket;
- `obs:*:*`, through the `MOS` project;
- `kms:*:*` in the region's project.

Apply it with credentials holding Security Administrator, with the provider targeting the region's
own project (`tenant_name = "eu-de"`).
