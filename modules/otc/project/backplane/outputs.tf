output "user_name" {
  value       = opentelekomcloud_identity_user_v3.building_block.name
  description = "Name of the IAM user the building block authenticates as."
}

output "password" {
  value       = random_password.building_block.result
  sensitive   = true
  description = "Password of the IAM user the building block authenticates as."
}

output "identity_provider_name" {
  value       = var.identity_provider == null ? null : opentelekomcloud_identity_provider.this.name
  description = "Name of the federated identity provider whose mapping project building blocks extend, or null without federation."
}

output "identity_provider_email_attribute" {
  value       = var.identity_provider == null ? null : var.identity_provider.email_attribute
  description = "SAML attribute or OIDC claim project building blocks match meshStack users' email against."
}

output "identity_provider_login_link" {
  value       = var.identity_provider == null ? null : opentelekomcloud_identity_provider.this.login_link
  description = "Console login link for federated users, or null without federation."
}
