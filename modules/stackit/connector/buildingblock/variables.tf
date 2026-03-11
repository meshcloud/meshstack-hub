variable "additional_environment_variables" {
  type        = map(string)
  description = "Map of additional environment variable key/value pairs to set as Forgejo repository action secrets."
  default     = {}
}

variable "namespace" {
  description = "Associated namespace in kubernetes cluster."
  type        = string
}