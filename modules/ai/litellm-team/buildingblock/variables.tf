variable "litellm_api_base" {
  type        = string
  description = "Base URL of the LiteLLM gateway, for example 'https://litellm.example.com'. The provider talks to the admin API under this URL."
}

variable "litellm_api_key" {
  type        = string
  sensitive   = true
  description = "LiteLLM admin key the provider authenticates with. It needs permission to create teams and keys."
}

variable "workspace_identifier" {
  type        = string
  description = "Identifier of the meshStack workspace the tenant belongs to. It becomes part of the team alias and is written to the team metadata."
}

variable "project_identifier" {
  type        = string
  description = "Identifier of the meshStack project the tenant belongs to. It becomes part of the team alias and is written to the team metadata."
}

variable "meshstack_tenant_uuid" {
  type        = string
  default     = ""
  description = "UUID of the meshStack tenant. It is written to the team metadata so an operator can trace a LiteLLM team back to its tenant."
}

variable "team_alias" {
  type        = string
  default     = null
  description = "Alias of the LiteLLM team. Leave unset to use '<workspace_identifier>.<project_identifier>'."
}

variable "key_alias" {
  type        = string
  default     = null
  description = "Alias of the virtual key. Leave unset to use '<team_alias>-key'."
}

variable "models" {
  type        = list(string)
  default     = []
  description = "Names of the models on the LiteLLM gateway that the team may call. An empty list sends no allow-list to LiteLLM."
}

variable "max_budget" {
  type        = number
  default     = 100
  description = "Spending limit of the team for one budget period, in the currency the gateway reports spend in. LiteLLM blocks the team once the limit is reached."
}

variable "budget_duration" {
  type        = string
  default     = "30d"
  description = "Length of one budget period, after which LiteLLM resets the spend counter. Written as a LiteLLM duration such as '30d', '7d' or '1h'."
}
