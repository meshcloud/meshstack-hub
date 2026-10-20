# T Cloud Public CCE – Backplane

Lets the CCE building block sign in through workload identity federation instead of an
access key, with [`otc/workload-identity`](../../workload-identity): an identity provider that trusts
only this definition's runs, and an IAM group holding what the building block needs:

- read access to IAM on the domain;
- `cce:*:*`, `ecs:*:*`, `evs:*:*`, `ims:*:*`, `vpc:*:*`, `elb:*:*` and `kms:*:*` on all projects,
  for the cluster, its nodes and add-ons, and the servers, disks, key pair, KMS key and elastic IP
  behind them.

Apply it with credentials holding Security Administrator, with the provider targeting the region's
own project (`tenant_name = "eu-de"`).
