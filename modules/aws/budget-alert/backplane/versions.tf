terraform {
  # lifecycle.enabled, which selects between the two ways the target role reaches its account.
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0.0"

      configuration_aliases = [
        # The AWS Organizations management account, or the delegated admin that may deploy StackSets
        # over the organization. Unused by a single-account deployment, which still has to configure
        # it — point it at the backplane account there.
        aws.management
      ]
    }
  }
}
