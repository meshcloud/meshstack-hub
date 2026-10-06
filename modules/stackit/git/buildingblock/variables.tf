variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the Git instance is created in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  description = "STACKIT region the Git instance is placed in."
}

variable "instance_name" {
  type        = string
  nullable    = false
  description = "First label of the instance hostname `<name>.git.onstackit.cloud`, globally unique across all of STACKIT."

  validation {
    # A hostname label: STACKIT publishes the instance as `<name>.git.onstackit.cloud`, so whatever
    # else the API accepts, a name that is not a valid DNS label cannot be reached.
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.instance_name))
    error_message = "instance_name must be a DNS label: lowercase alphanumeric or dashes, not starting or ending with a dash, at most 63 characters."
  }
}

variable "forgejo_organization" {
  type        = string
  nullable    = true
  description = "Forgejo organization to create inside the instance. Empty provisions the bare instance."
}

variable "local_user_username" {
  type        = string
  nullable    = false
  description = "Username of the technical user the module mints its token on."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,31}$", var.local_user_username))
    error_message = "local_user_username must be at most 32 characters of alphanumerics, dots, dashes or underscores, starting with an alphanumeric."
  }
}

variable "local_user_email" {
  type        = string
  nullable    = false
  description = "Email of the technical user. Leave empty to derive one from the instance hostname."
}

variable "local_user_token_name" {
  type        = string
  nullable    = false
  description = "Name of the Personal Access Token the module mints."
}

variable "local_user_token_scopes" {
  type        = list(string)
  nullable    = false
  description = "Forgejo scopes of the minted token."
}

variable "shared_runner_labels" {
  type        = list(string)
  nullable    = false
  description = "Labels of the STACKIT-hosted shared runner to order. Leave empty to order none."
}

variable "users" {
  description = "meshStack project members. Each user's `roles` are mapped to a Forgejo organization role via `role_mapping`."
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  nullable = false
}

variable "role_mapping" {
  type        = map(list(string))
  nullable    = false
  description = "Maps meshStack roles from `users[*].roles` to Forgejo organization roles: `owner`, `writer` or `reader`. The highest one wins; unknown meshStack roles are ignored."

  validation {
    condition     = alltrue([for role in flatten(values(var.role_mapping)) : contains(["owner", "writer", "reader"], role)])
    error_message = "role_mapping values must be `owner`, `writer` or `reader`."
  }
}

variable "output_to_vault" {
  type = object({
    address  = string
    mount    = string
    username = string
    password = string
    path     = string
  })
  default     = null
  sensitive   = true
  description = "Vault KV v2 secret this building block writes its secrets to: the server `address`, the engine `mount`, a userpass `username` and `password`, and the secret `path`. Null writes none."
}

variable "imports" {
  type = object({
    instance_id                     = string
    existing_forgejo_api_token_path = string
  })
  default     = null
  description = "Existing STACKIT Git instance and its Forgejo organization `forgejo_organization` this building block takes over instead of creating them. The instance's name must equal `instance_name`. `existing_forgejo_api_token_path` names the secret in the Vault of `output_to_vault` whose key `forgejo_api_token` holds a token of an owner of the organization. The technical user and the writer and reader teams then get a random suffix, no shared runner is ordered, and the organization is left in place on destroy. Null creates a new instance and organization."

  validation {
    condition     = var.imports == null || nonsensitive(var.output_to_vault != null)
    error_message = "imports needs output_to_vault, whose Vault holds the existing Forgejo API token."
  }

  validation {
    condition     = var.imports == null || coalesce(var.forgejo_organization, "") != ""
    error_message = "imports needs forgejo_organization, the organization it takes over."
  }
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  default     = false
  description = "Leave the instance in place when this building block is destroyed. Cannot change once the instance is managed."
}
