output "dynamodb_item_key" {
  description = "Composite key of the DynamoDB item written for this project (workspace/project)."
  value       = "${var.workspace_identifier}/${var.project_identifier}"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table the metadata was written to."
  value       = var.aws_dynamodb_table_name
}

output "dynamodb_item_url" {
  description = "AWS Console URL to view the specific item written for this project."
  value       = "https://${var.aws_region}.console.aws.amazon.com/dynamodbv2/home?region=${var.aws_region}#item?table=${var.aws_dynamodb_table_name}&itemMode=2&pk=${var.workspace_identifier}&sk=${var.project_identifier}&route=ROUTE_ITEM_EXPLORER"
}
