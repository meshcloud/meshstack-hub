locals {
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

  cf_services_map = {
    postgresql_instances = {
      for idx, instance in local.cf_services_by_type.postgresql_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "postgresql-db" })
    }
    redis_instances = {
      for idx, instance in local.cf_services_by_type.redis_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "redis-cache" })
    }
    destination_instances = {
      for idx, instance in local.cf_services_by_type.destination_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "destination" })
    }
    connectivity_instances = {
      for idx, instance in local.cf_services_by_type.connectivity_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "connectivity" })
    }
    xsuaa_instances = {
      for idx, instance in local.cf_services_by_type.xsuaa_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "xsuaa" })
    }
    application_logs_instances = {
      for idx, instance in local.cf_services_by_type.application_logs_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "application-logs" })
    }
    html5_repo_instances = {
      for idx, instance in local.cf_services_by_type.html5_repo_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "html5-apps-repo" })
    }
    job_scheduler_instances = {
      for idx, instance in local.cf_services_by_type.job_scheduler_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "jobscheduler" })
    }
    credstore_instances = {
      for idx, instance in local.cf_services_by_type.credstore_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "credstore" })
    }
    objectstore_instances = {
      for idx, instance in local.cf_services_by_type.objectstore_instances :
      "${instance.name}-${instance.plan_name}" => merge(instance, { service_name = "objectstore" })
    }
  }

  all_cf_services = merge(
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
  )
}
