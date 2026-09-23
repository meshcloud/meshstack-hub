resource "stackit_secretsmanager_instance" "this" {
  project_id = var.project_id
  name       = var.instance_name
}
