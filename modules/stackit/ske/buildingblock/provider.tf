# Callers that drive this module from Terragrunt usually replace this file with a generated
# `provider.tf` of their own. In that case `service_account_email` and `stackit_region` stay
# unset and the generated block carries the credentials instead.
provider "stackit" {
  default_region        = var.stackit_region
  service_account_email = var.service_account_email
  use_oidc              = true
}
