variable "harbor_host" {
  type = string
  description = "The URL of the Harbor registry."
  default   = "https://registry.onstackit.cloud"
}

variable "harbor_username" {
  type = string
  description = "The username for the Harbor registry."
  sensitive = true
}

variable "harbor_password" {
  type = string
  description = "The password for the Harbor registry."
  sensitive = true
}

variable "forgejo_repository_name" {
  type        = string
  description = "The name of the Forgejo repository."
}

variable "forgejo_repository_owner" {
  type        = string
  description = "The owner of the Forgejo repository."
}

variable "additional_environment_variables" {
  type        = map(string)
  description = "Map of additional environment variable key/value pairs to set as Forgejo repository action secrets."
  default     = {}
}

variable "namespace" {
  description = "Associated namespace in kubernetes cluster."
  type        = string
}