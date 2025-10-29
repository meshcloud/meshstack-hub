---
name: AWS Bedrock LZ
summary: |
  A landing zone for using AWS Bedrock in sandboxed to access LLM models for developers.
---

# AWS Bedrock LZ

This Landing Zone restricts access to only the AWS Bedrock service and necessary supporting services. This landing zone is a "single purpose" landing zone that's easy to audit and verify. It's designed to be handed to individual developers who need to:

- Access specific AWS Bedrock LLM models
- Use LLM models via AWS Bedrock for developer tools like Aider
- Interact with AI/ML capabilities provided by AWS Bedrock
- Have control over individual token consumption via standard AWS Billing

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_organizations_organizational_unit.bedrock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_organizational_unit) | resource |
| [aws_organizations_policy.only_bedrock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy) | resource |
| [aws_organizations_policy_attachment.only_bedrock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/organizations_policy_attachment) | resource |
| [aws_iam_policy_document.only_bedrock](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_parent_ou_id"></a> [parent\_ou\_id](#input\_parent\_ou\_id) | id of the parent OU | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_organizational_unit_id"></a> [organizational\_unit\_id](#output\_organizational\_unit\_id) | The ID of the Organizational Unit created in this module. |
<!-- END_TF_DOCS -->
