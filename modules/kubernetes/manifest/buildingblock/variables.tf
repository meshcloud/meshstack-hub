variable "namespace" {
  description = "Kubernetes namespace to deploy the Helm release into."
  type        = string
}

variable "release_name" {
  description = "Name of the Helm release."
  type        = string
}

variable "release_name_suffix" {
  description = "Appended to `release_name` as `<release_name>-<suffix>`, so several instances can share one namespace."
  type        = string
  default     = ""
  nullable    = false
}

variable "values_yaml" {
  description = "Helm values as a JSON-encoded string (YAML is also accepted by Helm)."
  type        = string
  default     = "{}"
}

variable "secret_values_yaml" {
  description = "Helm values that hold secrets, merged after `values_yaml` so they override it."
  type        = string
  default     = "{}"
  sensitive   = true
}
