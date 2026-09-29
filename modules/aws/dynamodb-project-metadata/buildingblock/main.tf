data "meshstack_project" "this" {
  metadata = {
    name               = var.project_identifier
    owned_by_workspace = var.workspace_identifier
  }
}

data "meshstack_tenant" "this" {
  metadata = {
    owned_by_project    = var.project_identifier
    owned_by_workspace  = var.workspace_identifier
    platform_identifier = var.platform_identifier
  }
}

locals {
  users_json = jsonencode([for u in var.users : { email = u.email, roles = u.roles }])

  # One DynamoDB attribute per meshStack tag instead of a single nested JSON blob.
  # meshStack tags are lists of strings; the account tags here are single-valued, so join.
  tag_attributes = {
    for k, v in data.meshstack_tenant.this.status.tags : k => { S = join(",", v) }
  }

  # The partition key attribute name is configurable via var.partition_key_name so it can match
  # whatever the target table uses (e.g. a pre-existing table with a non-standard attribute name).
  # mesh_accountStatus tracks the tenant/account: "active" while the tenant exists, "retired"
  # when the tenant is deleted (the pre-run script re-applies with account_status=retired on the
  # destroy run instead of deleting the item). Base attributes win over any same-named tag.
  item_attributes = merge(local.tag_attributes, {
    (var.partition_key_name) = { S = var.platform_tenant_id }
    mesh_accountStatus       = { S = var.account_status }
    workspace_identifier     = { S = var.workspace_identifier }
    project_identifier       = { S = var.project_identifier }
    platform_identifier      = { S = var.platform_identifier }
    users                    = { S = local.users_json }
  })
}

resource "aws_dynamodb_table_item" "this" {
  table_name = var.aws_dynamodb_table_name
  hash_key   = var.partition_key_name

  item = jsonencode(local.item_attributes)
}
