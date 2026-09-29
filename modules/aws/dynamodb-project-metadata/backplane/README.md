## Overview

The backplane provisions a central DynamoDB table in your AWS management/tooling account and an
IAM role that the meshStack building block runtime can assume via workload identity federation (OIDC).
No long-lived AWS credentials are required.

## What is provisioned

| Resource | Purpose |
|---|---|
| `aws_dynamodb_table` | Stores one item per AWS account (partition key = `var.partition_key_name`, the AWS account ID) |
| `aws_iam_openid_connect_provider` | Trusts the meshStack OIDC issuer |
| `aws_iam_role` | Grants DynamoDB write access to the building block runtime |
| `aws_iam_role_policy` | Scoped to `PutItem`, `UpdateItem`, `GetItem`, `DeleteItem` on the table only (accounts are normally retired rather than deleted; `DeleteItem` is granted for cleanup) |

> **Partition key naming:** `partition_key_name` must match the building block's value byte-for-byte,
> and both must match the target table's actual partition key attribute name. If you write to a
> pre-existing, externally-provisioned table, set this to that table's exact key attribute name.

## Required permissions

The AWS principal running this backplane must be able to create IAM resources and DynamoDB tables.
Typically this is run with `AdministratorAccess` in a management/tooling account.

## Usage

```hcl
module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/aws/dynamodb-project-metadata/backplane?ref=main"

  workload_identity_federation = {
    issuer   = "<meshStack WIF issuer>"
    audience = "<meshStack WIF audience>"
    subjects = ["system:serviceaccount:<namespace>:workspace.<workspace>.buildingblockdefinition.<uuid>"]
  }

  table_name         = "meshstack-accountdetails"   # optional, defaults to this value
  partition_key_name = "AWS_ACCOUNT_ID"             # optional; use a clean key for new tables
}
```

## Outputs

| Output | Description |
|---|---|
| `table_name` | Name of the created DynamoDB table (pass to `aws_dynamodb_table_name` BBD input) |
| `workload_identity_federation_role_arn` | IAM role ARN (pass to `AWS_ROLE_ARN` BBD input) |
