output "user_name" {
  value       = opentelekomcloud_identity_user_v3.building_block.name
  description = "Name of the IAM user the building blocks authenticate as."
}

output "access_key" {
  value       = opentelekomcloud_identity_credential_v3.building_block.access
  sensitive   = true
  description = "Access key of the IAM user the building blocks authenticate as."
}

output "secret_key" {
  value       = opentelekomcloud_identity_credential_v3.building_block.secret
  sensitive   = true
  description = "Secret key of the IAM user the building blocks authenticate as."
}

output "mapping_bucket" {
  value       = local.federation_enabled ? opentelekomcloud_obs_bucket.mappings.bucket : null
  description = "OBS bucket project building blocks record their group membership in, or null without federation."
}

output "identity_provider_name" {
  value       = local.federation_enabled ? opentelekomcloud_identity_provider.this.name : null
  description = "Name of the federated identity provider, or null without federation."
}

output "identity_provider_email_attribute" {
  value       = local.federation_enabled ? var.identity_provider.email_attribute : null
  description = "SAML attribute or OIDC claim that carries the user's email address."
}

output "identity_provider_login_link" {
  value       = local.federation_enabled ? opentelekomcloud_identity_provider.this.login_link : null
  description = "Console login link for federated users, or null without federation."
}
