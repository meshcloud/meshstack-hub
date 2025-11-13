variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "region" {
  type        = string
  default     = "eu10"
  description = "The region of the subaccount."
}

variable "project_identifier" {
  type        = string
  description = "The meshStack project identifier."
}

variable "subfolder" {
  type        = string
  default     = ""
  description = "The subfolder name to use for the SAP BTP resources. This is used to create a folder structure in the SAP BTP cockpit. Mutually exclusive with parent_id."
}

variable "parent_id" {
  type        = string
  default     = ""
  description = "The parent directory ID for the subaccount. Use this when importing existing subaccounts. Mutually exclusive with subfolder."
}

variable "users" {
  type = list(object(
    {
      meshIdentifier = string
      username       = string
      firstName      = string
      lastName       = string
      email          = string
      euid           = string
      roles          = list(string)
    }
  ))
  description = "Users and their roles provided by meshStack"
  default     = []
}
