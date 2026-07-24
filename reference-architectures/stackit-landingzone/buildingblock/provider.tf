provider "stackit" {
  experiments         = ["iam"] # Required for authorization resources
  service_account_key = var.stackit_service_account_key
}
