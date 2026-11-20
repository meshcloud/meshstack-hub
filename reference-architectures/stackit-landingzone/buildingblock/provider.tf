# Contract mode manages no STACKIT resource, but the provider fails to configure without credentials. A
# placeholder WIF token satisfies it, and no call ever presents it.
provider "stackit" {
  experiments         = ["iam"]
  service_account_key = var.stackit_service_account_key

  use_oidc                        = var.platform_contract_mode
  service_account_email           = var.platform_contract_mode ? var.backplane_service_account_email : null
  service_account_federated_token = var.platform_contract_mode ? "unused" : null
}
