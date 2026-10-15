variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the model serving token is created in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  description = "STACKIT region the token and the inference endpoint live in."
}

variable "token_name" {
  type        = string
  nullable    = false
  description = "Name of the model serving token, shown in the STACKIT portal."
}

variable "token_description" {
  type        = string
  nullable    = false
  description = "Description of the model serving token."
}

variable "model" {
  type        = string
  nullable    = false
  description = "Model applications default to. Must be one the `/v1/models` endpoint serves."
}

variable "output_to_vault" {
  type = object({
    address     = string
    mount       = string
    username    = string
    password    = string
    path_prefix = optional(string, "")
  })
  nullable    = false
  sensitive   = true
  description = "Vault KV v2 login this building block writes its secret with: the server `address`, the engine `mount`, a userpass `username` and `password`, and an optional `path_prefix`. The secret is `<path_prefix>stackit/ai-llm`, with the key `kubernetes-secret` (`{STACKIT_AI_BASE_URL, STACKIT_AI_API_KEY, STACKIT_AI_MODEL}`)."
}
