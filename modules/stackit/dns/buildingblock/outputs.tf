output "zone_name" {
  value       = stackit_dns_zone.this.dns_name
  description = "DNS name of the zone, for example `likvid.stackit.run`. Use it as the ExternalDNS zone filter and as the zone the cert-manager DNS-01 solver operates on."
}

output "zone_id" {
  value       = stackit_dns_zone.this.zone_id
  description = "UUID of the zone."
}

output "zone_project_id" {
  value       = var.project_id
  description = "STACKIT project ID the zone lives in. The DNS-01 solver has to name the same project, because STACKIT DNS is project-scoped."
}

output "record_fqdns" {
  value       = { for name, record in stackit_dns_record_set.this : name => record.fqdn }
  description = "Fully qualified name of every record set the module created, keyed the same way as the `records` input."
}

output "delegation_record_fqdn" {
  value       = one(stackit_dns_record_set.delegation[*].fqdn)
  description = "Fully qualified name of the NS record created in the parent zone. Null when `delegation` is unset, which is the usual case."
}

output "dns_service_account_email" {
  value       = one(stackit_service_account.dns[*].email)
  description = "Email of the service account that manages records in the zone. Null when `dns_service_account_enabled` is false."
}

output "dns_service_account_key" {
  value       = one(stackit_service_account_key.dns[*].json)
  description = "STACKIT service account key as raw JSON, for the cert-manager DNS-01 solver and for ExternalDNS. It holds `dns.admin` on the zone's project, so it can write every record in every zone of that project. Null when `dns_service_account_enabled` is false."
  sensitive   = true
}

output "summary" {
  description = "Summary with the zone, its records and the DNS credential."
  sensitive   = true
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    zone_name         = stackit_dns_zone.this.dns_name
    zone_id           = stackit_dns_zone.this.zone_id
    project_id        = var.project_id
    record_fqdns      = sort([for record in stackit_dns_record_set.this : record.fqdn])
    credential_shared = var.dns_service_account_enabled
    dns_email         = coalesce(one(stackit_service_account.dns[*].email), "-")
    dns_key           = coalesce(one(stackit_service_account_key.dns[*].json), "-")
  })
}
