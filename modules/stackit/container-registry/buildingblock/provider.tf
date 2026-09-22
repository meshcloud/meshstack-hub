# Authentication comes entirely from the environment via Workload Identity Federation:
# STACKIT_SERVICE_ACCOUNT_EMAIL, STACKIT_USE_OIDC and STACKIT_FEDERATED_TOKEN_FILE are injected by
# meshStack and exchanged for a token at runtime. The backplane provisions the federated identity.
provider "stackit" {
  default_region = var.stackit_region
}

# The STACKIT provider ships no container registry resource, so both calls go through the REST API
# and need a bearer token of their own. The provider mints one from WIF but exposes no way to read
# it back, so stackit-access-token.sh repeats the exchange.
provider "restapi" {
  alias = "service_enablement"

  uri                  = "https://service-enablement.api.stackit.cloud"
  write_returns_object = false

  headers = {
    Authorization = "Bearer ${local.stackit_access_token}"
    Content-Type  = "application/json"
  }
}

provider "restapi" {
  alias = "registry"

  uri                  = "https://registry.api.stackit.cloud"
  write_returns_object = false

  headers = {
    Authorization = "Bearer ${local.stackit_access_token}"
    Content-Type  = "application/json"
  }
}
