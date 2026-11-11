output "arn" {
  description = "ARN of the IAM OIDC provider. A backplane finds the provider by its issuer. It takes this ARN as `oidc_provider_arn` only together with `workload_identity_federation`."
  value       = aws_iam_openid_connect_provider.meshstack.arn
}
