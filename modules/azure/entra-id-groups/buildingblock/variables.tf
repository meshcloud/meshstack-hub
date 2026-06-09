variable "prefix" {
  type        = string
  default     = ""
  description = "Optional prefix prepended to all group display names. Leave empty to omit."
}

variable "workspace_identifier" {
  type        = string
  description = "meshStack workspace identifier included in the group name."
}

variable "project_identifier" {
  type        = string
  description = "meshStack project identifier included in the group name."
}

variable "project_roles" {
  type        = string
  default     = "admin,user,reader"
  description = "Comma-separated list of project role name suffixes. One Entra group is created per role. Defaults to the three standard meshStack roles: admin, user, reader."
}

variable "administrative_unit_id" {
  type        = string
  default     = ""
  description = "Object ID of the Entra Administrative Unit to add the groups to. Leave empty to skip AU membership."
}
