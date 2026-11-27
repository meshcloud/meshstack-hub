output "record_name" {
  description = "The FQDN of the DNS record"
  value       = aws_route53_record.record.name
}

output "record_type" {
  description = "The type of the DNS record"
  value       = aws_route53_record.record.type
}

output "alias_target" {
  description = "The alias target"
  value       = var.alias_name
}

output "summary" {
  description = "Summary of the created DNS alias record"
  value       = <<-EOT
Route53 DNS alias record `${aws_route53_record.record.name}` points to `${var.alias_name}`.

| Property | Value |
|----------|-------|
| DNS Name | `${aws_route53_record.record.name}` |
| Type | `${var.type}` |
| Alias Target | `${var.alias_name}` |
| Health Check | ${var.alias_evaluate_target_health ? "✅ Enabled" : "⚠️ Disabled"} |
| Zone | `${var.zone_name}` |

${var.private_zone ? "⚠️ *Note:* This is a private hosted zone record, only resolvable within your VPC." : "🌐 *Note:* This is a public DNS record, resolvable globally."}
EOT
}
