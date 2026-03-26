variable "namespace" {
  description = "Kubernetes namespace to deploy the Helm release into."
  type        = string
}

variable "release_name" {
  description = "Name of the Helm release."
  type        = string
}

variable "values_yaml" {
  description = "Helm values as a JSON-encoded string (YAML is also accepted by Helm)."
  type        = string
  default     = "{}"
}
