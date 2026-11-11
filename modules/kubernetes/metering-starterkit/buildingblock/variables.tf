variable "clouds" {
  type        = list(string)
  nullable    = false
  description = "Clouds whose costs are metered, keys of `metering_building_block_definition_version_refs`."
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "Workspace that gets the metering project."
}

variable "payment_method" {
  type = object({
    kind = string
    name = string
  })
  nullable    = false
  description = "Payment method of the metering project."
}

variable "project_name" {
  type        = string
  nullable    = false
  description = "Name of the metering project, and so part of its namespace."
}

variable "project_tags" {
  type        = map(list(string))
  nullable    = false
  description = "Tags of the metering project."
}

variable "platform_ref" {
  type = object({
    uuid = string
  })
  nullable    = false
  description = "Kubernetes meshPlatform the metering namespace is created on."
}

variable "landing_zone_ref" {
  type = object({
    name = string
  })
  nullable    = false
  description = "Landing zone of the metering namespace."
}

variable "service_account_definition_version_ref" {
  type = object({
    uuid = string
  })
  nullable    = false
  description = "Version of the Kubernetes Service Account definition the metering deploys with."
}

variable "metering_building_block_definition_version_refs" {
  type = map(object({
    uuid = string
  }))
  nullable    = false
  description = "Versions of the metering definitions, keyed by the cloud name offered in `clouds`."
}

variable "schedule" {
  type        = string
  nullable    = false
  description = "Cron schedule of every metering job."
}
