data "external" "env" {
  program = ["python3", "-c", <<-PY
  import json
  import os

  print(json.dumps(dict(os.environ)))
  PY
  ]
}
