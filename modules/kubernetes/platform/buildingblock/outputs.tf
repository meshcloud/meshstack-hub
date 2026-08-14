output "platform_identifier" {
  description = "Platform identifier in the `<name>.<location>` form meshStack uses to address a platform, for example `ske-namespace.eu-de-central`."
  value       = "${meshstack_platform.this.metadata.name}.${meshstack_platform.this.spec.location_ref.name}"
}

output "platform_ref" {
  description = "Reference to the platform, for use in building block compositions that create tenants on it."
  value = {
    uuid = meshstack_platform.this.metadata.uuid
    kind = "meshPlatform"
  }
}

output "landing_zone_identifiers" {
  description = "meshStack landing zone identifiers keyed by environment."
  value       = { for env, lz in meshstack_landingzone.this : env => lz.metadata.name }
}

output "landing_zone_refs" {
  description = "meshStack landing zone references keyed by environment, for use in building block compositions."
  value       = { for env, lz in meshstack_landingzone.this : env => lz.ref }
}

output "replicator_token" {
  description = "Access token of the replicator service account. meshStack already holds this token, so you only need the output to debug the cluster connection."
  value       = local.replicator_token
  sensitive   = true
}

output "metering_token" {
  description = "Access token of the metering service account, or null when metering is off."
  value       = local.metering_token
  sensitive   = true
}
