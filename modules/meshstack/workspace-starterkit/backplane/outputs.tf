# Split rather than one object: the client id is not a secret on its own, and marking it sensitive
# would force the building block definition's non-sensitive input to carry a sensitive value.

output "api_key_client_id" {
  description = "Client id of the API key. Wire into the building block definition as the `MESHSTACK_API_KEY` environment input."
  value       = meshstack_api_key.automation.status.client_id
}

output "api_key_client_secret" {
  description = "Client secret of the API key. Wire into the building block definition as the `MESHSTACK_API_SECRET` environment input, as a sensitive one."
  value       = meshstack_api_key.automation.status.client_secret
  sensitive   = true
}
