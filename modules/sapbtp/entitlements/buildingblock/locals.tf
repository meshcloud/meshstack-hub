locals {
  quota_based_services = ["postgresql-db", "redis-cache", "hana-cloud", "auditlog-viewer", "APPLICATION_RUNTIME", "sapappstudio", "sap-build-apps"]

  raw_entitlements = var.entitlements != "" ? (
    can(jsondecode(var.entitlements)) ? jsondecode(var.entitlements) : split(",", var.entitlements)
  ) : []

  parsed_entitlements = [
    for e in local.raw_entitlements :
    {
      service_name = split(".", trimspace(e))[0]
      plan_name    = split(".", trimspace(e))[1]
      amount       = contains(local.quota_based_services, split(".", trimspace(e))[0]) ? 1 : null
    }
    if trimspace(e) != ""
  ]

  entitlements_with_quota = [
    for e in local.parsed_entitlements :
    e if e.amount != null
  ]

  entitlements_without_quota = [
    for e in local.parsed_entitlements :
    e if e.amount == null
  ]

  entitlements_map_with_quota = {
    for idx, entitlement in local.entitlements_with_quota :
    "${entitlement.service_name}-${entitlement.plan_name}" => entitlement
  }

  entitlements_map_without_quota = {
    for idx, entitlement in local.entitlements_without_quota :
    "${entitlement.service_name}-${entitlement.plan_name}" => entitlement
  }
}
