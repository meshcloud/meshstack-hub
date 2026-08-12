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

output "api_base" {
  value = "https://api.openai-compat.model-serving.${stackit_modelserving_token.this.region}.onstackit.cloud/v1"
  # The '/v1' suffix belongs to the base URL. A client that drops it gets a 'Not Found' error
  # from the endpoint, so this output carries the suffix instead of leaving it to the caller.
  description = "OpenAI-compatible base URL of the STACKIT inference endpoint, including the '/v1' suffix."
}

output "summary" {
  description = "Summary with the endpoint URL and the token."
  sensitive   = true
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    token_name  = stackit_modelserving_token.this.name
    token_id    = stackit_modelserving_token.this.token_id
    token       = stackit_modelserving_token.this.token
    valid_until = stackit_modelserving_token.this.valid_until
    api_base    = "https://api.openai-compat.model-serving.${stackit_modelserving_token.this.region}.onstackit.cloud/v1"
  })
}
