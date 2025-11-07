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
  entitlements_map_with_quota = {
    for idx, entitlement in local.entitlements_with_quota :
    "${entitlement.service_name}-${entitlement.plan_name}" => entitlement
  }

  entitlements_map_without_quota = {
    for idx, entitlement in local.entitlements_without_quota :
    "${entitlement.service_name}-${entitlement.plan_name}" => entitlement
  }

  subscriptions_map = {
    for idx, subscription in local.parsed_subscriptions :
    "${subscription.app_name}-${subscription.plan_name}" => subscription
  }
}

resource "btp_subaccount_entitlement" "entitlement_with_quota" {
  for_each = local.entitlements_map_with_quota

  subaccount_id = btp_subaccount.subaccount.id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
  amount        = each.value.amount
}

resource "btp_subaccount_entitlement" "entitlement_without_quota" {
  for_each = local.entitlements_map_without_quota

  subaccount_id = btp_subaccount.subaccount.id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
}

resource "btp_subaccount_subscription" "subscription" {
  for_each = local.subscriptions_map

  subaccount_id = btp_subaccount.subaccount.id
  app_name      = each.value.app_name
  plan_name     = each.value.plan_name
  parameters    = jsonencode(each.value.parameters)

  depends_on = [
    btp_subaccount_entitlement.entitlement_with_quota,
    btp_subaccount_entitlement.entitlement_without_quota
  ]
}

resource "btp_subaccount_environment_instance" "cloudfoundry" {
  count = local.cloudfoundry_instance != null ? 1 : 0

  subaccount_id    = btp_subaccount.subaccount.id
  name             = local.cloudfoundry_instance.name
  environment_type = local.cloudfoundry_instance.environment
  service_name     = local.cloudfoundry_instance.environment
  plan_name        = local.cloudfoundry_instance.plan_name
  parameters = jsonencode(merge(
    local.cloudfoundry_instance.parameters,
    { instance_name = local.cloudfoundry_instance.name }
  ))
}

resource "btp_subaccount_trust_configuration" "custom_idp" {
  count = local.trust_configuration != null ? 1 : 0

  subaccount_id     = btp_subaccount.subaccount.id
  identity_provider = local.trust_configuration.identity_provider
}

locals {
  cf_services_map = local.cloudfoundry_instance != null ? {
    postgresql_instances = {
      for idx, instance in local.cloudfoundry_services.postgresql_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "postgresql-db" })
    }
    redis_instances = {
      for idx, instance in local.cloudfoundry_services.redis_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "redis-cache" })
    }
    destination_instances = {
      for idx, instance in local.cloudfoundry_services.destination_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "destination" })
    }
    connectivity_instances = {
      for idx, instance in local.cloudfoundry_services.connectivity_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "connectivity" })
    }
    xsuaa_instances = {
      for idx, instance in local.cloudfoundry_services.xsuaa_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "xsuaa" })
    }
    application_logs_instances = {
      for idx, instance in local.cloudfoundry_services.application_logs_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "application-logs" })
    }
    html5_repo_instances = {
      for idx, instance in local.cloudfoundry_services.html5_repo_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "html5-apps-repo" })
    }
    job_scheduler_instances = {
      for idx, instance in local.cloudfoundry_services.job_scheduler_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "jobscheduler" })
    }
    credstore_instances = {
      for idx, instance in local.cloudfoundry_services.credstore_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "credstore" })
    }
    objectstore_instances = {
      for idx, instance in local.cloudfoundry_services.objectstore_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "objectstore" })
    }
  } : {}

  all_cf_services = local.cloudfoundry_instance != null ? merge(
    local.cf_services_map.postgresql_instances,
    local.cf_services_map.redis_instances,
    local.cf_services_map.destination_instances,
    local.cf_services_map.connectivity_instances,
    local.cf_services_map.xsuaa_instances,
    local.cf_services_map.application_logs_instances,
    local.cf_services_map.html5_repo_instances,
    local.cf_services_map.job_scheduler_instances,
    local.cf_services_map.credstore_instances,
    local.cf_services_map.objectstore_instances
  ) : {}
}

data "btp_subaccount_service_plan" "cf_service_plan" {
  for_each = local.all_cf_services

  subaccount_id = btp_subaccount.subaccount.id
  offering_name = each.value.service_name
  name          = each.value.plan_name

  depends_on = [
    btp_subaccount_entitlement.entitlement_with_quota,
    btp_subaccount_entitlement.entitlement_without_quota
  ]
}

resource "btp_subaccount_service_instance" "cf_service" {
  for_each = local.all_cf_services

  subaccount_id  = btp_subaccount.subaccount.id
  name           = each.value.name
  serviceplan_id = data.btp_subaccount_service_plan.cf_service_plan[each.key].id
  parameters     = jsonencode(each.value.parameters)

  depends_on = [
    btp_subaccount_environment_instance.cloudfoundry
  ]
}
