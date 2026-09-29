output "table_name" {
  description = "Name of the DynamoDB table."
  value       = aws_dynamodb_table.this.name
}

output "table_arn" {
  description = "ARN of the DynamoDB table."
  value       = aws_dynamodb_table.this.arn
}

output "table_region" {
  description = "AWS region where the DynamoDB table was created."
  value       = aws_dynamodb_table.this.region
}

output "table_console_url" {
  description = "AWS Console URL for the DynamoDB table."
  value       = "https://${aws_dynamodb_table.this.region}.console.aws.amazon.com/dynamodbv2/home?region=${aws_dynamodb_table.this.region}#table?name=${aws_dynamodb_table.this.name}"
}

output "workload_identity_federation_role_arn" {
  description = "ARN of the IAM role assumed by the building block runtime via workload identity federation."
  # Manually construct ARN to avoid dependency cycle on input workload_identity_federation (which contains the BBD UUID as subject)
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.role_name}"
}
