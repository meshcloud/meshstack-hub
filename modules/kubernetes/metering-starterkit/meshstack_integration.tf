variable "kubernetes" {
  type = object({
    platform_ref = object({
      kind = string
      uuid = string
    })
    landing_zone_name = string
    cluster_name      = string
    cluster_server    = string
    cluster_roles     = optional(list(string), ["edit"])

    service_account_bbd_display_name = optional(string)
  })
  nullable    = false
  description = <<-EOT
  Kubernetes meshPlatform the metering namespace is created on, and its cluster. Configure the `kubernetes` provider with a cluster admin login for that cluster: it creates the deployer identity of the Kubernetes Service Account definition, and meshStack only gets the deployer's kubeconfig.
  `cluster_roles`: ClusterRoles the Kubernetes Service Account definition offers. It must contain `edit`, which the metering orders.
  `service_account_bbd_display_name`: Overrides the name of the Kubernetes Service Account definition.
  EOT

  validation {
    condition     = contains(var.kubernetes.cluster_roles, "edit")
    error_message = "kubernetes.cluster_roles must contain edit, which the metering service account is ordered with."
  }
}

variable "stackit" {
  type = object({
    platform_identifier    = string
    organization_id        = string
    project_id             = string
    kubernetes_oidc_issuer = string
    service_account_name   = optional(string, "mesh-metering")
    image_tag              = optional(string, "latest")
  })
  default     = null
  description = <<-EOT
  Offers the metering of STACKIT, see `stackit/metering`; null leaves it out. Configure the `stackit` provider with an identity that may create service accounts in `project_id` and assign roles on the organization.
  `platform_identifier`: Full identifier `<platform>.<location>` of the STACKIT meshPlatform, e.g. `stackit.global`.
  `organization_id`: STACKIT organization whose costs are read.
  `project_id`: STACKIT project of the metering service accounts.
  `kubernetes_oidc_issuer`: OIDC issuer of the cluster's service account tokens, as its `/.well-known/openid-configuration` reports it. STACKIT must reach it.
  EOT
}

variable "tcloud" {
  type = object({
    platform_identifier = string
    contract_ids        = optional(list(string), [])
    image_tag           = optional(string, "latest")
  })
  default     = null
  description = <<-EOT
  Offers the metering of T Cloud Public, see `otc/metering`; null leaves it out. Needs `tcloud_api_token`.
  `platform_identifier`: Full identifier `<platform>.<location>` of the T Cloud Public meshPlatform, e.g. `otc.global`.
  `contract_ids`: T Cloud contract numbers to read. Empty reads every contract the API key sees.
  EOT

  validation {
    condition     = var.stackit != null || var.tcloud != null
    error_message = "Offer the metering of at least one cloud: set stackit, tcloud or both."
  }
}

variable "tcloud_api_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "API key of the T Cloud Financial Dashboard (Configuration > API Keys) with security level `Admin`. It is valid for at most 90 days; apply again with a new key before then."

  validation {
    condition     = var.tcloud == null || var.tcloud_api_token != null
    error_message = "tcloud needs tcloud_api_token."
  }
}

variable "metering_meshfed_url" {
  type        = string
  nullable    = false
  description = "meshfed API endpoint of the meshStack that receives the usage reports, e.g. `https://federation.example.meshcloud.io`."
}

variable "metering_kraken_url" {
  type        = string
  nullable    = false
  description = "Kraken API endpoint of the same meshStack, e.g. `https://kraken.example.meshcloud.io`."
}

variable "metering_api_user" {
  type        = string
  nullable    = false
  description = "Username of the meshStack API user that lists meshTenants and imports usage reports. An organization admin creates it in meshPanel; the metering API accepts no API keys."
}

variable "metering_api_secret" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Password of the meshStack API user."
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

output "service_account_building_block_definition" {
  description = "The Kubernetes Service Account definition, which teams can also order on their own namespaces."
  value       = module.service_account.building_block_definition
}

output "metering_building_block_definitions" {
  description = "The cloud metering definitions on offer, keyed by the cloud name on the order form."
  value       = local.metering_definitions
}

