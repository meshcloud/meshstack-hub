variable "automation_identity" {
  type = object({
    building_block_ref    = object({ uuid = string })
    service_account_email = string
    service_account_id    = string
  })
  nullable    = false
  description = "Automation Identity building block and the STACKIT service account it created."
}

variable "service_account_federation_bbd_version_ref" {
  type        = object({ uuid = string })
  nullable    = false
  description = "STACKIT Service Account Federation definition version the landing zone offers."
}

variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the Kubernetes platform created in meshStack."
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Whether the ordering STACKIT Kubernetes Platform is a throwaway deployment."
}

variable "dns_parent_domain" {
  type        = string
  nullable    = false
  description = "Domain the platform's DNS zone is created under."
}

variable "dns_subdomain" {
  type        = string
  nullable    = false
  description = "Label the platform's DNS zone occupies under `dns_parent_domain`."
}

variable "cluster_issuer_email" {
  type        = string
  nullable    = false
  description = "Let's Encrypt contact email registered for the ACME ClusterIssuer and the DNS zone."
}

variable "phase2_completed" {
  type        = bool
  nullable    = false
  description = "Whether a Harbor robot is linked to the platform's service account; the run fails while none is."
}

variable "stages" {
  type = map(object({
    landingzone = optional(map(list(string)), {})
    project     = optional(map(list(string)), {})
    quotas = optional(list(object({
      key   = string
      value = number
    })))
  }))
  nullable    = false
  description = "Stages of the STACKIT Kubernetes Platform by name, with their tag maps and quotas."
}

variable "tags" {
  type = object({
    landingzone               = map(list(string))
    building_block            = map(list(string))
    starterkit_building_block = map(list(string))
    starterkit_project        = map(list(string))
    project_owner_tag_key     = optional(string)
  })
  nullable    = false
  description = "Tag maps of the STACKIT Kubernetes Platform, see its `tags` input. A null `project_owner_tag_key` sets no owner tag."
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
  description = "Run triggers that need an operator's approval on the platform definitions this run registers."
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
  description = "Run triggers that need an operator's approval on the application team definitions (Git repository, Forgejo connector, SKE starterkit) this run registers."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global meshStack location; false creates one for the platform."
}

variable "ai_model" {
  type        = string
  default     = null
  description = "Model applications default to. Must be one STACKIT Model Serving's `/v1/models` endpoint serves. Null sets up no Model Serving token and no `stackit-ai` secret."
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

variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the SKE cluster."
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

variable "imports" {
  type = object({
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
  description = "Existing resources the child building blocks of the same key take over, as in the STACKIT Kubernetes Platform's `imports`. Null takes over nothing."
}

variable "starterkit_add_random_name_suffix" {
  type        = bool
  nullable    = false
  description = "Append a random suffix to the projects the starterkit creates. Keep it as the adopted starterkit had it: an upgrade that changes it renames, and so replaces, every project and tenant it created."
}

variable "runner_ref" {
  type = object({
    kind = optional(string)
    uuid = optional(string)
  })
  nullable    = false
  description = "Runner to use for all definitions created by this building block. Set to `{}` to use the default shared runner."
}

variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the platform runs in."
}

variable "tenant_uuid" {
  type        = string
  nullable    = false
  description = "meshStack tenant of the STACKIT project, which every building block of this run is ordered for."
}

variable "workspace" {
  type        = string
  nullable    = false
  description = "meshStack workspace that owns the platform and the definitions this run registers."
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
  `bbd_draft`: Draft state of the application team definitions (starter kit, Git repository, Forgejo
  connector). The platform's own definitions are always drafts.
  EOT
}
