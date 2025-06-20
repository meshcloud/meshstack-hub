terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.77.0"

      configuration_aliases = [
        # This provider needs to point at the account owning your AWS Organization (organization master account)
        # or the delegated admin account that can deploy StackSets over your AWS Organization.
        aws.management,

        # This provider needs to point at the account that will host the IAM User for the building block backplane (also called automation account).
        # Typically this is a dedicated account only used for building block automation.
        aws.backplane
      ]
    }
  }
}