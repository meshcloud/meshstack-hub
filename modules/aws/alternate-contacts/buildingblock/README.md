---
name: AWS Alternate Contacts
supportedPlatforms:
- aws
description: |
  Sets the alternate contact information (billing, operations, security) for an AWS account.
---

This Terraform module configures the alternate contacts for an AWS account. AWS alternate contacts are used to receive notifications for billing, operations, and security-related communications, ensuring the right people are contacted for each concern.

Each contact type is optional -- set only the ones you need. AWS allows exactly one contact per type (billing, operations, security). Each contact requires a name, title, email, and phone number.

## Usage Examples

Set only a security contact:

```hcl
security_contact = {
  name  = "Jane Doe"
  title = "Security Officer"
  email = "security@example.com"
  phone = "+1-555-555-0100"
}
```

Set billing and security contacts, skip operations:

```hcl
billing_contact = {
  name  = "Carlos Salazar"
  title = "CFO"
  email = "billing@example.com"
  phone = "+1-555-555-0199"
}

security_contact = {
  name  = "Jane Doe"
  title = "Security Officer"
  email = "security@example.com"
  phone = "+1-555-555-0100"
}
```

## Permissions

Please reference the [backplane implementation](../backplane/) for the required permissions to deploy this building block.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_account_alternate_contact.billing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |
| [aws_account_alternate_contact.operations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |
| [aws_account_alternate_contact.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/account_alternate_contact) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_id"></a> [account\_id](#input\_account\_id) | Target account id where the alternate contacts should be set | `string` | n/a | yes |
| <a name="input_assume_role_name"></a> [assume\_role\_name](#input\_assume\_role\_name) | The name of the role to assume in target account identified by account\_id | `string` | n/a | yes |
| <a name="input_aws_partition"></a> [aws\_partition](#input\_aws\_partition) | The AWS partition to use. e.g. aws, aws-cn, aws-us-gov | `string` | `"aws"` | no |
| <a name="input_billing_contact"></a> [billing\_contact](#input\_billing\_contact) | Billing alternate contact. Set to null to skip. All fields are required when set. | <pre>object({<br/>    name  = string<br/>    title = string<br/>    email = string<br/>    phone = string<br/>  })</pre> | `null` | no |
| <a name="input_operations_contact"></a> [operations\_contact](#input\_operations\_contact) | Operations alternate contact. Set to null to skip. All fields are required when set. | <pre>object({<br/>    name  = string<br/>    title = string<br/>    email = string<br/>    phone = string<br/>  })</pre> | `null` | no |
| <a name="input_security_contact"></a> [security\_contact](#input\_security\_contact) | Security alternate contact. Set to null to skip. All fields are required when set. | <pre>object({<br/>    name  = string<br/>    title = string<br/>    email = string<br/>    phone = string<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_operations_contacts"></a> [operations\_contacts](#output\_operations\_contacts) | Map of configured alternate contact types to their email addresses |
<!-- END_TF_DOCS -->
