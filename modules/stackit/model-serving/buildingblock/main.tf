resource "stackit_modelserving_token" "this" {
  project_id   = var.project_id
  region       = var.region
  name         = var.token_name
  description  = var.token_description
  ttl_duration = var.ttl_duration
}
