output "workload_identity_federation_role" {
  description = "Workload identity federation role ARN"
  # Manually construct ARN to avoid dependency cycle on input workload_identity_federation (which contains the BBD UUID as subject)
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.assume_federated_role_name}"
}
