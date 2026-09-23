provider "stackit" {
  default_region = var.stackit_region
  experiments    = ["iam"]
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

  # A single TCP reset from the STACKIT API failed whole runs: without this the provider makes one
  # attempt and gives up. Same settings as the Harbor provider next to it.
  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}

provider "restapi" {
  alias = "registry"

  uri = "https://registry.api.stackit.cloud"
  # The 202 from creating an artifactory carries the created object, including the uuid every later
  # call addresses it by. Only the create does, so this is `create_returns_object` rather than
  # `write_returns_object`.
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
