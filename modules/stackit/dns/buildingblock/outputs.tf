output "zone_name" {
  value       = module.zone.zone.dns_name
  description = "Fully qualified name of the zone. Hostnames are built under it."
}

output "zone_id" {
  value       = module.zone.zone.zone_id
  description = "Id of the created zone, for records made by another building block."
}

output "zone_url" {
  value       = "https://portal.stackit.cloud/projects/${var.stackit_project_id}/dns/${module.zone.zone.zone_id}"
  description = "The zone in the STACKIT portal."
}

output "summary" {
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    zone_name          = local.zone_name
    zone_url           = "https://portal.stackit.cloud/projects/${var.stackit_project_id}/dns/${module.zone.zone.zone_id}"
    wildcard_target_ip = var.wildcard_target_ip
    default_ttl        = var.default_ttl
  })
  description = "Markdown summary shown on the building block."
}
