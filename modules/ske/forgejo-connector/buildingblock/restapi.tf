data "external" "env" {
  program = ["python3", "-c", <<-PY
  import json
  import os

  print(json.dumps(dict(os.environ)))
  PY
  ]
}

locals {
  restapi_provider_headers = {
    Authorization = "token ${data.external.env.result["FORGEJO_API_TOKEN"]}"
    Content-Type  = "application/json"
  }
}

provider "restapi" {
  alias   = "with_returned_object"
  uri     = data.external.env.result["FORGEJO_HOST"]
  headers = local.restapi_provider_headers
  # Endpoints that return JSON (e.g. action variables)
  write_returns_object = true

  # Forgejo occasionally answers slowly or with 5xx; without this the provider
  # makes a single attempt and one such answer fails the whole run. Same
  # settings as stackit/git-repository, which manages the same API.
  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}

provider "restapi" {
  alias   = "without_returned_object"
  uri     = data.external.env.result["FORGEJO_HOST"]
  headers = local.restapi_provider_headers
  # Endpoints that return 204 or where response can't be read back (e.g. secrets)
  write_returns_object = false

  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}
