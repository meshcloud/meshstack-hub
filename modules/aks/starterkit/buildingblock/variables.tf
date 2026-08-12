variable "workspace_identifier" {
  type = string
}

variable "name" {
  type        = string
  description = "This name will be used for the created projects, app subdomain and GitHub repository."
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
  description = "Landing zone references keyed by stage (usually dev and prod). Wired in as a static building block input from the platform/backplane that owns the meshLandingZones (their `.ref` outputs)."
}

variable "building_block_definition_version_refs" {
  # meshStack passes this map as a static building block input; the matching input in
  # meshstack_integration.tf of the parent module carries the same name.
  type = map(object({
    uuid = string
  }))
  description = "Building block definition version references for the child building blocks this starter kit creates, keyed by definition name (`git-repository` and `github-actions-connector`). The definition uuid is not part of this map, because meshStack derives the definition of a parent building block from the building block ref."
}

variable "github_repo_input_repo_visibility" {
  type        = string
  description = "Visibility of the GitHub repository (e.g., public, private)."
  default     = "private"
}

variable "archive_repo_on_destroy" {
  type        = bool
  description = "Whether to archive github repository when destroying the terraform resource, or delete it. Defaults to true (archive)."
  default     = true
}

variable "github_org" {
  type        = string
  description = "GitHub organization name. Used only for display purposes."
}

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

variable "repo_admin" {
  type        = string
  description = "GitHub handle of the user who will be assigned as the repository admin. Delete building block definition input if not needed."
  default     = null
}

variable "project_tags" {
  type = object({
    dev  = map(list(string))
    prod = map(list(string))

    owner_tag_key = optional(string, null)
  })
  description = "Tags for the created Dev/Prod projects."
}
variable "github_template_repo_path" {
  type        = string
  description = "GitHub repository template to use when creating the application repository, in the format 'owner/repo'."
  default     = "likvid-bank/aks-starterkit-template"
}

variable "apps_base_domain" {
  type        = string
  description = "Base domain used for application URLs (e.g. 'likvid-k8s.msh.host'). The app subdomain will be prefixed to this value."
  default     = "likvid-k8s.msh.host"
}