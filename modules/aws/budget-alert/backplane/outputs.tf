output "workload_identity_federation_role" {
  description = "ARN of the IAM role the building block runner assumes via workload identity federation."
  # Manually construct ARN to avoid dependency cycle on input workload_identity_federation (which contains the BBD UUID as subject)
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.federated_role_name}"
}

output "role_name" {
  description = "Name of the IAM role the building block assumes in the account the budget is created in."
  value       = var.building_block_target_account_access_role_name
}
