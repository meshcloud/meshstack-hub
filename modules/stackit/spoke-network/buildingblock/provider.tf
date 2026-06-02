provider "stackit" {
  service_account_key   = var.service_account_key_json
  enable_beta_resources = true
  experiments           = ["routing-tables", "network"]
}
