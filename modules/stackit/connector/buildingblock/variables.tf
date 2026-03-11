### forgejo

variable "forgejo_host" {
  description = "The URL of the Forgejo instance."
  type        = string
}

variable "forgejo_api_token" {
  description = "The API token for accessing the Forgejo instance."
  type        = string
}

variable "forgejo_repository_name" {
  description = "The name of the Forgejo repository where the action secrets will be created."
  type        = string
}

variable "forgejo_repository_owner" {
  description = "The owner of the Forgejo repository where the action secrets will be created."
  type        = string
}

variable "action_secret_name" {
  description = "The action secret holding the name of the push robot accessing the container registry."
  type        = string
}

variable "action_secret_secret" {
  description = "The action secret holding the secret of the push robot accessing the container registry."
  type        = string
}

### kubernetes

variable "namespace" {
  description = "Associated namespace in kubernetes cluster."
  type        = string
}