output "btp_subaccount_id" {
  value = "initial state creation"
}

output "btp_subaccount_region" {
  value = "initial state creation"
}

output "btp_subaccount_name" {
  value = "initial state creation"
}

output "btp_subaccount_login_link" {
  value = "initial state creation"
}

output "entitlements" {
  description = "Map of entitlements created for this subaccount"
  value       = "initial state creation"
}

output "subscriptions" {
  description = "Map of application subscriptions created in this subaccount"
  value       = "initial state creation"
}

output "cloudfoundry_instance_id" {
  description = "ID of the Cloud Foundry environment instance (if created)"
  value       = "initial state creation"
}

output "cloudfoundry_instance_state" {
  description = "State of the Cloud Foundry environment instance (if created)"
  value       = "initial state creation"
}

output "trust_configuration_origin" {
  description = "Origin key of the configured trust configuration (if configured)"
  value       = "initial state creation"
}

output "cloudfoundry_services" {
  description = "Map of Cloud Foundry service instances created in this subaccount"
  value       = "initial state creation"
}
