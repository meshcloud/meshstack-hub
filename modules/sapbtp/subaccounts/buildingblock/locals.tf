locals {
  quota_based_services = ["postgresql-db", "redis-cache", "hana-cloud", "auditlog-viewer"]

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

  raw_subscriptions = var.subscriptions != "" ? (
    can(jsondecode(var.subscriptions)) ? jsondecode(var.subscriptions) : split(",", var.subscriptions)
  ) : []

  parsed_subscriptions = [
    for s in local.raw_subscriptions :
    {
      app_name   = split(".", trimspace(s))[0]
      plan_name  = split(".", trimspace(s))[1]
      parameters = {}
    }
    if trimspace(s) != ""
  ]

  raw_cf_services = var.cf_services != "" ? (
    can(jsondecode(var.cf_services)) ? jsondecode(var.cf_services) : split(",", var.cf_services)
  ) : []

  parsed_cf_services = [
    for s in local.raw_cf_services :
    {
      service_name  = split(".", trimspace(s))[0]
      plan_name     = split(".", trimspace(s))[1]
      instance_name = "${split(".", trimspace(s))[0]}-${split(".", trimspace(s))[1]}"
    }
    if trimspace(s) != ""
  ]

  cf_services_by_type = {
    postgresql_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "postgresql"
    ]
    redis_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "redis"
    ]
    destination_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "destination"
    ]
    connectivity_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "connectivity"
    ]
    xsuaa_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "xsuaa"
    ]
    application_logs_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "application-logs"
    ]
    html5_repo_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "html5-apps-repo"
    ]
    job_scheduler_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "job-scheduler"
    ]
    credstore_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "credstore"
    ]
    objectstore_instances = [
      for s in local.parsed_cf_services :
      {
        name       = s.instance_name
        plan_name  = s.plan_name
        parameters = {}
      }
      if s.service_name == "objectstore"
    ]
  }

  cloudfoundry_instance = var.enable_cloudfoundry ? {
    name        = "cf-${var.project_identifier}"
    environment = "cloudfoundry"
    plan_name   = var.cloudfoundry_plan
    parameters  = {}
  } : null

  trust_configuration = var.identity_provider != "" ? {
    identity_provider = var.identity_provider
  } : null

  cloudfoundry_services = var.enable_cloudfoundry ? local.cf_services_by_type : {
    postgresql_instances       = []
    redis_instances            = []
    destination_instances      = []
    connectivity_instances     = []
    xsuaa_instances            = []
    application_logs_instances = []
    html5_repo_instances       = []
    job_scheduler_instances    = []
    credstore_instances        = []
    objectstore_instances      = []
  }
}
