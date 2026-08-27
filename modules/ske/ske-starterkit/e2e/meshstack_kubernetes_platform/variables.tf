variable "kube_host" {
  type        = string
  nullable    = false
  description = "The Kubernetes API server URL."
}

variable "workspace" {
  type        = string
  nullable    = false
  description = "The meshStack workspace identifier that will own the platform and landing zones."
}

variable "test_suffix" {
  type = string
}
