output "workload_identity_federation_role" {
  description = "Workload identity federation role ARN"
  # Built from the role name to avoid a cycle.
  value = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.assume_federated_role_name}"
}
