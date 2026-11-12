variable "kubernetes_service_account_definition_ref" {
  type = object({
    kind = string
    uuid = string
  })
  nullable    = false
  description = "Ref of the `kubernetes/service-account` building block definition whose kubeconfig the metering deploys with. Order it with a role that may manage Secrets and CronJobs, such as `edit`."
}

variable "tcloud_api_token" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "API key of the T Cloud Financial Dashboard (Configuration > API Keys) with security level `Admin`. It is valid for at most 90 days; apply again with the new key to roll it out to every building block."
}

variable "tcloud_contract_ids" {
  type        = list(string)
  nullable    = false
  default     = []
  description = "T Cloud contract numbers to read. Empty reads every contract the API key sees."
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

variable "metering_platform_identifier" {
  type        = string
  nullable    = false
  description = "Full identifier `<platform>.<location>` of the T Cloud Public meshPlatform whose tenants receive the usage reports, e.g. `otc.global`."
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

variable "metering_schedule" {
  type        = string
  nullable    = false
  default     = "0 * * * *"
  description = "Cron schedule preselected on the order form. Each run re-submits the full current month."
}

variable "metering_image_tag" {
  type        = string
  nullable    = false
  default     = "latest"
  description = "Tag of the `ghcr.io/meshcloud/mesh-custom-metering/mesh-metering-tcloud` image every building block runs."
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
  api_secret_version = nonsensitive(sha256(var.metering_api_secret))
  api_token_version  = nonsensitive(sha256(var.tcloud_api_token))
  # The kubernetes provider rewrites a write-only secret only when its revision changes.
  credentials_revision = parseint(substr(sha256("${local.api_secret_version}${local.api_token_version}"), 0, 7), 16) + 1
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "T Cloud Public Metering")
    description         = coalesce(var.bbd_description, "Collects T Cloud Public consumption on a schedule and submits it to meshStack as usage reports, running as a CronJob in your Kubernetes namespace.")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/otc/metering/buildingblock/logo.png"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "KUBERNETES" }]
    run_transparency    = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **T Cloud Public Metering** building block brings T Cloud Public (Open Telekom Cloud) costs into meshStack. It runs the T Cloud metering of [mesh-custom-metering](https://github.com/meshcloud/mesh-custom-metering) as a CronJob in your Kubernetes namespace, which reads the consumption of every project from the T Cloud Financial Dashboard and submits it to meshStack as usage reports.

    ## 🎯 When to use it

    Use this building block when you:
    - Run a T Cloud Public platform in meshStack and want its costs in chargeback and the cost dashboards.
    - Already have a namespace with a Kubernetes Service Account building block that may manage Secrets and CronJobs, such as one with the `edit` role.

    ## 💡 Usage examples

    **Example 1: Hourly costs for the T Cloud Public platform**
    The platform team orders the metering in its operations namespace for the platform `otc.global`. Every hour the CronJob re-submits the consumption of the current month.

    **Example 2: Part of Platform Metering**
    The Platform Metering building block orders this one in its metering namespace when the team ticks T Cloud, next to the metering of other clouds.

    ## 🔑 Financial Dashboard API key

    The Financial Dashboard offers no workload identity federation, so the job reads with an API key of security level `Admin`. The platform team provides it and rotates it at least every 90 days; each rotation reaches every building block on its next run.

    The meshStack API user and the meshPlatform the reports go to are set by the platform team as well, so you only choose how often the job runs.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the Kubernetes cluster | ✅ | ❌ |
    | Provide and rotate the Financial Dashboard API key | ✅ | ❌ |
    | Provide and rotate the meshStack API user | ✅ | ❌ |
    | Publish the metering image | ✅ | ❌ |
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
        repository_path                = "modules/otc/metering/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    dependency_refs = [var.kubernetes_service_account_definition_ref]

    inputs = {
      schedule = {
        display_name           = "Schedule"
        description            = "Cron schedule of the metering job. Each run re-submits the full current month."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(var.metering_schedule)
        updateable_by_consumer = true
        display_order          = 1
      }

      kubeconfig = {
        display_name    = "Kubeconfig"
        description     = "Kubeconfig of the parent Kubernetes Service Account building block."
        type            = "STRING"
        assignment_type = "BUILDING_BLOCK_OUTPUT"
        argument        = jsonencode("${var.kubernetes_service_account_definition_ref.uuid}.kubeconfig")
      }

      namespace = {
        display_name    = "Namespace"
        description     = "Kubernetes namespace of the tenant the CronJob runs in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      platform_identifier = {
        display_name    = "meshPlatform"
        description     = "T Cloud Public meshPlatform whose tenants receive the usage reports."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_platform_identifier)
      }

      meshstack_api_user = {
        display_name    = "meshStack API User"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_api_user)
      }

      meshstack_api_secret = {
        display_name    = "meshStack API User Password"
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.metering_api_secret
            secret_version = local.api_secret_version
          }
        }
      }

      tcloud_api_token = {
        display_name    = "Financial Dashboard API Key"
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = var.tcloud_api_token
            secret_version = local.api_token_version
          }
        }
      }

      credentials_revision = {
        display_name    = "Credentials Revision"
        description     = "Changes with the API user password or the Financial Dashboard API key, so a run writes them anew to the Kubernetes secret."
        type            = "INTEGER"
        assignment_type = "STATIC"
        argument        = jsonencode(local.credentials_revision)
      }

      meshstack_meshfed_url = {
        display_name    = "meshfed URL"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_meshfed_url)
      }

      meshstack_kraken_url = {
        display_name    = "Kraken URL"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_kraken_url)
      }

      tcloud_contract_ids = {
        display_name    = "T Cloud Contracts"
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.tcloud_contract_ids))
      }

      image_tag = {
        display_name    = "Image Tag"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_image_tag)
      }
    }

    outputs = {
      cron_job_name = {
        display_name    = "CronJob"
        type            = "STRING"
        assignment_type = "NONE"
      }

      summary = {
        display_name    = "Summary"
        type            = "STRING"
        assignment_type = "SUMMARY"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.2"
    }
  }
}
