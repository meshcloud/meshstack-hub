variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the cluster in place when it is destroyed, and only drop it from the state."
}

variable "project_id" {
  type     = string
  nullable = false
}

variable "region" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}

variable "kubernetes_version_min" {
  type     = string
  nullable = true
}

variable "node_pools" {
  type = list(object({
    name               = string
    machine_type       = string
    minimum            = number
    maximum            = number
    availability_zones = list(string)
    max_surge          = number
  }))
  nullable = false
}

variable "maintenance" {
  type = object({
    enable_kubernetes_version_updates    = bool
    enable_machine_image_version_updates = bool
    start                                = string
    end                                  = string
  })
  nullable = false
}
