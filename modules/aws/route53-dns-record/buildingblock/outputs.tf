output "record_name" {
  description = "The FQDN of the DNS record"
  value       = aws_route53_record.record.name
}

output "record_type" {
  description = "The type of the DNS record"
  value       = aws_route53_record.record.type
}

output "record_value" {
  description = "The value of the DNS record"
  value       = var.record
}

output "summary" {
  description = "Summary of the created DNS record"
  value       = <<-EOT
Route53 DNS record `${aws_route53_record.record.name}` points to `${var.record}`.

| Property | Value |
|----------|-------|
| DNS Name | `${aws_route53_record.record.name}` |
| Type | `${var.type}` |
| Value | `${var.record}` |
| TTL | `${var.ttl}` seconds |
| Zone | `${var.zone_name}` |

${var.private_zone ? "⚠️ *Note:* This is a private hosted zone record, only resolvable within your VPC." : "🌐 *Note:* This is a public DNS record, resolvable globally."}

*Propagation:* DNS changes may take up to ${var.ttl} seconds to fully propagate.
EOT
}
