output "token_replicator" {
  sensitive = true
  value     = kubernetes_secret.meshfed_service_secret.data["token"]
}

output "full_platform_identifier" {
  value = "${meshstack_platform.this.metadata.name}.${meshstack_platform.this.spec.location_ref.name}"
}

output "platform_ref" {
  value = {
    uuid = meshstack_platform.this.metadata.uuid
    kind = "meshPlatform"
  }
}

output "landing_zone_identifiers" {
  value = {
    dev  = meshstack_landingzone.dev.metadata.name
    prod = meshstack_landingzone.prod.metadata.name
  }
}

output "landing_zone_refs" {
  value = {
    dev  = meshstack_landingzone.dev.ref
    prod = meshstack_landingzone.prod.ref
  }
}