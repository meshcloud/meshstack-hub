variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "project_identifier" {
  type        = string
  description = "The meshStack project identifier."
}

variable "parent_id" {
  description = "The ID of the parent resource."
  type        = string
}

variable "subfolder" {
  type        = string
  description = "The subfolder to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit."
}
