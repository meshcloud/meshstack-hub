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

locals {
  entitlements_map = {
    for idx, entitlement in var.entitlements :
    "${entitlement.service_name}-${entitlement.plan_name}" => entitlement
  }

  subscriptions_map = {
    for idx, subscription in var.subscriptions :
    "${subscription.app_name}-${subscription.plan_name}" => subscription
  }
}

resource "btp_subaccount_entitlement" "entitlement" {
  for_each = local.entitlements_map

  subaccount_id = btp_subaccount.subaccount.id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
  amount        = each.value.amount
}

resource "btp_subaccount_subscription" "subscription" {
  for_each = local.subscriptions_map

  subaccount_id = btp_subaccount.subaccount.id
  app_name      = each.value.app_name
  plan_name     = each.value.plan_name
  parameters    = jsonencode(each.value.parameters)

  depends_on = [btp_subaccount_entitlement.entitlement]
}

resource "btp_subaccount_environment_instance" "cloudfoundry" {
  count = var.cloudfoundry_instance != null ? 1 : 0

  subaccount_id    = btp_subaccount.subaccount.id
  name             = var.cloudfoundry_instance.name
  environment_type = var.cloudfoundry_instance.environment
  service_name     = var.cloudfoundry_instance.environment
  plan_name        = var.cloudfoundry_instance.plan_name
  parameters = jsonencode(merge(
    var.cloudfoundry_instance.parameters,
    { instance_name = var.cloudfoundry_instance.name }
  ))
}

resource "btp_subaccount_trust_configuration" "custom_idp" {
  count = var.trust_configuration != null ? 1 : 0

  subaccount_id     = btp_subaccount.subaccount.id
  identity_provider = var.trust_configuration.identity_provider
}
