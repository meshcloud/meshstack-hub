# T Cloud Public Network – Backplane

Lets the network building block sign in through workload identity federation instead of an
access key, with [`otc/workload-identity`](../../workload-identity): an identity provider that trusts
only this definition's runs, and an IAM group holding what the building block needs:

- read access to IAM on the domain;
- `vpc:*:*` and `nat:*:*` on all projects, for the VPC, subnet, NAT gateway and elastic IP.

Apply it with credentials holding Security Administrator, with the provider targeting the region's
own project (`tenant_name = "eu-de"`).
