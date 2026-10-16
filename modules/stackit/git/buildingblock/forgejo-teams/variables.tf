variable "forgejo_host" {
  type        = string
  nullable    = false
  description = "Base URL of the Forgejo instance."
}

variable "forgejo_api_token" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Token of an owner of `organization`, used for the membership calls the restapi provider cannot track."
}

variable "organization" {
  type        = string
  nullable    = false
  description = "Forgejo organization the teams belong to."
}

variable "teams" {
  type = map(object({
    name                      = string
    description               = optional(string, "")
    permission                = string
    includes_all_repositories = optional(bool, false)
    units                     = optional(list(string), ["repo.code", "repo.issues", "repo.ext_issues", "repo.wiki", "repo.pulls", "repo.releases", "repo.projects", "repo.ext_wiki", "repo.actions", "repo.packages"])
    members                   = map(string)
  }))
  nullable    = false
  description = "Teams by a stable key. `permission` is `read`, `write`, `admin` or `owner`, which uses the organization's built-in Owners team. `members` maps a stable key to a Forgejo username; an empty username is skipped until it is known."

  validation {
    condition     = alltrue([for team in values(var.teams) : contains(["read", "write", "admin", "owner"], team.permission)])
    error_message = "Team permission must be `read`, `write`, `admin` or `owner`."
  }
}
