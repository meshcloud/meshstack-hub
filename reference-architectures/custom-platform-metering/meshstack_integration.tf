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

variable "approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable    = false
  default     = {}
  description = "Run triggers that need an operator's approval on this definition."
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
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

# Each object input takes its field defaults from one local, which feeds both the input's
# `default_value` and the `default` of each field in its schema, because the order form only shows
# the latter. A `default_value` must satisfy the whole schema, so inputs with required fields that have
# no sane default, and the optional `stackit` and `tcloud`, carry their field defaults only in the
# schema. meshStack does not fill in schema defaults for a value sent through the API, so a field with
# a default is never required, and buildingblock/ repeats the default with optional().
locals {
  kubernetes_default = {
    cluster_roles = ["edit"]
  }

  metering_default = {
    schedule = "0 * * * *"
  }

  metering_project_default = {
    name         = "metering"
    display_name = "Platform Metering"
    tags         = []
  }

  stackit_default = {
    image_tag = "latest"
  }

  tcloud_default = {
    contract_ids = []
    image_tag    = "latest"
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name      = coalesce(var.bbd_display_name, "Custom Platform Metering")
    description       = coalesce(var.bbd_description, "Brings the costs of platforms meshStack does not meter natively, such as STACKIT or T Cloud Public, into meshStack. The metering jobs run on a Kubernetes cluster of your choice.")
    symbol            = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/custom-platform-metering/buildingblock/logo.png"
    support_url       = "https://github.com/meshcloud/mesh-custom-metering"
    target_type       = "WORKSPACE_LEVEL"
    run_transparency  = true
    approval_policies = var.approval_policies

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **Custom Platform Metering** building block sets up the metering of clouds meshStack does not meter natively in one run. Choose the clouds and enter their credentials, and it creates everything workspaces need to collect their costs: the **Platform Metering** definition they order, the cloud metering definitions it orders, and the Kubernetes Service Account definition the metering jobs deploy with.

    ## 🎯 When to use it

    Use this building block when you:
    - Run STACKIT or T Cloud Public platforms in meshStack and want their costs in chargeback and the cost dashboards.
    - Have a Kubernetes platform in meshStack whose cluster can run the metering jobs.

    ## 💡 Usage examples

    **Example 1: Start with STACKIT**
    The platform team switches STACKIT on and enters the organization and a service account key. A workspace then orders Platform Metering, ticks STACKIT, and the costs of the current month show up on the STACKIT tenants within the hour.

    **Example 2: Add T Cloud later**
    The team edits this building block, switches T Cloud on and enters a Financial Dashboard API key. The next run offers T Cloud on the Platform Metering order form.

    ## 🔐 Credentials

    - The **admin kubeconfig** only creates a deployer identity on the cluster. The definitions get the deployer's kubeconfig, which may only manage service accounts and bind the offered ClusterRoles.
    - The **STACKIT service account key** only creates the STACKIT metering identities. The metering jobs read the costs through workload identity federation, without a key.
    - The **T Cloud Financial Dashboard API key** is valid for at most 90 days. Enter a new one here and run this building block again before it expires.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the Kubernetes cluster | ✅ | ❌ |
    | Provide the meshStack API user and the cloud credentials | ✅ | ❌ |
    | Rotate the T Cloud Financial Dashboard API key | ✅ | ❌ |
    | Choose which clouds a workspace meters | ❌ | ✅ |
    | Monitor failed metering runs | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    runner_ref    = var.meshstack.runner_ref
    deletion_mode = "DELETE"

    permissions = [
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCKRUNNER_LIST",
      "PLATFORMINSTANCE_LIST",
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/custom-platform-metering/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      kubernetes = {
        display_name           = "Kubernetes Platform"
        description            = "Kubernetes meshPlatform the metering namespaces are created on, and the ClusterRoles the Kubernetes Service Account definition offers."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 10

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["platform_identifier", "landing_zone_name"]
          properties = {
            platform_identifier              = { type = "string", title = "Platform Identifier (<platform>.<location>)" }
            landing_zone_name                = { type = "string", title = "Landing Zone" }
            cluster_roles                    = { type = "array", title = "Offered ClusterRoles (must include edit)", items = { type = "string" }, default = local.kubernetes_default.cluster_roles }
            service_account_bbd_display_name = { type = "string", title = "Name of the Kubernetes Service Account definition" }
          }
        })
      }

      "kubeconfig.yaml" = {
        display_name           = "Admin Kubeconfig"
        description            = "Kubeconfig of a cluster admin of that platform's cluster. It only creates the deployer identity of the Kubernetes Service Account definition."
        type                   = "FILE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 20
      }

      metering = {
        display_name           = "meshStack Metering API"
        description            = "meshStack endpoints the usage reports go to, the API user that submits them, and the cron schedule of every metering job. An organization admin creates the API user in meshPanel; the metering API accepts no API keys."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 30

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["meshfed_url", "kraken_url", "api_user"]
          properties = {
            meshfed_url = { type = "string", title = "meshfed URL, e.g. https://federation.example.meshcloud.io" }
            kraken_url  = { type = "string", title = "Kraken URL, e.g. https://kraken.example.meshcloud.io" }
            api_user    = { type = "string", title = "API User" }
            schedule    = { type = "string", title = "Cron Schedule", default = local.metering_default.schedule }
          }
        })
      }

      metering_api_secret = {
        display_name           = "meshStack API User Password"
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 40
      }

      metering_project = {
        display_name           = "Metering Project"
        description            = "Name, display name and tags of the meshProject every Platform Metering order creates. Add the tags your meshStack makes mandatory."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(jsonencode(local.metering_project_default))
        display_order          = 50

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          # Not `tags`: meshPanel counts an empty array as a missing required value.
          required = ["name", "display_name"]
          properties = {
            name         = { type = "string", title = "Project Name", default = local.metering_project_default.name }
            display_name = { type = "string", title = "Project Display Name", default = local.metering_project_default.display_name }
            tags = {
              type    = "array"
              title   = "Project Tags"
              default = local.metering_project_default.tags
              items = {
                type     = "object"
                required = ["key", "values"]
                properties = {
                  key    = { type = "string", title = "Tag Key" }
                  values = { type = "array", title = "Values", minItems = 1, items = { type = "string" } }
                }
              }
            }
          }
        })
      }

      stackit_enabled = {
        display_name           = "STACKIT"
        description            = "Offer the metering of STACKIT."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(false)
        display_order          = 60
      }

      stackit = {
        display_name           = "STACKIT Settings"
        description            = "STACKIT meshPlatform, the organization whose costs are read, the project that holds the metering service accounts, and the OIDC issuer of the cluster's service account tokens as its /.well-known/openid-configuration reports it."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        condition              = "input.stackit_enabled == true"
        is_optional            = true
        updateable_by_consumer = true
        display_order          = 70

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["platform_identifier", "organization_id", "project_id", "kubernetes_oidc_issuer"]
          properties = {
            platform_identifier    = { type = "string", title = "STACKIT Platform Identifier (<platform>.<location>)" }
            organization_id        = { type = "string", title = "STACKIT Organization ID" }
            project_id             = { type = "string", title = "STACKIT Project ID of the metering service accounts" }
            kubernetes_oidc_issuer = { type = "string", title = "OIDC Issuer of the Kubernetes Cluster" }
            image_tag              = { type = "string", title = "Metering Image Tag", default = local.stackit_default.image_tag }
          }
        })
      }

      stackit_service_account_key = {
        display_name           = "STACKIT Service Account Key"
        description            = "Key of a STACKIT service account that may create service accounts in that project and assign roles on the organization, e.g. an organization owner."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        condition              = "input.stackit_enabled == true"
        is_optional            = true
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 80
      }

      tcloud_enabled = {
        display_name           = "T Cloud Public"
        description            = "Offer the metering of T Cloud Public."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(false)
        display_order          = 90
      }

      tcloud = {
        display_name           = "T Cloud Public Settings"
        description            = "T Cloud Public meshPlatform and the contract numbers to read. No contract numbers read every contract the API key sees."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        condition              = "input.tcloud_enabled == true"
        is_optional            = true
        updateable_by_consumer = true
        display_order          = 100

        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["platform_identifier"]
          properties = {
            platform_identifier = { type = "string", title = "T Cloud Public Platform Identifier (<platform>.<location>)" }
            contract_ids        = { type = "array", title = "Contract Numbers", items = { type = "string" }, default = local.tcloud_default.contract_ids }
            image_tag           = { type = "string", title = "Metering Image Tag", default = local.tcloud_default.image_tag }
          }
        })
      }

      tcloud_api_token = {
        display_name           = "T Cloud Financial Dashboard API Key"
        description            = "API key created in the Financial Dashboard (Configuration > API Keys) with security level Admin. It is valid for at most 90 days; enter a new one and run again before then."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        condition              = "input.tcloud_enabled == true"
        is_optional            = true
        updateable_by_consumer = true
        sensitive              = {}
        display_order          = 110
      }

      runner_ref = {
        display_name    = "Runner"
        description     = "Runner of every definition this building block creates. `{}` uses the default shared runner."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(coalesce(var.meshstack.runner_ref, {})))
        display_order   = 120
      }

      workspace = {
        display_name    = "Workspace"
        description     = "Workspace that owns the definitions this building block creates."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_order   = 130
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference the nested integrations are sourced from) and `bbd_draft` (forwarded to the definitions this building block creates)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
        display_order   = 140
      }
    }

    outputs = {
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
