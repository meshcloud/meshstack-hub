---
name: AWS Alternate Contacts Backplane
supportedPlatforms:
- aws
description: |
  Backplane infrastructure for the AWS Alternate Contacts building block.
---

This module sets up the IAM user and StackSet-based role deployment needed to manage alternate contacts on AWS accounts in your organization.

It creates:

1. An **IAM User** in your backplane account with permission to assume a service role in target accounts.
2. A **CloudFormation StackSet** deployed to the specified OUs that creates a service role in each target account with the necessary `account:*AlternateContact` permissions.

## Usage

```hcl
module "alternate_contacts_backplane" {
  source = "./modules/aws/alternate-contacts/backplane"

  building_block_target_ou_ids = ["ou-xxxx-xxxxxxxx"]

  providers = {
    aws.management = aws.management
    aws.backplane  = aws.backplane
  }
}
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
