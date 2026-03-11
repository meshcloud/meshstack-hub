variable "cluster_host" {
  type        = string
  description = "The endpoint of the Kubernetes cluster."
}

variable "cluster_ca_certificate" {
  type      = string
  sensitive = true
}

variable "client_certificate" {
  type      = string
  sensitive = true
}

variable "client_key" {
  type      = string
  sensitive = true
}

variable "cluster_kubeconfig" {
  type      = string
  sensitive = true
}

variable "harbor_host" {
  type      = string
  sensitive = true
  default   = "https://registry.onstackit.cloud"
}

variable "harbor_username" {
  type      = string
  sensitive = true
}

variable "harbor_password" {
  type      = string
  sensitive = true
}

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