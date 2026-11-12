# The admin kubeconfig only creates the deployer identity of the Kubernetes Service Account
# definition, which gets the deployer's kubeconfig instead.
provider "kubernetes" {
  config_path = local.kubeconfig_path
}

provider "stackit" {
  default_region = "eu01"
  experiments    = ["iam"]

  service_account_key = var.stackit_enabled ? var.stackit_service_account_key : null

  # OpenTofu configures the provider even when STACKIT is off and nothing uses it. These placeholders
  # pass that, because the provider only exchanges the token on its first API call.
  use_oidc                        = var.stackit_enabled ? null : true
  service_account_email           = var.stackit_enabled ? null : "unused@sa.stackit.cloud"
  service_account_federated_token = var.stackit_enabled ? null : "unused"
}
