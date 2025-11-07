output "btp_subaccount_id" {
  value = btp_subaccount.subaccount.id
}

output "btp_subaccount_region" {
  value = btp_subaccount.subaccount.region
}

output "btp_subaccount_name" {
  value = btp_subaccount.subaccount.name
}

output "btp_subaccount_login_link" {
  value = "https://emea.cockpit.btp.cloud.sap/cockpit#/globalaccount/${btp_subaccount.subaccount.parent_id}/subaccount/${btp_subaccount.subaccount.id}"
}

output "entitlements" {
  description = "Map of entitlements created for this subaccount"
  value = merge(
    {
      for k, v in btp_subaccount_entitlement.entitlement_with_quota :
      k => {
        service_name = v.service_name
        plan_name    = v.plan_name
        amount       = v.amount
      }
    },
    {
      for k, v in btp_subaccount_entitlement.entitlement_without_quota :
      k => {
        service_name = v.service_name
        plan_name    = v.plan_name
        amount       = null
      }
    }
  )
}

output "subscriptions" {
  description = "Map of application subscriptions created in this subaccount"
  value = {
    for k, v in btp_subaccount_subscription.subscription :
    k => {
      app_name  = v.app_name
      plan_name = v.plan_name
      state     = v.state
    }
  }
}

output "cloudfoundry_instance_id" {
  description = "ID of the Cloud Foundry environment instance (if created)"
  value       = local.cloudfoundry_instance != null ? btp_subaccount_environment_instance.cloudfoundry[0].id : null
}

output "cloudfoundry_instance_state" {
  description = "State of the Cloud Foundry environment instance (if created)"
  value       = local.cloudfoundry_instance != null ? btp_subaccount_environment_instance.cloudfoundry[0].state : null
}

output "trust_configuration_origin" {
  description = "Origin key of the configured trust configuration (if configured)"
  value       = local.trust_configuration != null ? btp_subaccount_trust_configuration.custom_idp[0].origin : null
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
