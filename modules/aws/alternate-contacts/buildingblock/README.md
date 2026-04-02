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
<!-- END_TF_DOCS -->
