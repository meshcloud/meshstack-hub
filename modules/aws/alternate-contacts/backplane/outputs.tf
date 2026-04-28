output "aws_access_key_id" {
  description = "Access key for the IAM user that can set alternate contacts"
  value       = aws_iam_access_key.backplane.id
}

output "aws_secret_access_key" {
  description = "Secret key for the IAM user that can set alternate contacts"
  sensitive   = true
  value       = aws_iam_access_key.backplane.secret
}

output "role_name" {
  description = "Name of the IAM role assumed in target accounts to set alternate contacts"
  value       = var.building_block_target_account_access_role_name
}
