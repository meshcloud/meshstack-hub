# T Cloud Public RDS – Backplane

Lets the RDS building block sign in through workload identity federation instead of an
access key, with [`otc/workload-identity`](../../workload-identity): an identity provider that trusts
only this definition's runs, and an IAM group holding what the building block needs:

- read access to IAM on the domain;
- on all projects, by IAM name: RDS FullAccess (`system_all_12`), KMS Administrator (`kms_adm`),
  which RDS requires for an encrypted instance, and CES FullAccess (`system_all_61`) for the alarm
  rule;
- `vpc:*:*` on all projects for the security group, its rules and the elastic IP. VPC
  Administrator is refused deleting the rules through the Neutron API.

Apply it with credentials holding Security Administrator, with the provider targeting the region's
own project (`tenant_name = "eu-de"`).
