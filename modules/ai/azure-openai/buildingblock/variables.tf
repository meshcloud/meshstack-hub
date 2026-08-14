variable "litellm_api_base" {
  type        = string
  description = "Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. The provider talks to the admin API under this URL."
}

variable "litellm_api_key" {
  type        = string
  sensitive   = true
  description = "LiteLLM admin key the provider authenticates with. It needs permission to register models."
}

variable "azure_openai_endpoint" {
  type        = string
  description = "Endpoint of the Azure OpenAI resource, for example 'https://my-aoai.openai.azure.com'. LiteLLM calls the deployment under this host."
}

variable "azure_openai_api_key" {
  type        = string
  sensitive   = true
  description = "Key of the Azure OpenAI resource. LiteLLM stores it and sends it upstream in the 'api-key' header."
}

variable "azure_openai_api_version" {
  type        = string
  default     = "2024-10-21"
  description = "Azure OpenAI data plane API version. '2024-10-21' is the latest dated GA version of the inference API."
}

variable "azure_deployment_name" {
  type        = string
  description = "Name of the model deployment in the Azure OpenAI resource, for example 'gpt-4o'. Azure routes on the deployment name, not on the model name."
}

variable "model_name" {
  type        = string
  description = "Name the model is offered under on the LiteLLM gateway. Application teams pass this name in the 'model' field of their requests."
}

variable "mode" {
  type        = string
  default     = "chat"
  description = "What the deployment is used for. LiteLLM accepts 'chat', 'completion', 'embedding', 'audio_speech', 'audio_transcription', 'image_generation', 'video_generation', 'batch' and 'rerank'."
}

variable "team_id" {
  type        = string
  default     = null
  description = "ID of the LiteLLM team the model is registered for. Only that team can call the model. Leave unset to register the model for the whole gateway."
}
