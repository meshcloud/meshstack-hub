output "zone_name" {
  value       = var.zone_name
  description = "DNS name of the zone, for example `likvid.stackit.run`. Use it as the ExternalDNS zone filter and as the zone the cert-manager DNS-01 solver operates on."
}

output "zone_id" {
  value       = local.zone_id
  description = "UUID of the zone the record sets were written into, whether this module created it or not."
}

output "zone_project_id" {
  value       = var.project_id
  description = "STACKIT project ID the zone lives in. The DNS-01 solver has to name the same project, because STACKIT DNS is project-scoped."
}

output "record_fqdns" {
  value       = { for name, record in stackit_dns_record_set.this : name => record.fqdn }
  description = "Fully qualified name of every record set the module created, keyed the same way as the `records` input."
}

output "wildcard_domain" {
  value       = local.wildcard_domain
  description = "Domain the wildcard record covers — the zone itself when no label is set, and `<label>.<zone_name>` otherwise. Application hostnames live under it, and a wildcard certificate has to be issued for `*.<wildcard_domain>`. Null when `wildcard` is unset."
}

output "wildcard_record_fqdn" {
  value       = one(stackit_dns_record_set.wildcard[*].fqdn)
  description = "Fully qualified name of the wildcard record set. Null when `wildcard` is unset."
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
  description = "Summary with the zone, its records and the DNS credential. Null when the module is switched off with `zone_name = null`."
  sensitive   = true
  value = var.zone_name == null ? null : templatefile("${path.module}/SUMMARY.md.tftpl", {
    zone_name    = var.zone_name
    zone_id      = local.zone_id
    zone_created = var.create_zone
    project_id   = var.project_id
    record_fqdns = sort(concat(
      [for record in stackit_dns_record_set.this : record.fqdn],
      stackit_dns_record_set.wildcard[*].fqdn
    ))
    credential_shared = var.dns_service_account_enabled
    dns_email         = coalesce(one(stackit_service_account.dns[*].email), "-")
    dns_key           = coalesce(one(stackit_service_account_key.dns[*].json), "-")
  })
}
