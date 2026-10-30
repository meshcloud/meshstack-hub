variable "landingzone" {
  type = object({
    platform_ref                               = object({ uuid = string, kind = string })
    landingzone_refs                           = map(object({ name = string, kind = string }))
    service_account_bbd_version_ref            = object({ uuid = string })
    service_account_federation_bbd_version_ref = object({ uuid = string })
  })
  nullable    = false
  description = "Refs from the summary of the STACKIT Landing Zone building block this platform is built on."
}

variable "landingzone_variant" {
  type        = string
  nullable    = false
  description = "Key into `landingzone.landingzone_refs`. `networked` requires hub-and-spoke networking enabled on the landing zone."

  validation {
    condition     = contains(["default", "networked"], var.landingzone_variant)
    error_message = "landingzone_variant must be either default or networked."
  }
}

variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the platform, location, landing zones, STACKIT project and the building block definitions this architecture registers."
}

variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the Kubernetes platform created in meshStack (letters, digits and dashes only). In playground mode a random suffix is appended to it."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global meshStack location instead of creating a dedicated one for this platform."
}

variable "payment_method_identifier" {
  type        = string
  default     = null
  description = "Payment method identifier assigned to the platform's meshProject. Null assigns none."
}

variable "project_identifier" {
  type        = string
  default     = null
  description = "Identifier of the platform's meshProject; null uses `<platform identifier>-ske`."
}

variable "tags" {
  type = object({
    landingzone           = map(list(string))
    building_block        = map(list(string))
    project               = map(list(string))
    starterkit_project    = map(list(string))
    project_owner_tag_key = optional(string, "")
  })
  nullable    = false
  description = "Tags shared by every stage: `landingzone` on the SKE landing zones, `building_block` on the nested definitions, `project` on the platform's meshProject and `starterkit_project` on the starter kit's meshProjects. `project_owner_tag_key` names the tag on those meshProjects that gets the creator's display name, e.g. `projectOwner`."
}

variable "stages" {
  type = map(object({
    landingzone = optional(map(list(string)), {})
    project     = optional(map(list(string)), {})
  }))
  nullable    = false
  description = "Stages by name, each with one landing zone and one starter kit meshProject and namespace. Their `landingzone` and `project` tags are merged over `tags.landingzone`, `tags.starterkit_project` and the `environment` tag of the key."
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
  nullable    = false
  description = "Creator of the platform, injected by meshStack; its display name fills the `tags.project_owner_tag_key` tag."
}

variable "workspace_members" {
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  nullable    = false
  description = "Members of the owning workspace, injected by meshStack. Owners and managers become Project Admin of the platform's project."
}

variable "approval_policies" {
  type = object({
    building_block_creation = bool
    user_input_changes      = bool
    any_input_changes       = bool
    manual_triggers         = bool
    version_upgrade         = bool
  })
  nullable    = false
  description = "Run triggers that need an operator's approval on the platform definitions this architecture registers."
}

variable "starterkit_approval_policies" {
  type = object({
    building_block_creation = bool
    user_input_changes      = bool
    any_input_changes       = bool
    manual_triggers         = bool
    version_upgrade         = bool
  })
  nullable    = false
  description = "Run triggers that need an operator's approval on the application team definitions (Git repository, Forgejo connector, SKE starterkit) this architecture registers."
}

variable "platform_engineer_role_mapping" {
  type = object({
    git                = optional(map(list(string)))
    container_registry = optional(map(list(string)))
    secrets_manager    = optional(map(list(string)))
  })
  nullable    = false
  default     = {}
  description = "Maps the meshStack project roles on the platform's project to roles on the Git instance (Forgejo `owner`, `writer`, `reader`), the container registry and the Secrets Manager (STACKIT project roles). A service left out keeps its module's default: Project Admins become Forgejo owners, registry admins and Secrets Manager readers."
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform that gets a random identifier suffix and stays destroyable."
}

variable "cluster_name" {
  type        = string
  nullable    = true
  default     = null
  description = "Overrides the generated SKE cluster name. 2-11 chars, lowercase alphanumeric or dashes."

  validation {
    condition     = var.cluster_name == null || var.cluster_name == "" || can(regex("^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "cluster_issuer_email" {
  type        = string
  nullable    = true
  default     = null
  description = "Overrides the Let's Encrypt contact email registered for the ACME ClusterIssuer."
}

variable "dns_subdomain" {
  type        = string
  nullable    = true
  default     = null
  description = "Label the platform's DNS zone occupies under `dns_parent_domain`. Empty uses the platform identifier. Set it to adopt a zone that already carries a different name."
}

variable "dns_parent_domain" {
  type        = string
  nullable    = false
  description = "Domain the platform's DNS zone is created under."
}

variable "phase2_completed" {
  type        = bool
  nullable    = false
  default     = false
  description = "Set to true once a Harbor robot is linked to the platform's service account, as the summary describes; the run fails while none is."
}

variable "ai_model" {
  type        = string
  nullable    = false
  description = "Model applications default to. Must be one STACKIT Model Serving's `/v1/models` endpoint serves."
}

variable "starterkit_app_name" {
  type        = string
  nullable    = false
  description = "Image name every application ordered from the starter kit builds under, set as APP_NAME."
}

variable "starterkit_repo_clone_addr" {
  type        = string
  nullable    = false
  description = "Template repository the starter kit initialises an application repository from."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference the nested integrations are sourced from.
  `bbd_draft`: Forwarded to the nested integrations' `hub.bbd_draft`.
  EOT
}

variable "imports" {
  type = object({
    project = optional(object({
      display_name   = optional(string)
      admin_bindings = optional(map(string), {})
    }))
    ske = optional(object({}))
    git = optional(object({
      instance_id          = string
      instance_name        = string
      forgejo_organization = string
    }))
    dns = optional(object({
      zone_id       = string
      record_set_id = string
    }))
    ingress = optional(object({}))
    secrets_manager = optional(object({
      instance_id = string
    }))
    container_registry = optional(object({
      artifactory_id = string
      registry_name  = string
    }))
    kubernetes_platform = optional(object({}))
  })
  default     = null
  description = "Existing resources to take over, by key; see Adopting Existing Resources in the README. `git` needs `import_secrets.git`; null creates everything."

  validation {
    condition     = var.imports == null || var.imports.project != null || alltrue([for key, adopted in var.imports : adopted == null])
    error_message = "Every key of imports needs imports.project, because what it names lives in that project."
  }

  validation {
    condition     = var.imports == null || (var.imports.ingress == null && var.imports.kubernetes_platform == null) || var.imports.ske != null
    error_message = "imports.ingress and imports.kubernetes_platform need imports.ske, because they live in that cluster."
  }

  validation {
    condition     = var.imports == null || var.imports.git == null || nonsensitive(var.import_secrets.git != null)
    error_message = "imports.git needs import_secrets.git, the Forgejo API token of an owner of the organization."
  }
}

variable "import_secrets" {
  type = object({
    git = optional(object({
      forgejo_api_token = string
    }))
  })
  nullable    = false
  default     = {}
  sensitive   = true
  description = "Secrets of the resources in `imports`: `git.forgejo_api_token`, a token of an owner of the adopted Forgejo organization."
}
