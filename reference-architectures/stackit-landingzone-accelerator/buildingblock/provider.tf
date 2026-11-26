# The accelerator's own provider blocks carry no credentials either, so every STACKIT provider of
# the run authenticates with STACKIT_SERVICE_ACCOUNT_KEY from the environment.
provider "stackit" {
  experiments = ["iam"]
}
