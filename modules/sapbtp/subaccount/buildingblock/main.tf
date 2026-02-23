data "btp_directories" "all" {}

locals {
  reader = { for user in var.users : user.euid => user if contains(user.roles, "reader") }
  admin  = { for user in var.users : user.euid => user if contains(user.roles, "admin") }
  user   = { for user in var.users : user.euid => user if contains(user.roles, "user") }

  subfolders = [
    for dir in data.btp_directories.all.values : {
      id   = dir.id
      name = dir.name
    }
  ]

  # Support both subfolder name (meshStack pattern) and parent_id (import pattern)
  selected_subfolder_id = var.parent_id != "" ? var.parent_id : try(
    one([
      for sf in local.subfolders : sf.id
      if sf.name == var.subfolder
    ]),
    null
  )
}

resource "btp_subaccount" "subaccount" {
  name      = var.project_identifier
  subdomain = var.project_identifier
  parent_id = local.selected_subfolder_id
  region    = var.region
}

resource "btp_subaccount_role_collection_assignment" "subaccount_admin" {
  for_each             = local.admin
  role_collection_name = "Subaccount Administrator"
  subaccount_id        = btp_subaccount.subaccount.id
  user_name            = each.key
}

resource "btp_subaccount_role_collection_assignment" "subaccount_service_admininstrator" {
  for_each             = local.user
  role_collection_name = "Subaccount Service Administrator"
  subaccount_id        = btp_subaccount.subaccount.id
  user_name            = each.key
}

resource "btp_subaccount_role_collection_assignment" "subaccount_viewer" {
  for_each             = local.reader
  role_collection_name = "Subaccount Viewer"
  subaccount_id        = btp_subaccount.subaccount.id
  user_name            = each.key
}