output "stackit_metering_service_account_email" {
  description = "STACKIT service account the STACKIT metering CronJobs act as; null without `stackit`."
  value       = one(module.stackit_metering[*].metering_service_account_email)
}

module "service_account" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/service-account?ref=${var.hub.git_ref}"

  cluster_name     = var.kubernetes.cluster_name
  cluster_server   = var.kubernetes.cluster_server
  cluster_roles    = var.kubernetes.cluster_roles
  bbd_display_name = var.kubernetes.service_account_bbd_display_name

  meshstack = var.meshstack
  hub       = var.hub
}

module "stackit_metering" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/metering?ref=${var.hub.git_ref}"
  count  = var.stackit == null ? 0 : 1

  stackit_organization_id      = var.stackit.organization_id
  stackit_project_id           = var.stackit.project_id
  stackit_service_account_name = var.stackit.service_account_name
  kubernetes_oidc_issuer       = var.stackit.kubernetes_oidc_issuer
  metering_platform_identifier = var.stackit.platform_identifier
  metering_image_tag           = var.stackit.image_tag

  kubernetes_service_account_definition_ref = module.service_account.building_block_definition.ref

  metering_meshfed_url = var.metering_meshfed_url
  metering_kraken_url  = var.metering_kraken_url
  metering_api_user    = var.metering_api_user
  metering_api_secret  = var.metering_api_secret
  metering_schedule    = var.metering_schedule

  meshstack = var.meshstack
  hub       = var.hub
}

module "tcloud_metering" {
  source = "github.com/meshcloud/meshstack-hub//modules/otc/metering?ref=${var.hub.git_ref}"
  count  = var.tcloud == null ? 0 : 1

  tcloud_api_token             = var.tcloud_api_token
  tcloud_contract_ids          = var.tcloud.contract_ids
  metering_platform_identifier = var.tcloud.platform_identifier
  metering_image_tag           = var.tcloud.image_tag

  kubernetes_service_account_definition_ref = module.service_account.building_block_definition.ref

  metering_meshfed_url = var.metering_meshfed_url
  metering_kraken_url  = var.metering_kraken_url
  metering_api_user    = var.metering_api_user
  metering_api_secret  = var.metering_api_secret
  metering_schedule    = var.metering_schedule

  meshstack = var.meshstack
  hub       = var.hub
}

locals {
  # Keyed by the cloud name on the order form, which also names each metering building block.
  metering_definitions = merge(
    var.stackit == null ? {} : { STACKIT = module.stackit_metering[0].building_block_definition },
    var.tcloud == null ? {} : { "T Cloud" = module.tcloud_metering[0].building_block_definition },
  )

  clouds = sort(keys(local.metering_definitions))
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = coalesce(var.bbd_display_name, "Platform Metering")
    description      = coalesce(var.bbd_description, "Brings the costs of your clouds into meshStack: pick the clouds, and it sets up a metering job for each of them.")
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/kubernetes/metering-starterkit/buildingblock/logo.png"
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
        repository_path                = "modules/kubernetes/metering-starterkit/buildingblock"
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
        argument        = jsonencode(jsonencode(var.kubernetes.platform_ref))
      }

      landing_zone_ref = {
        display_name    = "Landing Zone"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode({ name = var.kubernetes.landing_zone_name }))
      }

      service_account_definition_version_ref = {
        display_name    = "Service Account Definition Version"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(module.service_account.building_block_definition.version_ref))
      }

      metering_building_block_definition_version_refs = {
        display_name    = "Metering Definition Versions"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode({ for cloud, definition in local.metering_definitions : cloud => definition.version_ref }))
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

# Configure all three providers, the stackit one also without `stackit`: OpenTofu configures the providers
# of a module with count = 0 too. Without STACKIT a placeholder suffices, because the provider only exchanges
# the token on its first API call:
#   provider "stackit" {
#     use_oidc                        = true
#     service_account_email           = "unused@sa.stackit.cloud"
#     service_account_federated_token = "unused"
#   }
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.38.0, < 3.0.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
