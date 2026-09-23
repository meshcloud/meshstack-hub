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
