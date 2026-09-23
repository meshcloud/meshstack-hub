provider "stackit" {
  default_region = var.stackit_region

  # `stackit_git` is a beta resource; without this the provider refuses to plan it.
  enable_beta_resources = true
}

# Talks to the Forgejo API of the instance created above, as the technical user, over HTTP Basic
# auth. Basic auth rather than the token this module mints, for two reasons: minting the token needs
# it (Forgejo refuses to mint a token for a caller holding a token), and the `restapi` provider
# cannot take an unknown value in its `headers` map, which is what a token minted in the same apply
# still is at plan time. Username and password are plain string attributes, which do accept one.
provider "restapi" {
  uri                  = local.forgejo_base_url
  username             = var.local_user_username
  password             = random_password.local_user.result
  write_returns_object = true

  headers = {
    Content-Type = "application/json"
  }

  # A single TCP reset from the STACKIT API failed whole runs: without this the provider makes one
  # attempt and gives up.
  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}

# The STACKIT Git API, which is where the technical user is created. The provider mints a token from
# Workload Identity Federation but exposes no way to read it back, so stackit-access-token.sh
# repeats the exchange.
provider "restapi" {
  alias = "stackit_git"

  uri                   = "https://git.api.stackit.cloud"
  create_returns_object = true
  write_returns_object  = false

  headers = {
    Authorization = "Bearer ${local.stackit_access_token}"
    Content-Type  = "application/json"
  }

  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}
