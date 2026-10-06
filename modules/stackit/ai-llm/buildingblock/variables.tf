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
    address  = string
    mount    = string
    username = string
    password = string
    path     = string
  })
  nullable    = false
  sensitive   = true
  description = "Vault KV v2 secret this building block writes its secrets to: the server `address`, the engine `mount`, a userpass `username` and `password`, and the secret `path`."
}
