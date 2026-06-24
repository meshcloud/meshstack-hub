## Overview

The backplane provisions a central DynamoDB table in your AWS management/tooling account and an
IAM role that the meshStack building block runtime can assume via workload identity federation (OIDC).
No long-lived AWS credentials are required.

## What is provisioned

| Resource | Purpose |
|---|---|
| `aws_dynamodb_table` | Stores one item per meshStack project tenant (PK: workspace, SK: project) |
| `aws_iam_openid_connect_provider` | Trusts the meshStack OIDC issuer |
| `aws_iam_role` | Grants DynamoDB write access to the building block runtime |
| `aws_iam_role_policy` | Scoped to `PutItem`, `UpdateItem`, `DeleteItem` on the table only |

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

  table_name = "meshstack-project-metadata"   # optional, defaults to this value
}
```

## Outputs

| Output | Description |
|---|---|
| `table_name` | Name of the created DynamoDB table (pass to `aws_dynamodb_table_name` BBD input) |
| `workload_identity_federation_role_arn` | IAM role ARN (pass to `AWS_ROLE_ARN` BBD input) |
