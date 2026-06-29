provider "stackit" {
  service_account_email = var.service_account_email
  use_oidc              = true
  experiments           = ["iam"] # Required for authorization resources
}
