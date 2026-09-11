# Authentication comes entirely from the environment via Workload Identity Federation:
# STACKIT_SERVICE_ACCOUNT_EMAIL, STACKIT_USE_OIDC and STACKIT_FEDERATED_TOKEN_FILE are injected by
# meshStack and exchanged for a token at runtime. The backplane provisions the federated identity.
provider "stackit" {
  default_region = var.stackit_region
}
