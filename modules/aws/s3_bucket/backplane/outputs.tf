output "credentials" {
  sensitive   = true
  description = "Access credentials for the S3 bucket, only available if workload_identity_federation variable is null."
  value = try({
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.buildingblock_s3_access_key[0].id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.buildingblock_s3_access_key[0].secret
  }, null)
}

output "workload_identity_federation_role_arn" {
  description = "Workload identity federation role ARN"
  # Manually construct ARN to avoid dependency cycle on input workload_identity_federation (which contains the BBD UUID as subject)
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.assume_federated_role_name}"
}
