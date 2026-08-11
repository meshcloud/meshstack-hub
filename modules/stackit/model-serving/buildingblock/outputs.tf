output "token" {
  value       = stackit_modelserving_token.this.token
  sensitive   = true
  description = "The STACKIT Model Serving API token. Shown only on creation."
}

output "token_id" {
  value       = stackit_modelserving_token.this.token_id
  description = "ID of the Model Serving token."
}

output "valid_until" {
  value       = stackit_modelserving_token.this.valid_until
  description = "Expiry timestamp of the Model Serving token."
}
