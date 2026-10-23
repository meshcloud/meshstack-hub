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
  description = "Namespace to grant access to. Must be one of the namespaces the backplane offers."
  type        = string
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
