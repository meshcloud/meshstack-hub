variable "duration_days" {
  type        = number
  nullable    = false
  description = "How many days the group keeps its role on the workspace, counted from the first run of this building block."
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the workspace the group is bound to. meshStack fills it in with the workspace the building block is ordered in."
}

variable "group_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack group that gets the role on the workspace. Not its display name."
}

variable "workspace_role_name" {
  type        = string
  nullable    = false
  description = "meshStack workspace role granted to the group, e.g. `Workspace Member`."
}

variable "max_duration_days" {
  type        = number
  nullable    = false
  description = "Longest duration an orderer may ask for. A longer one fails the run before anything is bound."
}

variable "allowed_workspace_identifiers" {
  type        = list(string)
  nullable    = false
  description = "Workspaces this building block may grant access to. A run in any other workspace fails before anything is bound. Empty allows every workspace."
}
