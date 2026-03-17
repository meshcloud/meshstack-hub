variable "cluster_host" {
  type        = string
  description = "The endpoint of the Kubernetes cluster."
}

variable "cluster_ca_certificate" {
  description = "Base64-encoded certificate authority (CA) certificate used to verify the Kubernetes API server's identity."
  type        = string
  sensitive   = true
}

variable "client_certificate" {
  description = "Base64-encoded client certificate used for authenticating to the Kubernetes API server."
  type        = string
  sensitive   = true
}

variable "client_key" {
  description = "Base64-encoded private key corresponding to the client certificate, used for authentication with the Kubernetes API server."
  type        = string
  sensitive   = true
}
