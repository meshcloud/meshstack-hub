variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the landing-zone folder and foundation project are left destroyable. Set to false for a platform that is actually used. Cannot change after the first run. A playground platform and the building block definitions it registers are not meant to be published to other workspaces."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global location instead of creating a dedicated location for this platform."
}

variable "stackit_org" {
  type        = string
  nullable    = false
  description = "STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.stackit_org))
    error_message = "stackit_org must be a valid UUID."
  }
}

variable "root_folder_name" {
  type        = string
  default     = null
  description = "Name of a folder at the organization root that holds the landing-zone folder and the foundation project, for an organization that serves more than one meshStack. Null puts the landing-zone folder at the organization root, except in playground mode, which names the folder `playground-<platform identifier>`."

  validation {
    condition     = var.root_folder_name == null ? true : length(var.root_folder_name) <= 63
    error_message = "root_folder_name must be at most 63 characters."
  }
}

variable "stackit_service_account_key" {
  type        = string
  sensitive   = true
  ephemeral   = true
  nullable    = false
  description = "Key JSON of the deployment service account, which needs `resource-manager.admin` on the organization. Used to create the landing-zone folder and foundation project."
}

variable "stackit_owner_email" {
  type        = string
  nullable    = false
  description = "Owner email assigned to the STACKIT resourcemanager folder, the foundation project, and every tenant project the platform creates. Must be the deployment service account's own email unless the deployment service account is an organization owner."
}

variable "topology" {
  type        = list(string)
  nullable    = false
  description = "Landing zone labels to deploy and offer application teams. `sandbox` deploys the sandbox landing zone; `hub&spoke` also provisions the hub-and-spoke networking. The starterkit defaults to `sandbox` when selected, else `hub&spoke`."

  validation {
    condition     = length(var.topology) > 0 && alltrue([for t in var.topology : contains(["sandbox", "hub&spoke"], t)])
    error_message = "topology must be a non-empty subset of [\"sandbox\", \"hub&spoke\"]."
  }
}

variable "network" {
  type = object({
    hub_network_area_name            = optional(string, "hub")
    hub_network_ranges               = optional(list(string), ["10.0.0.0/16"])
    hub_transfer_network             = optional(string, "10.1.255.0/24")
    hub_min_prefix_length            = optional(number, 24)
    hub_max_prefix_length            = optional(number, 28)
    hub_default_prefix_length        = optional(number, 28)
    hub_default_nameservers          = optional(list(string), [])
    tenant_network_min_prefix_length = optional(number, 24)
    tenant_network_max_prefix_length = optional(number, 28)
  })
  default     = null
  description = "Hub-and-spoke address plan, read only when `topology` includes `hub&spoke`. Otherwise the input is hidden and meshStack sends no value."
}

variable "role_mapping" {
  type = object({
    admin                   = list(string)
    user                    = list(string)
    reader                  = list(string)
    organization_onboarding = optional(bool, true)
  })
  nullable    = false
  description = <<-EOT
  Default mapping from meshStack roles to STACKIT project roles for the nested STACKIT Project integration. Values can be built-in STACKIT roles or custom STACKIT role names.
  `organization_onboarding` adds meshStack project users to the STACKIT organization before the project roles are granted. Turn it off if organization membership is managed outside this landing zone.
  EOT
}

variable "tags" {
  type = object({
    landingzone           = list(object({ key = string, values = list(string) }))
    building_block        = list(object({ key = string, values = list(string) }))
    project               = list(object({ key = string, values = list(string) }))
    project_owner_tag_key = optional(string)
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested STACKIT integrations, each map built in the meshPanel form as a list of {key, values} entries.
  `landingzone` tags are applied to the created landing zones.
  `building_block` tags are applied to the nested building block definitions.
  `project` tags are applied to the meshProjects the starterkit creates.
  `project_owner_tag_key` names the tag that receives the creator's display name; null or empty sets none.
  EOT
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
  description = "Run triggers that need an operator's approval before a run of the project starterkit is applied. The defaults are the provider's own, and the provider asserts them whenever the definition sets no policies — so a gate switched on in meshPanel is turned off again by the next run unless it is set here. Ignored in playground mode, which gates nothing."

  validation {
    condition     = var.playground_mode || var.starterkit_approval_policies != null
    error_message = "starterkit_approval_policies is required unless playground_mode is set."
  }
}

variable "imports" {
  type = object({
    folder = optional(object({
      container_id = string
    }))
    foundation_project = optional(object({
      container_id = string
    }))
    adopt_platform = optional(bool, false)
    project_definition = optional(object({
      uuid                            = string
      service_account_name            = string
      service_account_email           = string
      federated_identity_provider_ids = list(string)
    }))
    service_account_definition = optional(object({
      uuid                            = string
      service_account_email           = string
      federated_identity_provider_ids = list(string)
    }))
    service_account_federation_definition = optional(object({
      uuid                            = string
      service_account_email           = string
      federated_identity_provider_ids = list(string)
    }))
  })
  default     = null
  description = "Existing resources to take over, by key; see Adopting an Existing Platform in the README. Null creates everything."

  validation {
    condition     = var.imports == null || !var.playground_mode
    error_message = "imports needs playground_mode = false: nothing taken over is released on destroy."
  }

  validation {
    condition     = var.imports == null ? true : alltrue([for key, adopted in var.imports : adopted == null || contains(["folder", "adopt_platform"], key) || var.imports.foundation_project != null])
    error_message = "imports.project_definition, service_account_definition and service_account_federation_definition need imports.foundation_project, because their service accounts live in it."
  }
}

variable "runner_ref" {
  type = object({
    kind = optional(string)
    uuid = optional(string)
  })
  nullable    = false
  description = "Runner to use for all definitions created by this building block. Set to `{}` to use the default shared runner."
}

variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that will own the created platform, location, landing zones, and (when networking is enabled) the hub network-area instance."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested foundation, network-area, and network integration modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Draft state of the definitions this landing zone registers; the landing zone's own definition is always a draft.
  EOT
}
