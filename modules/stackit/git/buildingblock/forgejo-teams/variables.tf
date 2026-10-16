variable "organization" {
  type        = string
  nullable    = true
  description = "Forgejo organization the teams belong to. Required when `teams` is not empty."

  validation {
    condition     = var.organization != null || length(var.teams) == 0
    error_message = "organization is required when teams is not empty."
  }
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
  description = "Teams by a stable key. `permission` is `read`, `write`, `admin` or `owner`, which uses the organization's built-in Owners team. `members` maps a stable key to a Forgejo username; an empty username is skipped."

  validation {
    condition     = alltrue([for team in values(var.teams) : contains(["read", "write", "admin", "owner"], team.permission)])
    error_message = "Team permission must be `read`, `write`, `admin` or `owner`."
  }
}
