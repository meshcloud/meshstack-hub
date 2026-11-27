variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the STACKIT platform created in meshStack, and prefix of its landing zones (letters, digits and dashes only)."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the STACKIT Project definition gets the platform identifier appended to its name. Cannot change after the first run. Publish a playground platform or its definition only to test, and delete the playground afterwards."
}

variable "landing_zone_tfvars" {
  type        = string
  nullable    = false
  description = "The tfvars file the STACKIT Landing Zone Configurator exports, unchanged. Its values are the accelerator's inputs."

  validation {
    condition     = can(provider::terraform::decode_tfvars(var.landing_zone_tfvars))
    error_message = "landing_zone_tfvars must be a tfvars file with literal values only."
  }

  validation {
    condition = !can(provider::terraform::decode_tfvars(var.landing_zone_tfvars)) || alltrue([
      for id, keys in { for key in keys(lookup(provider::terraform::decode_tfvars(var.landing_zone_tfvars), "landing_zones", {})) : trim(replace(lower(key), "/[^a-z0-9]+/", "-"), "-") => key... } : id != "" && length(keys) == 1
    ])
    error_message = "Every key of landing_zones must keep a letter or digit and stay distinct once lowercased with each run of other characters turned into a dash, because it becomes a meshStack landing zone identifier."
  }

  validation {
    condition = !can(provider::terraform::decode_tfvars(var.landing_zone_tfvars)) || length(setsubtract(keys(provider::terraform::decode_tfvars(var.landing_zone_tfvars)), [
      "audit_logs", "company_code", "company_name", "connectivity", "connectivity_regions", "devops", "federated_identity_providers",
      "firewall_config", "labels", "landing_zone_namespace_services", "landing_zones", "observability", "organization_auditors",
      "organization_id", "organization_owners", "owner_email", "platform_contract_namespace", "platform_kubernetes", "region",
      "rm_folder_parent_id", "rm_folders", "sandboxes",
    ])) == 0
    error_message = "landing_zone_tfvars sets an accelerator input this building block does not pass on, such as a firewall credential or bucket_naming."
  }
}

variable "accelerator_ref" {
  type        = string
  nullable    = false
  const       = true
  default     = "v2.3.0"
  description = "Git ref of github.com/stackitcloud/stackit-landing-zone whose `src/` the run applies: a tag such as `v2.3.0`, a branch or a commit. The export's `Accelerator source` header names the commit it was made for; another ref works when the export's variables fit that version. `const` so it can be interpolated into the module source at init time."
}

variable "tags" {
  type = object({
    landingzone    = list(object({ key = string, values = list(string) }))
    building_block = list(object({ key = string, values = list(string) }))
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested STACKIT integration, each map built in the meshPanel form as a list of {key, values} entries.
  `landingzone` tags are applied to the created landing zones.
  `building_block` tags are applied to the STACKIT Project definition.
  EOT
}

variable "runner_ref" {
  type = object({
    kind = optional(string)
    uuid = optional(string)
  })
  nullable    = false
  description = "Runner of the STACKIT Project definition. Set to `{}` to use the default shared runner."
}

variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the created platform, landing zones and STACKIT Project definition."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested STACKIT integration. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Draft state of the STACKIT Project definition.
  EOT
}
