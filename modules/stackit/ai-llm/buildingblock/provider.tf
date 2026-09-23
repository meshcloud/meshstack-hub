provider "stackit" {
  default_region        = var.stackit_region
  enable_beta_resources = true
}

# The STACKIT provider ships no service enablement resource, so that call goes through the REST API
# and needs a bearer token of its own. The provider mints one from WIF but exposes no way to read it
# back, so stackit-access-token.sh repeats the exchange.
provider "restapi" {
  alias = "service_enablement"

  uri                  = "https://service-enablement.api.stackit.cloud"
  write_returns_object = false

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
