provider "stackit" {
  service_account_email = var.service_account_email
  use_oidc              = true
  enable_beta_resources = true
  experiments           = ["routing-tables", "network"]
}
