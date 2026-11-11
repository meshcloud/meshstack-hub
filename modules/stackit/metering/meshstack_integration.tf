variable "stackit_organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization whose project costs the metering reads."
}

variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project of the platform team that holds the backplane service accounts."
}

variable "stackit_service_account_name" {
  type        = string
  nullable    = false
  default     = "mesh-metering"
  description = "Name of the metering service account in `stackit_project_id`; the building block runs get one named `<name>-bb`."
}

variable "kubernetes_oidc_issuer" {
  type        = string
  nullable    = false
  description = "OIDC issuer of the service account tokens of the cluster behind `kubernetes_service_account_definition_ref`, as its `/.well-known/openid-configuration` reports it. STACKIT must reach it."
}

variable "kubernetes_service_account_definition_ref" {
  type = object({
    kind = string
    uuid = string
  })
  nullable    = false
  description = "Ref of the `kubernetes/service-account` building block definition whose kubeconfig the metering deploys with. Order it with a role that may manage service accounts, Secrets and CronJobs, such as `edit`."
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
  description = "Full identifier `<platform>.<location>` of the STACKIT meshPlatform whose tenants receive the usage reports, e.g. `stackit.global`."
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
  description = "Tag of the `ghcr.io/meshcloud/mesh-custom-metering/mesh-metering-stackit` image every building block runs. It must support workload identity federation."
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

output "metering_service_account_email" {
  description = "STACKIT service account the metering CronJobs act as."
  value       = module.backplane.metering_service_account_email
}

locals {
  api_secret_version = nonsensitive(sha256(var.metering_api_secret))
  # The kubernetes provider rewrites a write-only secret only when its revision changes.
  credentials_revision = parseint(substr(local.api_secret_version, 0, 7), 16) + 1
}

# Lookup specified runner for workload identity federation info. Null results in the default hosted runner.
data "meshstack_building_block_runner" "this" {
  metadata = {
    uuid = var.meshstack.runner_ref == null ? null : var.meshstack.runner_ref.uuid
  }

  lifecycle {
    postcondition {
      # try: a runner without any workload identity federation has a null spec.workload_identity_federation.
      condition     = try(self.spec.workload_identity_federation.azure, null) != null
      error_message = "The building block runner offers no token for Azure. We use that token as a generic OIDC token for STACKIT, so pick a runner that offers one via var.meshstack.runner_ref."
    }
  }
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/metering/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_project_id
  organization_id      = var.stackit_organization_id
  service_account_name = var.stackit_service_account_name

  # The runner offers no STACKIT token, so we use the one offered for Azure as a generic OIDC token. The federation trusts its issuer and audience.
  workload_identity_federation = {
    issuer   = data.meshstack_building_block_runner.this.spec.workload_identity_federation.issuer
    audience = data.meshstack_building_block_runner.this.spec.workload_identity_federation.azure.audience
    subjects = [meshstack_building_block_definition.this.version_latest.workload_identity_federation.subject]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "STACKIT Metering")
    description         = coalesce(var.bbd_description, "Collects STACKIT project costs on a schedule and submits them to meshStack as usage reports, running as a CronJob in your Kubernetes namespace.")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/stackit/metering/buildingblock/logo.png"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "KUBERNETES" }]
    run_transparency    = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Metering** building block brings STACKIT costs into meshStack. It runs the STACKIT metering of [mesh-custom-metering](https://github.com/meshcloud/mesh-custom-metering) as a CronJob in your Kubernetes namespace, which reads the costs of every project in the STACKIT organization from the Cost API and submits them to meshStack as usage reports.

    ## 🎯 When to use it

    Use this building block when you:
    - Run a STACKIT platform in meshStack and want its costs in chargeback and the cost dashboards.
    - Already have a namespace with a Kubernetes Service Account building block that may manage service accounts, Secrets and CronJobs, such as one with the `edit` role.

    ## 💡 Usage examples

    **Example 1: Hourly costs for the STACKIT platform**
    The platform team orders the metering in its operations namespace for the platform `stackit.global`. Every hour the CronJob re-submits the costs of the current month.

    **Example 2: Part of Platform Metering**
    The Platform Metering building block orders this one in its metering namespace when the team ticks STACKIT, next to the metering of other clouds.

    ## 🔐 No STACKIT key

    The CronJob acts as a STACKIT service account with read access to the organization's costs through workload identity federation: STACKIT trusts the token of the CronJob's Kubernetes service account in your namespace. There is no STACKIT key to store or rotate.

    The meshStack API user and the meshPlatform the reports go to are set by the platform team, so you only choose how often the job runs.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the Kubernetes cluster | ✅ | ❌ |
    | Provide the STACKIT identity with read access to the costs | ✅ | ❌ |
    | Provide and rotate the meshStack API user | ✅ | ❌ |
    | Publish the metering image | ✅ | ❌ |
    | Monitor failed metering runs | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    runner_ref    = data.meshstack_building_block_runner.this.ref
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/metering/buildingblock"
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
        description     = "STACKIT meshPlatform whose tenants receive the usage reports."
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

      credentials_revision = {
        display_name    = "Credentials Revision"
        description     = "Changes with the API user password, so a run writes a new password to the Kubernetes secret."
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

      stackit_organization_id = {
        display_name    = "STACKIT Organization"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_organization_id)
      }

      stackit_project_id = {
        display_name    = "STACKIT Project"
        description     = "Project of the metering service account."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_project_id)
      }

      stackit_metering_service_account_email = {
        display_name    = "STACKIT Metering Service Account"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.backplane.metering_service_account_email)
      }

      kubernetes_oidc_issuer = {
        display_name    = "Kubernetes OIDC Issuer"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.kubernetes_oidc_issuer)
      }

      image_tag = {
        display_name    = "Image Tag"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.metering_image_tag)
      }

      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account the provider authenticates as via WIF."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.backplane.service_account_email)
      }

      STACKIT_USE_OIDC = {
        display_name    = "STACKIT Use OIDC"
        description     = "Enables OIDC-based WIF for the STACKIT provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("1")
      }

      STACKIT_FEDERATED_TOKEN_FILE = {
        display_name    = "STACKIT Federated Token File"
        description     = "Path to the WIF token file injected by meshStack."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(data.meshstack_building_block_runner.this.spec.workload_identity_federation.azure.token_path)
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
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
