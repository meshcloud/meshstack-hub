variable "automation_identity" {
  type = object({
    building_block_ref    = object({ kind = string, uuid = string })
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

variable "imports" {
  type = object({
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
  nullable    = false
  default     = {}
  description = "Existing resources the child building blocks of the same key take over, as in the STACKIT Kubernetes Platform's `imports`."
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
  description = "Secrets of the resources in `imports`, written to the platform's Secrets Manager: `git.forgejo_api_token`, a token of an owner of the adopted Forgejo organization, needed until the Git building block's technical user is an owner."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global meshStack location; false creates one for the platform."
}

variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the SKE cluster."
}

variable "cluster_issuer_email" {
  type        = string
  nullable    = false
  description = "Let's Encrypt contact email registered for the ACME ClusterIssuer and the DNS zone."
}

variable "dns_subdomain" {
  type        = string
  nullable    = false
  description = "Label the platform's DNS zone occupies under `dns_parent_domain`."
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
  description = "Whether a Harbor robot is linked to the platform's service account; the run fails while none is."
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

variable "tags" {
  type = object({
    landingzone           = map(list(string))
    building_block        = map(list(string))
    starterkit_project    = map(list(string))
    project_owner_tag_key = optional(string, "")
  })
  nullable    = false
  description = "Tags of the STACKIT Kubernetes Platform, see its `tags` input."
}

variable "stages" {
  type = map(object({
    landingzone = optional(map(list(string)), {})
    project     = optional(map(list(string)), {})
  }))
  nullable    = false
  description = "Stages of the STACKIT Kubernetes Platform, see its `stages` input."
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
