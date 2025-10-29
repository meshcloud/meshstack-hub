variable "name" {
  description = "Name of the building block"
  type        = string
}

variable "scope" {
  description = "Scope for the role assignment"
  type        = string
}

variable "principal_ids" {
  description = "Principal IDs to assign the role to"
  type        = set(string)
}