output "region" {
  value       = aws_account_region.region.region_name
  description = "The region name"
}

output "opt_status" {
  value       = aws_account_region.region.opt_status
  description = "The region opt status"
}
