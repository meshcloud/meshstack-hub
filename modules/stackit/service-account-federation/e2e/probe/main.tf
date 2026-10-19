# Runs as the federated service account: a run that cannot sign in through WIF fails to read the
# project, so a non-empty name proves the federation works.
variable "project_id" {
  type     = string
  nullable = false
}

data "stackit_resourcemanager_project" "this" {
  project_id = var.project_id
}

output "project_name" {
  value = data.stackit_resourcemanager_project.this.name
}
