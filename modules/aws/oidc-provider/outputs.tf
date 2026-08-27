output "arn" {
  description = "ARN of the IAM OIDC provider. Pass this to every AWS backplane in this account as `oidc_provider_arn`."
  value       = aws_iam_openid_connect_provider.meshstack.arn
}
