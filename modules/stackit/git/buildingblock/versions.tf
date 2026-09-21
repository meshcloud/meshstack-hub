terraform {
  required_version = ">= 1.12.0"

  required_providers {
    stackit = {
      source = "stackitcloud/stackit"
      # 0.83 is the first release carrying the `stackit_git` resource this module needs. It is still
      # a beta resource as of 0.116.0 (September 2026), hence `enable_beta_resources` in provider.tf.
      version = ">= 0.83.0, < 1.0.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = ">= 3.0.0, < 4.0.0"
    }
  }
}
