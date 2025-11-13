output "trust_configuration_origin" {
  description = "Origin key of the configured trust configuration (if configured)"
  value       = local.trust_configuration != null ? btp_subaccount_trust_configuration.custom_idp[0].origin : null
}

output "trust_configuration_status" {
  description = "Status of the trust configuration (if configured)"
  value       = local.trust_configuration != null ? btp_subaccount_trust_configuration.custom_idp[0].status : null
}

output "subaccount_id" {
  description = "The subaccount ID (passthrough for dependency chaining)"
  value       = var.subaccount_id
}
