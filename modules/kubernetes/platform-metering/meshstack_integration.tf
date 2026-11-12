variable "kubernetes_platform_ref" {
  type = object({
    kind = string
    uuid = string
  })
  nullable    = false
  description = "Ref of the Kubernetes meshPlatform the metering namespace is created on, the one the Kubernetes Service Account definition's kubeconfig belongs to."
}

variable "kubernetes_landing_zone_name" {
  type        = string
  nullable    = false
  description = "Landing zone of the metering namespace."
}

variable "kubernetes_service_account_definition_version_ref" {
  type = object({
    uuid = string
  })
  nullable    = false
  description = "Version of the `kubernetes/service-account` definition on that platform, ordered with the `edit` role."
}

variable "metering_building_block_definition_version_refs" {
  type = map(object({
    uuid = string
  }))
  nullable    = false
  description = "Versions of the cloud metering definitions on offer, such as `stackit/metering`, keyed by the cloud name shown on the order form, e.g. `{ STACKIT = module.stackit_metering.building_block_definition.version_ref }`."

  validation {
    condition     = length(var.metering_building_block_definition_version_refs) > 0
    error_message = "Offer at least one cloud metering definition."
  }
}

variable "metering_project_name" {
  type        = string
  nullable    = false
  default     = "metering"
  description = "Name of the meshProject every order creates. It is fixed, so a workspace holds one Platform Metering."
}

variable "metering_project_display_name" {
  type        = string
  nullable    = false
  default     = "Platform Metering"
  description = "Display name of the meshProject every order creates."
}

variable "metering_project_tags" {
  type        = map(list(string))
  nullable    = false
  default     = {}
  description = "Tags of the metering project, for the tags a meshStack makes mandatory."
}

variable "metering_schedule" {
  type        = string
  nullable    = false
  default     = "0 * * * *"
  description = "Cron schedule of every metering job."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry application teams see in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown next to the marketplace entry."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace before ordering."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
  })
  description = "Shared meshStack context, see docs."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const = true
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the building block definition version is kept in draft mode.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

locals {
  clouds = sort(keys(var.metering_building_block_definition_version_refs))
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = coalesce(var.bbd_display_name, "Platform Metering")
    description      = coalesce(var.bbd_description, "Brings the costs of your clouds into meshStack: pick the clouds, and it sets up a metering job for each of them.")
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/platform-metering/buildingblock/logo.png"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    **Platform Metering** brings the costs of your clouds into meshStack's chargeback and cost dashboards. Select the clouds, and it sets up everything their metering needs: a project with a Kubernetes namespace, a service account for it, and one metering job per cloud.

    ## 🎯 When to use it

    Use this building block when you:
    - Run platforms in meshStack whose costs meshStack does not meter natively, such as ${join(", ", local.clouds)}.
    - Want one place for all metering jobs instead of setting up namespaces and credentials per cloud.

    ## 💡 Usage examples

    **Example 1: Start with one cloud**
    The platform team selects ${local.clouds[0]}. Within minutes the first costs of the current month show up on the tenants of that platform.

    **Example 2: Add a cloud later**
    A new cloud joins the platform. The team edits this building block, selects the cloud as well, and the next run adds its metering job next to the existing ones. Deselecting a cloud removes its job.

    ## 📦 What you get

    - The project `${var.metering_project_name}` in your workspace with one Kubernetes namespace.
    - A service account that may deploy only into that namespace.
    - One metering job per selected cloud, running on `${var.metering_schedule}`.

    The credentials for meshStack and for each cloud are set up by the platform team, so there is nothing to enter but the clouds.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the Kubernetes cluster | ✅ | ❌ |
    | Provide the meshStack API user and the cloud credentials | ✅ | ❌ |
    | Offer the metering of a cloud | ✅ | ❌ |
    | Choose which clouds are metered | ❌ | ✅ |
    | Monitor failed metering runs | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    runner_ref    = var.meshstack.runner_ref
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/kubernetes/platform-metering/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      clouds = {
        display_name           = "Clouds"
        description            = "Clouds whose costs meshStack collects. Change the selection later to add or remove a cloud."
        type                   = "MULTI_SELECT"
        assignment_type        = "USER_INPUT"
        selectable_values      = local.clouds
        updateable_by_consumer = true
        display_order          = 1
      }

      workspace_identifier = {
        display_name    = "Workspace"
        description     = "Workspace that gets the metering project."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      payment_method = {
        display_name           = "Payment Method"
        description            = "Payment method of the metering project, one of your workspace's payment methods."
        type                   = "CODE"
        assignment_type        = "PAYMENT_METHOD"
        updateable_by_consumer = true
      }

      project_name = {
        display_name    = "Project Name"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_project_name)
      }

      project_display_name = {
        display_name    = "Project Display Name"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_project_display_name)
      }

      project_tags = {
        display_name    = "Project Tags"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.metering_project_tags))
      }

      platform_ref = {
        display_name    = "Kubernetes Platform"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.kubernetes_platform_ref))
      }

      landing_zone_ref = {
        display_name    = "Landing Zone"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode({ name = var.kubernetes_landing_zone_name }))
      }

      service_account_definition_version_ref = {
        display_name    = "Service Account Definition Version"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.kubernetes_service_account_definition_version_ref))
      }

      metering_building_block_definition_version_refs = {
        display_name    = "Metering Definition Versions"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.metering_building_block_definition_version_refs))
      }

      schedule = {
        display_name    = "Schedule"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_schedule)
      }
    }

    outputs = {
      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }

    permissions = [
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "PROJECT_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
      "TENANT_DELETE",
    ]
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.0"
    }
  }
}
