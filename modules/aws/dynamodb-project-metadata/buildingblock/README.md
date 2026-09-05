---
name: AWS DynamoDB Project Metadata
supportedPlatforms:
  - aws
description: Pushes meshStack project metadata (workspace, project, tags, team members) into a central AWS DynamoDB table per AWS organization.
---

Automatically syncs meshStack project metadata into a central AWS DynamoDB table whenever a building
block is assigned to a tenant. This eliminates the need for long-lived meshStack API credentials in
your AWS organization — metadata is pushed from meshStack using workload identity federation.

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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_dynamodb_table_name"></a> [aws\_dynamodb\_table\_name](#input\_aws\_dynamodb\_table\_name) | Name of the DynamoDB table to write project metadata to. | `string` | n/a | yes |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region where the DynamoDB table is located. | `string` | n/a | yes |
| <a name="input_platform_identifier"></a> [platform\_identifier](#input\_platform\_identifier) | meshStack platform identifier (typically the AWS account ID for AWS tenants). | `string` | n/a | yes |
| <a name="input_project_identifier"></a> [project\_identifier](#input\_project\_identifier) | meshStack project identifier. | `string` | n/a | yes |
| <a name="input_users"></a> [users](#input\_users) | Project team members with their roles, injected by meshStack. | <pre>list(object({<br/>    meshIdentifier = string<br/>    username       = string<br/>    firstName      = string<br/>    lastName       = string<br/>    email          = string<br/>    euid           = string<br/>    roles          = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_workspace_identifier"></a> [workspace\_identifier](#input\_workspace\_identifier) | meshStack workspace identifier. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dynamodb_item_key"></a> [dynamodb\_item\_key](#output\_dynamodb\_item\_key) | Composite key of the DynamoDB item written for this project (workspace/project). |
| <a name="output_dynamodb_item_url"></a> [dynamodb\_item\_url](#output\_dynamodb\_item\_url) | AWS Console URL to view the specific item written for this project. |
| <a name="output_dynamodb_table_name"></a> [dynamodb\_table\_name](#output\_dynamodb\_table\_name) | Name of the DynamoDB table the metadata was written to. |
<!-- END_TF_DOCS -->
