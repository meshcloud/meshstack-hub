output "credentials" {
  sensitive = true
  value = {
    AWS_ACCESS_KEY_ID     = var.workload_identity_federation == null ? aws_iam_access_key.buildingblock_s3_access_key[0].id : "N/A; workload identity federation in use"
    AWS_SECRET_ACCESS_KEY = var.workload_identity_federation == null ? aws_iam_access_key.buildingblock_s3_access_key[0].secret : "N/A; workload identity federation in use"
  }
}

output "workload_identity_federation_role" {
  value = var.workload_identity_federation == null ? null : aws_iam_role.assume_federated_role[0].arn
}
