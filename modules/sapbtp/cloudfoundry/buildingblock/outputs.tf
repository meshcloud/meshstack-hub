output "cloudfoundry_instance_id" {
  description = "ID of the Cloud Foundry environment instance"
  value       = btp_subaccount_environment_instance.cloudfoundry.id
}

output "cloudfoundry_instance_state" {
  description = "State of the Cloud Foundry environment instance"
  value       = btp_subaccount_environment_instance.cloudfoundry.state
}

output "cloudfoundry_services" {
  description = "Map of Cloud Foundry service instances created in this subaccount"
  value = {
    for k, v in btp_subaccount_service_instance.cf_service :
    k => {
      name         = v.name
      service_name = local.all_cf_services[k].service_name
      plan_name    = local.all_cf_services[k].plan_name
      instance_id  = v.id
      ready        = v.ready
    }
  }
}

output "subaccount_id" {
  description = "The subaccount ID (passthrough for dependency chaining)"
  value       = var.subaccount_id
}
