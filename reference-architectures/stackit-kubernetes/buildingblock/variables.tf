variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the Kubernetes platform created in meshStack (letters, digits and dashes only). In playground mode a random suffix is appended to it."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "phase2_completed" {
  type        = bool
  nullable    = false
  description = "Set to true once a Harbor robot is linked to the platform's service account, as the summary describes; the run fails while none is."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global meshStack location instead of creating a dedicated one for this platform."
}

variable "payment_method" {
  type = object({
    kind = string
    name = string
  })
  nullable    = false
  description = "Payment method of the platform's own meshProject."
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform that gets a random identifier suffix and stays destroyable. Cannot change after the first run."
}

variable "landingzone" {
  type = object({
    platform_ref                               = object({ uuid = string })
    landingzone_refs                           = map(object({ name = string }))
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

variable "starterkit_add_random_name_suffix" {
  type        = bool
  default     = null
  description = "Append a random suffix to the projects the starterkit creates. Cannot change after the first run: it renames, and so replaces, every project and tenant the starterkit created. Ignored in playground mode, which always appends one."

  validation {
    condition     = var.playground_mode || var.starterkit_add_random_name_suffix != null
    error_message = "starterkit_add_random_name_suffix is required unless playground_mode is set."
  }
}

variable "starterkit_demo" {
  type = object({
    name          = string
    template_repo = string
    ai_model      = optional(string)
  })
  nullable    = false
  description = <<-EOT
  Demo application the starter kit deploys.
  `name`: image name every application ordered from the starter kit builds under, set as APP_NAME.
  `template_repo`: template repository the starter kit initialises an application repository from.
  `ai_model`: model applications default to, one STACKIT Model Serving's `/v1/models` endpoint serves; null sets up no Model Serving token and no `stackit-ai` secret.
  EOT
}

variable "dns_domain" {
  type        = string
  default     = null
  description = "DNS zone of the platform under a free STACKIT domain: a bare one such as `stackit.run` gives `<platform identifier>.stackit.run`, one label more such as `likvid.stackit.run` is the zone itself. Ignored in playground mode, which uses `stackit.run`."

  validation {
    condition     = var.playground_mode || var.dns_domain != null
    error_message = "dns_domain is required unless playground_mode is set."
  }

  validation {
    condition     = var.dns_domain == null || can(regex("^([a-z0-9]([a-z0-9-]{0,18}[a-z0-9])?\\.)?(stackit\\.(run|zone|rocks|gg)|runs\\.onstackit\\.cloud)$", var.dns_domain))
    error_message = "dns_domain must be stackit.run, stackit.zone, stackit.rocks, stackit.gg or runs.onstackit.cloud, optionally with one label of at most 20 lowercase letters, digits or dashes in front."
  }
}

variable "stages" {
  type = list(object({
    name        = string
    landingzone = list(object({ key = string, values = list(string) }))
    project     = list(object({ key = string, values = list(string) }))
    quotas = optional(list(object({
      key   = string
      value = number
    })))
  }))
  nullable    = false
  description = "Stages, each with one landing zone and one starter kit meshProject and namespace. Their `landingzone` and `project` tags are merged over `tags.landingzone` and `tags.starterkit_project`. `quotas` sets the landing zone's quotas; null keeps the defaults of the `kubernetes` hub module, the larger set for `prod`."

  validation {
    condition     = length(distinct([for stage in var.stages : stage.name])) == length(var.stages)
    error_message = "Every stage needs a name of its own."
  }
}

variable "quota_definitions" {
  type = list(object({
    quota_key               = string
    label                   = string
    description             = string
    unit                    = string
    min_value               = number
    max_value               = number
    auto_approval_threshold = number
  }))
  default     = null
  description = "Quotas the meshPlatform offers, with their limits; null keeps the defaults of the `kubernetes` hub module. CPU in millicores (m), memory in mebibytes (Mi)."
}

variable "tags" {
  type = object({
    landingzone               = list(object({ key = string, values = list(string) }))
    building_block            = list(object({ key = string, values = list(string) }))
    starterkit_building_block = list(object({ key = string, values = list(string) }))
    project                   = list(object({ key = string, values = list(string) }))
    starterkit_project        = list(object({ key = string, values = list(string) }))
    project_owner_tag_key     = optional(string)
  })
  nullable    = false
  description = <<-EOT
  Tags shared by every stage, each map built in the meshPanel form as a list of {key, values} entries.
  `landingzone` goes on the SKE landing zones, `building_block` on the definitions platform engineers order,
  `starterkit_building_block` on those application teams order (Git repository, Forgejo connector, SKE starterkit),
  `project` on the platform's meshProject and `starterkit_project` on the starter kit's meshProjects.
  `project_owner_tag_key` names the tag on those meshProjects that gets the creator's display name; null sets none.
  EOT
}

variable "overrides" {
  type = object({
    cluster_name         = optional(string)
    cluster_issuer_email = optional(string)
    project_identifier   = optional(string)
  })
  default     = null
  description = <<-EOT
  Names and settings that replace the generated ones; null or a field left out keeps the default.
  `cluster_name`: SKE cluster name, 2-11 chars, lowercase alphanumeric or dashes; the default derives from the platform identifier.
  `cluster_issuer_email`: Let's Encrypt contact email of the ACME ClusterIssuer; the default is the platform's service account.
  `project_identifier`: identifier of the platform's meshProject; the default is `<platform identifier>-ske`.
  EOT

  validation {
    condition     = (var.overrides == null ? null : var.overrides.cluster_name) == null ? true : can(regex("^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$", var.overrides.cluster_name))
    error_message = "overrides.cluster_name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "approval_policies" {
  type = object({
    building_block_creation = bool
    user_input_changes      = bool
    any_input_changes       = bool
    manual_triggers         = bool
    version_upgrade         = bool
  })
  default     = null
  description = "Run triggers that need an operator's approval on the platform definitions this architecture registers. Ignored in playground mode, which gates nothing."

  validation {
    condition     = var.playground_mode || var.approval_policies != null
    error_message = "approval_policies is required unless playground_mode is set."
  }
}

variable "starterkit_approval_policies" {
  type = object({
    building_block_creation = bool
    user_input_changes      = bool
    any_input_changes       = bool
    manual_triggers         = bool
    version_upgrade         = bool
  })
  default     = null
  description = "Run triggers that need an operator's approval on the application team definitions (Git repository, Forgejo connector, SKE starterkit) this architecture registers. Ignored in playground mode, which gates nothing."

  validation {
    condition     = var.playground_mode || var.starterkit_approval_policies != null
    error_message = "starterkit_approval_policies is required unless playground_mode is set."
  }
}

variable "imports" {
  type = object({
    project = optional(object({
      display_name   = optional(string)
      admin_bindings = optional(map(string), {})
    }))
    adopt_ske = optional(bool, false)
    git = optional(object({
      instance_id          = string
      instance_name        = string
      forgejo_organization = string
    }))
    dns = optional(object({
      zone_id       = string
      record_set_id = string
    }))
    adopt_ingress = optional(bool, false)
    secrets_manager = optional(object({
      instance_id = string
    }))
    container_registry = optional(object({
      artifactory_id = string
      registry_name  = string
    }))
    kubernetes_platform = optional(object({
      platform_name     = optional(string)
      location_name     = optional(string)
      landingzone_names = optional(map(string), {})
    }))
    starterkit_definitions = optional(object({
      starterkit        = optional(string)
      git_repository    = optional(string)
      forgejo_connector = optional(string)
    }))
  })
  default     = null
  description = "Existing resources and definitions to take over, by key; see Adopting Existing Resources in the README. `git` needs `import_secrets.git` on its first run; null creates everything."

  validation {
    condition     = var.imports == null || var.imports.project != null || alltrue([for key, adopted in var.imports : adopted == null || adopted == false if key != "starterkit_definitions"])
    error_message = "Every key of imports but starterkit_definitions needs imports.project, because what it names lives in that project."
  }

  validation {
    condition     = var.imports == null || (!var.imports.adopt_ingress && var.imports.kubernetes_platform == null) || var.imports.adopt_ske
    error_message = "imports.adopt_ingress and imports.kubernetes_platform need imports.adopt_ske, because they live in that cluster."
  }

  validation {
    condition     = (var.imports == null ? null : var.imports.kubernetes_platform) == null ? true : length(var.imports.kubernetes_platform.landingzone_names) == 0 || var.imports.kubernetes_platform.platform_name != null
    error_message = "imports.kubernetes_platform.landingzone_names needs imports.kubernetes_platform.platform_name, because the landing zones belong to that platform."
  }

  validation {
    condition     = (var.imports == null ? null : var.imports.kubernetes_platform) == null ? true : var.imports.kubernetes_platform.platform_name == null || var.imports.kubernetes_platform.location_name != null || var.use_global_location
    error_message = "imports.kubernetes_platform.platform_name needs imports.kubernetes_platform.location_name or use_global_location, because the platform exists in a location already."
  }

  # The meshPlatform and the definitions have no release on destroy, so a playground would delete them.
  validation {
    condition     = !var.playground_mode || ((var.imports == null ? null : var.imports.kubernetes_platform) == null ? true : var.imports.kubernetes_platform.platform_name == null)
    error_message = "imports.kubernetes_platform.platform_name needs playground_mode = false."
  }

  validation {
    condition     = !var.playground_mode || (var.imports == null ? null : var.imports.starterkit_definitions) == null
    error_message = "imports.starterkit_definitions needs playground_mode = false."
  }
}

variable "import_secrets" {
  type = object({
    git = optional(object({
      forgejo_api_token = string
    }))
  })
  sensitive   = true
  default     = null
  description = "Secrets of the resources in `imports`: `git.forgejo_api_token`, a token of an owner of the adopted Forgejo organization, needed until the organization is adopted."
}

variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the platform, location, landing zones, STACKIT project and the building block definitions this architecture registers."
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

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference the nested integrations are sourced from.
  `bbd_draft`: Draft state of the application team definitions; the platform's own are always drafts.
  EOT
}
