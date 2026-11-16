output "arn" {
  description = "ARN of the IAM OIDC provider. Pass it as `oidc_provider_arn` to a backplane that gets `workload_identity_federation`. A backplane that gets `runner_identities` looks the provider up and needs no ARN."
  value       = aws_iam_openid_connect_provider.meshstack.arn
}
