variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  description = "Information about the creator of the resources who will be assigned Project Admin role"
}

variable "name" {
  type        = string
  description = "This name will be used for the created projects, the GitHub repository and the app hostnames."
}

variable "workspace_identifier" {
  type = string
}

variable "platform_ref" {
  type = object({
    uuid = string
    kind = optional(string, "meshPlatform")
  })
  description = "Reference (by uuid) to the meshPlatform the tenants are created on. Wired in as a static building block input from the platform/backplane that owns the meshPlatform (its `.ref` output). Required because the meshTenant v4 API references platforms by ref."
}

variable "landing_zone_refs" {
  type        = map(object({ name = string, kind = optional(string, "meshLandingZone") }))
  description = "Landing zone references keyed by stage. The keys decide which stages this starter kit creates. Wired in as a static building block input from the platform/backplane that owns the meshLandingZones (their `.ref` outputs)."
}

variable "project_tags" {
  type = object({
    stages        = map(map(list(string)))
    owner_tag_key = optional(string, null)
  })
  description = "Tags for the created meshProjects. `stages` is keyed as `landing_zone_refs`; `owner_tag_key` names the tag that receives the creator's display name."
}

variable "building_block_definition_version_refs" {
  type = map(object({
    uuid = string
  }))
  description = "Building block definition versions this starter kit creates its child building blocks from, keyed by definition name (`git-repository` and `github-actions-connector`)."
}

variable "github_org" {
  type        = string
  description = "GitHub organization the repository is created in. Used for display only."
}

variable "github_template_repo_path" {
  type        = string
  description = "Template repository the application repository is created from, as `owner/repo`."
}

variable "repo_admin" {
  type        = string
  default     = null
  description = "GitHub handle that becomes admin of the repository. `null` or the string `\"null\"` adds no one."
}

variable "apps_domain" {
  type        = string
  description = "Wildcard domain of the cluster's default router, under which the app hostnames are created (example: `apps.ocp.example.com`)."
}

variable "add_random_name_suffix" {
  type        = bool
  description = "Whether to append a random suffix to the name, so the same name can be ordered more than once on a shared cluster."
}
