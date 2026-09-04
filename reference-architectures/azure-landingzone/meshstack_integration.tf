variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are optional and propagated to building block definition metadata."
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

variable "playground_mode" {
  type     = bool
  nullable = false
  default  = true

  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and nothing is protected against deletion. Set to false for a platform that is actually used. Passed to the building block as a STATIC input, so whoever orders the architecture cannot choose. A playground platform and the building block definitions it registers are not meant to be published to other workspaces."
}

variable "azure_bootstrap_subscription_id" {
  type        = string
  description = "Bare GUID of the subscription where the privileged bootstrap identity (that meshStack runs this architecture as) and its resource group are created."
}

variable "azure_bootstrap_scope" {
  type        = string
  description = "Full resource path where the bootstrap identity is granted Owner — high enough to cover everything the architecture provisions (management groups it creates, role assignments, subscriptions). Typically the tenant root management group."
}

variable "azure_location" {
  type        = string
  default     = "germanywestcentral"
  description = "Azure region for the bootstrap identity's resource group."
}

variable "azure_management_group_prefix" {
  type        = string
  default     = ""
  description = "Prefix for the created management group names/IDs (e.g. 'flotest-az-'), to keep them unique across the tenant. The bootstrap creates the MGs with this prefix; the building block imports/manages the same names."
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

data "meshstack_integrations" "this" {}

# Privileged identity meshStack runs the ordered building block as — federated to this very building
# block definition. Created once by whoever applies this integration (Owner on the scope + able to
# grant Microsoft Graph app roles). Its client id is wired into the ARM_CLIENT_ID input below.
module "bootstrap" {
  source = "github.com/meshcloud/meshstack-hub//reference-architectures/azure-landingzone/bootstrap?ref=${var.hub.git_ref}"

  scope                        = var.azure_bootstrap_scope
  subscription_id              = var.azure_bootstrap_subscription_id
  location                     = var.azure_location
  management_group_name_prefix = var.azure_management_group_prefix

  workload_identity_federation = {
    issuer = data.meshstack_integrations.this.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.this.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = "Azure Landing Zone Reference Architecture"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/azure-landingzone/buildingblock/logo.svg"
    description      = "Onboards an Azure Subscription platform into meshStack on top of an existing Enterprise-Scale management group hierarchy: creates Corp/Online/Sandbox landing zones and registers the budget-alert, storage-account and spoke-network building blocks."
    support_url      = "https://portal.azure.com"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    The **Azure Landing Zone** reference architecture turns an existing Azure Enterprise-Scale
    management group hierarchy into a self-service-ready meshStack platform in one run. It assumes
    the management groups (a parent "Landing Zones" group with Corp, Online and Sandbox beneath it)
    and a central network hub already exist — it does not create them.

    Running it once:
    - registers the **Azure Subscription** platform in meshStack,
    - creates one landing zone per Enterprise-Scale archetype — **Corp** (internal, hub-connected),
      **Online** (internet-facing) and **Sandbox** (experimentation) — each pointing at its
      management group, and
    - registers the **Azure Budget Alert**, **Azure Storage Account** and **Azure Spoke Network**
      building blocks, each with its own backplane identity, so application teams can order them.

    ## 🎯 When to use it

    Use this building block when you have an Enterprise-Scale management group hierarchy and want to
    onboard it into meshStack as a self-service Azure platform with ready-to-order building blocks,
    without hand-wiring the platform, landing zones and backplanes separately.

    ## 💡 Usage

    A platform engineer runs this once for a workspace. It authenticates to Azure with the applying
    identity, which needs **Owner** on the landing-zones management group and **Entra Application
    Administrator** — for example running locally after `az login`, or through an IaC runtime with
    workload-identity-federation `ARM_*` environment variables.

    Application teams then request Azure subscriptions through the Corp, Online or Sandbox landing
    zone and order the registered building blocks into them. The spoke-network building block is
    best paired with the Corp landing zone for hub-connected workloads.

    ## 🧪 Playground mode

    **Playground Mode** is fixed by whoever deployed this definition and cannot be chosen when
    ordering. It defaults to `true`, which deploys a throwaway platform: the platform identifier
    gets a random suffix so it does not occupy a name for good across the meshStack instance. Such a
    platform and the building block definitions it registers are meant for the deploying workspace
    only — do not publish them to other workspaces. Set it to `false` for a platform that is
    actually used.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the Azure credentials, management group IDs, billing details and hub network details | ✅ | ❌ |
    | Register the Azure platform and the Corp/Online/Sandbox landing zones | ✅ | ❌ |
    | Register the budget-alert, storage-account and spoke-network building blocks | ✅ | ❌ |
    | Request Azure subscriptions through the landing zones | ❌ | ✅ |
    | Order the registered building blocks into their subscriptions | ❌ | ✅ |
    | Manage workloads inside the provisioned subscriptions | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # Ephemeral API key permissions for the meshStack resources this building block and its nested
    # platform/hub-network/budget-alert/storage-account/spoke-network integrations create.
    permissions = [
      "INTEGRATION_LIST",
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE"
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/azure-landingzone/buildingblock"
        ref_name                       = var.hub.git_ref
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── Azure authentication ──
      # The ordered run authenticates as the bootstrap identity via workload identity federation;
      # meshStack injects its OIDC token. No secret is stored.

      ARM_CLIENT_ID = {
        display_name    = "ARM Client ID"
        description     = "Client ID of the bootstrap managed identity the run authenticates as."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.bootstrap.identity.client_id)
      }
      ARM_TENANT_ID = {
        display_name    = "ARM Tenant ID"
        description     = "Azure Entra tenant ID of the bootstrap managed identity."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode(module.bootstrap.identity.tenant_id)
      }
      ARM_USE_OIDC = {
        display_name    = "ARM Use OIDC"
        description     = "Enables OIDC-based workload identity federation for the Azure provider."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("true")
      }
      ARM_OIDC_TOKEN_FILE_PATH = {
        display_name    = "ARM OIDC Token File Path"
        description     = "Path to the OIDC token file meshStack mounts for workload identity federation."
        type            = "STRING"
        assignment_type = "STATIC"
        is_environment  = true
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub ref used to source the nested modules) and `bbd_draft` (forwarded to the nested definitions' draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      # ── meshStack context ──

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location, landing zones and building block definitions."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the Azure platform created in meshStack (letters, digits and dashes only)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }

      tags = {
        display_name           = "Tags"
        description            = "HCL object of tag maps forwarded to the nested integrations: `landingzone` for the landing zones, `building_block` for the registered building block definitions."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          landingzone    = {}
          building_block = {}
        }))
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: identifier gets a random suffix, nothing is protected from deletion. Do not publish such a platform to other workspaces. Set false for real use."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.playground_mode)
      }

      # ── Foundation — what Azure-side infra this run provisions (edit the template; remove blocks to skip) ──

      foundation = {
        display_name    = "Foundation"
        description     = "HCL object — fill in what to provision: `hub` (hub vnet), `policies` (ES policies), `resource_groups`. Remove a block to skip it. (Management groups are platform-configured, not here.)"
        type            = "CODE"
        assignment_type = "USER_INPUT"

        # A ready-to-edit template (not null): adjust the hub CIDR, toggle policies, and delete any
        # block you don't want provisioned.
        default_value = jsonencode(jsonencode({
          hub = {
            address_space   = "10.0.0.0/22"
            deploy_firewall = false
          }
          policies        = true
          resource_groups = {}
        }))
      }

      # ── Azure platform ──

      # STATIC — the tenant is the bootstrap identity's tenant, known at registration.
      azure_tenant_id = {
        display_name    = "Azure Tenant ID"
        description     = "Azure Entra tenant ID (the bootstrap identity's tenant)."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(module.bootstrap.identity.tenant_id)
      }

      # Platform-configured (STATIC): creates the Corp/Online/Sandbox/Connectivity hierarchy under the
      # bootstrap scope. End users don't configure management groups.
      azure_management_groups = {
        display_name    = "Management Groups"
        description     = "Platform-configured: creates the Corp/Online/Sandbox/Connectivity management group hierarchy under the bootstrap scope."
        type            = "CODE"
        assignment_type = "STATIC"
        argument = jsonencode(jsonencode({
          parent_management_group_id = var.azure_bootstrap_scope
          name_prefix                = var.azure_management_group_prefix
        }))
      }

      azure_subscription_provisioning = {
        display_name    = "Subscription Provisioning"
        description     = "HCL object — set exactly one: `pre_provisioned` (assign from a pool named `unused-*`) or `customer_agreement` (create via MCA billing account/profile/invoice section)."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(jsonencode({ pre_provisioned = { unused_subscription_name_prefix = "unused-" } }))
      }

      azure_location = {
        display_name    = "Azure Location"
        description     = "Azure region where the building block backplane resource groups and identities are created."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("germanywestcentral")
      }

      azure_platform_subscription_id = {
        display_name                   = "Platform Subscription ID"
        description                    = "Bare GUID of a platform-owned subscription. Hosts the **Budget Alert** and **Storage Account** backplanes (and, as written, the resources they deploy)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "Platform subscription ID must be a bare subscription GUID."
      }

      # ── Connectivity (Azure Hub Network building block, always registered) ──

      azure_connectivity_subscription_id = {
        display_name                   = "Connectivity Subscription ID"
        description                    = "Bare GUID of the **connectivity** subscription. Hosts the Hub Network backplane and, when `foundation.hub` is set, the hub vnet and firewall."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "Connectivity subscription ID must be a bare subscription GUID."
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
      version = ">= 0.24.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.36"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = ">= 3.0"
    }
  }
}
