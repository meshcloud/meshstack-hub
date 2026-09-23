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
  nullable    = false
  description = "Payment method identifier assigned to the platform's meshProject."
}

variable "tags" {
  type = object({
    landingzone           = map(list(string))
    building_block        = map(list(string))
    project               = map(list(string))
    project_owner_tag_key = optional(string, "")
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested integrations, and shared by every stage.
  `landingzone` tags are applied to the created SKE landing zones. Include every tag a tag policy matches against a project tag, or no tenant can be created on them.
  `building_block` tags are applied to the nested building block definitions.
  `project` tags are applied to the platform's meshProject and to the meshProjects the starter kit creates.
  `project_owner_tag_key` names the tag that receives the creator's display name on the platform's meshProject (empty to set none). Set it to the mandatory owner tag your meshStack enforces (e.g. `projectOwner`).
  EOT
}

variable "stages" {
  type = map(object({
    landingzone = optional(map(list(string)), {})
    project     = optional(map(list(string)), {})
  }))
  nullable    = false
  description = <<-EOT
  Stages the platform offers. The map keys name them, and one landing zone is created per key, so a platform can offer fewer or more than the usual `dev` and `prod`. The starter kit creates one meshProject and one namespace per key.
  `landingzone` and `project` carry the tags whose value differs between stages. They are merged over the matching map in `tags`, and over the `environment` tag the stage gets from its key.
  A tag policy pairs a landing zone tag with a project tag, so such a tag belongs here on both sides at once.
  EOT
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
  description = "Creator of the platform, injected by meshStack. They become Project Admin of the platform's meshProject, and their display name is written to its owner tag (see `tags.project_owner_tag_key`)."
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

variable "harbor_username" {
  type        = string
  nullable    = true
  default     = null
  description = "Name of the Harbor robot linked to this platform's STACKIT service account, empty until it exists."
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
