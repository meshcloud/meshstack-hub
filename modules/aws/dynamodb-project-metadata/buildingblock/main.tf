data "meshstack_project" "this" {
  metadata = {
    name               = var.project_identifier
    owned_by_workspace = var.workspace_identifier
  }
}

locals {
  tags_json  = jsonencode(data.meshstack_project.this.spec.tags)
  users_json = jsonencode([for u in var.users : { email = u.email, roles = u.roles }])
}

resource "aws_dynamodb_table_item" "this" {
  table_name = var.aws_dynamodb_table_name
  hash_key   = "workspace_identifier"
  range_key  = "project_identifier"

  item = jsonencode({
    workspace_identifier = { S = var.workspace_identifier }
    project_identifier   = { S = var.project_identifier }
    platform_identifier  = { S = var.platform_identifier }
    tags                 = { S = local.tags_json }
    users                = { S = local.users_json }
  })
}
