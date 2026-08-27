data "external" "prerun_env_keys" {
  program = ["bash", "-c", "jq -Rcn '[inputs] | {keys: tojson}' prerun_env_keys.txt"]
}

data "external" "apply_env_keys" {
  program = ["bash", "-c", "compgen -e | sort | jq -Rcn '[inputs] | {keys: tojson}'"]
}
