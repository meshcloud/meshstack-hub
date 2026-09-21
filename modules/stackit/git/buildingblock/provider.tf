# Authentication comes entirely from the environment via Workload Identity Federation:
# STACKIT_SERVICE_ACCOUNT_EMAIL, STACKIT_USE_OIDC and STACKIT_FEDERATED_TOKEN_FILE are injected by
# meshStack and exchanged for a token at runtime. The backplane provisions the federated identity.
provider "stackit" {
  default_region = var.stackit_region

  # `stackit_git` is a beta resource; without this the provider refuses to plan it.
  enable_beta_resources = true
}

# Talks to the Forgejo API of the instance created above. The token is a Personal Access Token
# minted by hand on a bot account — see variables.tf.
provider "restapi" {
  uri                  = local.forgejo_base_url
  write_returns_object = true

  headers = {
    Authorization = "token ${local.forgejo_token_header}"
    Content-Type  = "application/json"
  }
}
