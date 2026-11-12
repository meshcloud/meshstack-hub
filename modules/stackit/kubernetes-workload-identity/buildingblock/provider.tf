provider "stackit" {
  default_region = "eu01"
  experiments    = ["iam"]
  # Authentication comes entirely from the environment: STACKIT_SERVICE_ACCOUNT_EMAIL,
  # STACKIT_USE_OIDC and STACKIT_FEDERATED_TOKEN_FILE are injected by meshStack.
}
