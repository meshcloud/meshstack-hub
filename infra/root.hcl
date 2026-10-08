# Terragrunt root for the hub's own infrastructure. Its one job is the backend: every unit keeps its
# state in the shared meshcloud bucket, under a prefix named after the unit's folder.

remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.generated.tf"
    if_exists = "overwrite"
  }

  config = {
    bucket = "meshcloud-tf-states"
    prefix = "meshstack-hub/infra/${path_relative_to_include()}"
  }
}
