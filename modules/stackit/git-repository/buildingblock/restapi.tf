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
  alias   = "action_variable"
  uri     = data.external.env.result["FORGEJO_HOST"]
  headers = local.restapi_provider_headers
  # crucial flag which must be on provider level to control different handling for secrets (see below),
  # as they can't be read back to check for state
  write_returns_object = true
}

provider "restapi" {
  alias   = "action_secret"
  uri     = data.external.env.result["FORGEJO_HOST"]
  headers = local.restapi_provider_headers
  # Secrets can't be read back, so PUT/POST don't return the object
  write_returns_object = false
}

provider "restapi" {
  alias   = "team_management"
  uri     = data.external.env.result["FORGEJO_HOST"]
  headers = local.restapi_provider_headers
  # Team-repo PUT returns 204, member POST may not return the full object
  write_returns_object = false
}
