---
name: AWS DynamoDB Account Metadata
supportedPlatforms:
  - aws
description: Pushes meshStack account metadata (account ID, status, tags, team members) into a central AWS DynamoDB table per AWS organization.
---

Automatically syncs meshStack account metadata into a central AWS DynamoDB table whenever a building
block is assigned to a tenant. This eliminates the need for long-lived meshStack API credentials in
your AWS organization — metadata is pushed from meshStack using workload identity federation.

Each account is stored as **one item** keyed by the AWS account ID (partition key, configurable via
`partition_key_name`, default `AWS_ACCOUNT_ID`). The item carries `mesh_accountStatus` (`active`),
the workspace/project/platform identifiers, the team members (`users`), and every meshStack tenant tag
as its **own top-level attribute** (e.g. `BusinessUnit`, `Environment`, `Flags`, `OfferingNumber`).

When the building block is removed, the item is **not** deleted — a pre-run script re-applies it with
`mesh_accountStatus = retired` and drops it from Terraform state, so the record is kept for
audit/inventory purposes.

## When to use it

Use this building block when you need meshStack project data (tags, team members, workspace/project
identifiers) available inside your AWS organization without polling the meshStack API with static
credentials. Typical use cases:

- Feeding project ownership and cost-centre tags into AWS Cost Explorer via DynamoDB.
- Driving IAM permission boundaries or SCPs with project-level metadata.
- Providing a CMDB-like inventory of all meshStack tenants in your AWS org.

## Shared Responsibility

| Responsibility | Platform Team | Application Team |
|---|:---:|:---:|
| Deploy backplane (DynamoDB table + IAM role) | ✅ | ❌ |
| Assign building block to tenants | ✅ | ❌ |
| Consume DynamoDB data in tooling/pipelines | ✅ | ❌ |
| Keep meshStack project tags up to date | ❌ | ✅ |
| Manage team membership in meshStack | ❌ | ✅ |

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_meshstack"></a> [meshstack](#requirement\_meshstack) | >= 0.22.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table_item.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [meshstack_project.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/project) | data source |
| [meshstack_tenant.this](https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/data-sources/tenant) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_status"></a> [account\_status](#input\_account\_status) | Tenant/account status written to mesh\_accountStatus. Defaults to 'active'; the pre-run script sets it to 'retired' on the destroy run (tenant deletion) so the item is kept instead of deleted. Not a meshStack input — internal plumbing only. | `string` | `"active"` | no |
| <a name="input_aws_dynamodb_table_name"></a> [aws\_dynamodb\_table\_name](#input\_aws\_dynamodb\_table\_name) | Name of the DynamoDB table to write project metadata to. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where the DynamoDB table is located. | `string` | n/a | yes |
| <a name="input_partition_key_name"></a> [partition\_key\_name](#input\_partition\_key\_name) | Name of the DynamoDB table's partition key attribute (the AWS account ID). Must match the target table's key name exactly; override if your table uses a different attribute name. | `string` | `"AWS_ACCOUNT_ID"` | no |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | meshStack platform identifier (typically the AWS account name for AWS accounts). | `string` | n/a | yes |
| <a name="input_platform_tenant_id"></a> [platform\_tenant\_id](#input\_platform\_tenant\_id) | meshStack platform tenant id (the AWS account ID). Used as mesh\_accountId, the DynamoDB partition key. | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | meshStack project identifier. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | Project team members with their roles, injected by meshStack. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | meshStack workspace identifier. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dynamodb_item_key"></a> [dynamodb\_item\_key](#output\_dynamodb\_item\_key) | mesh\_accountId (AWS account ID) — partition key of the DynamoDB item written for this account. |
| <a name="output_dynamodb_item_url"></a> [dynamodb\_item\_url](#output\_dynamodb\_item\_url) | AWS Console URL to view the specific item written for this project. |
| <a name="output_dynamodb_table_name"></a> [dynamodb\_table\_name](#output\_dynamodb\_table\_name) | Name of the DynamoDB table the metadata was written to. |
<!-- END_TF_DOCS -->
