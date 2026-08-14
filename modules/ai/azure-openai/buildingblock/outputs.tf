output "model_name" {
  value       = litellm_model.this.model_name
  description = "Name to pass in the 'model' field of a request to the gateway."
}

output "model_id" {
  value       = litellm_model.this.id
  description = "ID LiteLLM gave the model entry."
}

output "api_base" {
  value       = local.api_base
  description = "OpenAI-compatible base URL of the LiteLLM gateway, including the '/v1' suffix. Calls to this model go here, not to the Azure endpoint."
}

output "summary" {
  description = "Summary with the model name and the endpoint to call it on."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    model_name        = litellm_model.this.model_name
    model_id          = litellm_model.this.id
    api_base          = local.api_base
    deployment_name   = var.azure_deployment_name
    azure_endpoint    = var.azure_openai_endpoint
    azure_api_version = var.azure_openai_api_version
  })
}
