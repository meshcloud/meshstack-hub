data "external" "env" {
  program = ["python3", "-c", <<-PY
import json
import os

print(json.dumps(dict(os.environ)))
PY
  ]
}

provider "stackit" {
  default_region      = "eu01"
  service_account_key = data.external.env.result["STACKIT_SERVICE_ACCOUNT_KEY"]
}
