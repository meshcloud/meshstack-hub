output "endpoint" {
  description = "The endpoint of the AI Services account."
  value       = azurerm_cognitive_account.this.endpoint
}

output "openai_endpoint" {
  description = "The endpoint OpenAI clients use as their Azure endpoint."
  value       = "https://${azurerm_cognitive_account.this.custom_subdomain_name}.openai.azure.com/"
}

output "deployment_name" {
  description = "The deployment name requests address the model by."
  value       = azurerm_cognitive_deployment.this.name
}

output "model" {
  description = "The deployed model and version."
  value       = "${var.model_name} (${local.model.version})"
}

output "account_name" {
  description = "The name of the AI Services account, including its random suffix."
  value       = azurerm_cognitive_account.this.name
}

output "resource_group" {
  description = "The resource group containing the AI Services account."
  value       = azurerm_resource_group.this.name
}

output "portal_url" {
  description = "Azure Portal URL of the AI Services account."
  value       = local.portal_url
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value       = <<-EOT
    # Azure AI LLM

    **${var.model_name}** (${local.model.version}) is deployed as `${azurerm_cognitive_deployment.this.name}` with ${var.capacity}k tokens per minute (${var.deployment_sku}).

    - **Endpoint**: `${azurerm_cognitive_account.this.custom_subdomain_name}.openai.azure.com`
    - **Resource group**: ${azurerm_resource_group.this.name}
    - **Network access**: ${var.public_network_access_enabled ? "public, protected by Entra ID" : "private endpoints only"}
    - **Access**: ${var.app_principal_id != null ? "`${var.app_principal_id}` holds `Cognitive Services OpenAI User`" : "no identity granted yet, assign `Cognitive Services OpenAI User` on the account"}
    - [Open in Azure Portal](${local.portal_url})

    API keys are disabled. Authenticate with an Entra ID token, for example with `DefaultAzureCredential`:

    ```python
    from azure.identity import DefaultAzureCredential, get_bearer_token_provider
    from openai import AzureOpenAI

    client = AzureOpenAI(
        azure_endpoint="https://${azurerm_cognitive_account.this.custom_subdomain_name}.openai.azure.com/",
        azure_ad_token_provider=get_bearer_token_provider(DefaultAzureCredential(), "https://cognitiveservices.azure.com/.default"),
        api_version="2025-04-01-preview",
    )
    client.chat.completions.create(model="${azurerm_cognitive_deployment.this.name}", messages=[{"role": "user", "content": "Hello"}])
    ```
  EOT
}
