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

# write_returns_object is provider-level, so there is one alias for endpoints that return a body and one for 204 No Content.
provider "restapi" {
  alias                = "with_returned_object"
  uri                  = data.external.env.result["FORGEJO_HOST"]
  headers              = local.restapi_provider_headers
  write_returns_object = true

  # Forgejo sometimes answers 5xx under concurrent load.
  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}

provider "restapi" {
  alias                = "without_returned_object"
  uri                  = data.external.env.result["FORGEJO_HOST"]
  headers              = local.restapi_provider_headers
  write_returns_object = false

  retries {
    max_retries = 5
    min_wait    = 1
    max_wait    = 10
  }
}
