# Authentication comes entirely from the environment: STACKIT_SERVICE_ACCOUNT_EMAIL,
# STACKIT_USE_OIDC and STACKIT_FEDERATED_TOKEN_FILE are injected by meshStack.
provider "stackit" {
  experiments = ["iam"] # Required for authorization resources
}
