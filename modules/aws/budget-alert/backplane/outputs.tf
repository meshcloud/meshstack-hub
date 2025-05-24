output "aws_access_key_id" {
  description = "Access key for the IAM role that can deploy budget alerts"
  value       = aws_iam_access_key.backplane.id
}

output "aws_secret_access_key" {
  description = "Secret key for the IAM role that can deploy budget alerts"
  sensitive   = true
  value       = aws_iam_access_key.backplane.secret
}

output "role_name" {
  description = "ARN of the IAM role that can deploy budget alerts"
  value       = var.building_block_target_account_access_role_name
}
