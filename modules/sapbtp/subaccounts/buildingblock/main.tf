data "btp_directories" "all" {}

# iterate through the list of users and redue to a map of user with only their euid
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

  selected_subfolder_id = try(
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

# btp_subaccount_role_collection_assignment.subaccount_admin_sysuser will be created
resource "btp_subaccount_role_collection_assignment" "subaccount_service_admininstrator" {
  for_each             = local.user
  role_collection_name = "Subaccount Service Administrator"
  subaccount_id        = btp_subaccount.subaccount.id
  user_name            = each.key
}

# btp_subaccount_role_collection_assignment.subaccount_viewer will be created
resource "btp_subaccount_role_collection_assignment" "subaccount_viewer" {
  for_each             = local.reader
  role_collection_name = "Subaccount Viewer"
  subaccount_id        = btp_subaccount.subaccount.id
  user_name            = each.key
}
