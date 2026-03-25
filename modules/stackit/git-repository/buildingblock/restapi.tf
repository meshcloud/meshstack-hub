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

# The restapi provider's write_returns_object flag must be set at the provider
# level, so we need two aliases to handle the different Forgejo API behaviors:
#
# with_returned_object (write_returns_object = true)
#   Use for Forgejo endpoints whose POST/PUT returns a JSON response body,
#   e.g. POST /orgs/{org}/teams, PUT /repos/{owner}/{repo}/actions/variables/{name}
#
# without_returned_object (write_returns_object = false)
#   Use for Forgejo endpoints whose PUT/DELETE returns 204 No Content,
#   e.g. PUT /teams/{id}/repos/{owner}/{repo}, PUT /teams/{id}/members/{username},
#        PUT /repos/{owner}/{repo}/actions/secrets/{name}

provider "restapi" {
  alias                = "with_returned_object"
  uri                  = data.external.env.result["FORGEJO_HOST"]
  headers              = local.restapi_provider_headers
  write_returns_object = true
}

provider "restapi" {
  alias                = "without_returned_object"
  uri                  = data.external.env.result["FORGEJO_HOST"]
  headers              = local.restapi_provider_headers
  write_returns_object = false
}
