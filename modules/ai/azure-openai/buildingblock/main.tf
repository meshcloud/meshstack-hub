locals {
  # LiteLLM's OpenAI-compatible routes live under '/v1'. The gateway also answers without the
  # prefix, but OpenAI client libraries expect it, so the output carries it.
  api_base = "${trimsuffix(var.litellm_api_base, "/")}/v1"
}

resource "litellm_model" "this" {
  model_name          = var.model_name
  custom_llm_provider = "azure"

  # The provider joins these two into '<custom_llm_provider>/<base_model>' and sends the result to
  # LiteLLM. Azure OpenAI addresses a deployment, not a model, so base_model carries the Azure
  # deployment name and the request goes to 'azure/<deployment name>'.
  base_model = var.azure_deployment_name

  model_api_base = var.azure_openai_endpoint
  model_api_key  = var.azure_openai_api_key
  api_version    = var.azure_openai_api_version
  mode           = var.mode

  # When a team ID is given, LiteLLM offers the model to that team alone. The gateway keeps one
  # entry per tenant, and the spend of each entry is attributed to its team.
  team_id = var.team_id
}
