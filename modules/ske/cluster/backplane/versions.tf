terraform {
  required_version = ">= 1.11.0"

  required_providers {
    stackit = {
      source = "stackitcloud/stackit"
      # stackit_service_account_federated_identity_provider requires >= 0.95.0.
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
