variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "subaccount_id" {
  type        = string
  description = "The ID of the subaccount where Cloud Foundry should be enabled."
}

variable "project_identifier" {
  type        = string
  description = "The meshStack project identifier (used for CF environment naming)."
}

variable "cloudfoundry_plan" {
  type        = string
  default     = "standard"
  description = "Cloud Foundry environment plan (standard, free, or trial)"
}

variable "cf_services" {
  type        = string
  default     = ""
  description = "Comma-separated list of Cloud Foundry service instances in format: service.plan (e.g., 'postgresql.small,destination.lite,redis.medium')"
}
