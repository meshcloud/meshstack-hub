variable "project_id" {
  description = "GCP project ID that contains the GKE cluster."
  type        = string
  nullable    = false
}

variable "cluster_name" {
  description = "Name of the GKE cluster."
  type        = string
  nullable    = false
}

variable "cluster_location" {
  description = "Region or zone of the GKE cluster."
  type        = string
  nullable    = false
}

variable "author" {
  description = "The meshStack user who requested access. They receive the access on their Google identity, which must use the same email."
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  nullable = false

  # API keys can order building blocks too, but have no Google identity to grant access to.
  validation {
    condition     = var.author.email != null
    error_message = "Only users with an email address can request access."
  }
}

variable "namespace" {
  description = "Namespace to grant access to. Must exist and must not be forbidden."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace))
    error_message = "\"${var.namespace}\" is not a valid namespace name."
  }

  # The backplane's admission policy enforces this too. Checking here fails the run before it
  # touches IAM, with a clearer message.
  validation {
    condition = !anytrue([
      for pattern in var.forbidden_namespaces :
      endswith(pattern, "*") ? startswith(var.namespace, trimsuffix(pattern, "*")) : var.namespace == pattern
    ])
    error_message = "Access to namespace \"${var.namespace}\" can't be requested."
  }
}

variable "forbidden_namespaces" {
  description = "Namespaces developers can't request access to. A trailing `*` matches a prefix. Take it from the backplane's `forbidden_namespaces` output."
  type        = set(string)
  nullable    = false
}

variable "duration_hours" {
  description = "How many hours the access lasts, counted from the first run."
  type        = number
  nullable    = false

  validation {
    condition     = var.duration_hours == floor(var.duration_hours) && var.duration_hours >= 1 && var.duration_hours <= 8
    error_message = "Access lasts between 1 and 8 whole hours."
  }
}

variable "cluster_role" {
  description = "ClusterRole to bind the developer to. Take it from the backplane's `cluster_role` output."
  type        = string
  nullable    = false
}

variable "binding_label" {
  description = "Label the cleanup CronJob selects RoleBindings by. Take it from the backplane's `binding_label` output."
  type        = string
  nullable    = false
}

variable "expiry_annotation" {
  description = "Annotation the cleanup CronJob reads the expiry from. Take it from the backplane's `expiry_annotation` output."
  type        = string
  nullable    = false
}
