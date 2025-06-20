output "aws_access_key_id" {
  description = "Access key for the IAM role that can deploy the building block"
  value       = aws_iam_access_key.backplane.id
}

output "aws_secret_access_key" {
  description = "Secret key for the IAM role that can deploy the building block"
  sensitive   = true
  value       = aws_iam_access_key.backplane.secret
}

output "backplane_role_arn" {
  description = "ARN of the IAM role that can deploy the building block"
  value       = aws_iam_role.backplane.arn
}
