# Authentication comes entirely from the environment: STACKIT_SERVICE_ACCOUNT_EMAIL, STACKIT_USE_OIDC
# and STACKIT_FEDERATED_TOKEN_FILE are injected by meshStack — see
# .agents/references/stackit-backplane.md. Only non-auth arguments belong here.
provider "stackit" {
  default_region        = var.stackit_region
  enable_beta_resources = true
}
