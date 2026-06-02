provider "stackit" {
  service_account_email = var.service_account_email
  enable_beta_resources = true
  experiments           = ["routing-tables", "network"]
}
