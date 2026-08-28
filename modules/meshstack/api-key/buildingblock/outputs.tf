output "uuid" {
  description = "Server-generated UUID of the API key."
  value       = meshstack_api_key.this.metadata.uuid
}

output "client_id" {
  description = "Client ID used to authenticate with the API key."
  value       = meshstack_api_key.this.status.client_id
}

output "client_secret" {
  description = "Client secret used to authenticate with the API key. Treat as a credential and store securely."
  value       = meshstack_api_key.this.status.client_secret
  sensitive   = true
}
