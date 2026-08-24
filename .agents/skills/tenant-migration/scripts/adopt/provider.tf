# local-only: the real building block authenticates via WIF; here we use the org service account key
provider "stackit" {
  service_account_key = var.stackit_service_account_key
  experiments         = ["iam"]
}

variable "stackit_service_account_key" {
  type      = string
  sensitive = true
}
