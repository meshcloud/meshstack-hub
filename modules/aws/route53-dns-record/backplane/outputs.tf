output "credentials" {
  sensitive = true
  value = {
    AWS_ACCESS_KEY_ID     = var.workload_identity_federation == null ? aws_iam_access_key.buildingblock_route53_record_access_key[0].id : "N/A; workload identity federation in use"
    AWS_SECRET_ACCESS_KEY = var.workload_identity_federation == null ? aws_iam_access_key.buildingblock_route53_record_access_key[0].secret : "N/A; workload identity federation in use"
  }
}

output "workload_identity_federation_role" {
  description = "Workload identity federation role ARN"
  # Manually construct ARN to avoid dependency cycle on input workload_identity_federation (which contains the BBD UUID as subject)
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BuildingBlockRoute53RecordIdentityFederation-${random_string.name_suffix.result}"
}
