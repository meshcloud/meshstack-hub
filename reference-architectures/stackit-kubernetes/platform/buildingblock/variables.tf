variable "automation_identity" {
  type = object({
    building_block_ref    = object({ kind = string, uuid = string })
    service_account_email = string
    service_account_id    = string
  })
  nullable    = false
  description = "The Automation Identity building block, the parent of the federations this run orders, and the STACKIT service account it created."
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
  description = "Identifier of the meshStack workspace that owns the platform, its location, its landing zones and the definitions this run registers."
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

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global meshStack location instead of creating a dedicated one for the platform."
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

variable "harbor_username" {
  type        = string
  nullable    = false
  default     = ""
  description = "Name of the Harbor robot linked to the platform's STACKIT service account, empty until it exists."
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
  description = "Run triggers that need an operator's approval before a run of a platform definition this run registers is applied."
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
  description = "Run triggers that need an operator's approval before a run of the Git repository, Forgejo connector or SKE starterkit definition this run registers is applied."
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
