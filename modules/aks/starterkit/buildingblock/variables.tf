variable "workspace_identifier" {
  type = string
}

variable "name" {
  type        = string
  description = "This name will be used for the created namespaces, app subdomain and GitHub repository."
}

variable "building_block_definition_version_refs" {
  # The input of the same name in meshstack_integration.tf fills this in; rename both together.
  type = map(object({
    uuid = string
  }))
  description = "Building block definition versions this starter kit creates its child building blocks from, keyed by definition name (`git-repository`, `aks-namespace` and `github-actions-connector`)."
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

variable "repo_admin" {
  type        = string
  description = "GitHub handle of the user who will be assigned as the repository admin. Delete building block definition input if not needed."
  default     = null
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
