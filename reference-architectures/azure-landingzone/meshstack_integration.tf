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

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

# JSON-schema for the Tags input: each section is a list of {key, values} entries — friendlier in the
# meshPanel form than a dynamic-key map — adopted from the STACKIT Landing Zone reference architecture.
# main.tf turns each list back into the map(list(string)) the nested integrations take.
locals {
  tag_list_schema = {
    type = "array"
    items = {
      type     = "object"
      required = ["key", "values"]
      properties = {
        key    = { type = "string", title = "Tag Key" }
        values = { type = "array", title = "Values", minItems = 1, items = { type = "string" } }
      }
    }
  }

  tags_json_schema = {
    "$schema" = "http://json-schema.org/draft-07/schema#"
    type      = "object"
    required  = ["landingzone", "building_block", "owner_tag_key"]
    properties = {
      landingzone    = merge(local.tag_list_schema, { title = "Landing Zone Tags" })
      building_block = merge(local.tag_list_schema, { title = "Building Block Tags" })
      owner_tag_key  = { type = "string", title = "Owner Tag Key", default = "" }
    }
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
    The **Azure Landing Zone** reference architecture turns a fresh Azure Enterprise-Scale
    hierarchy into a self-service-ready meshStack platform in one run — you enter the service
    principal it runs as when ordering, no separate bootstrap step.

    Running it once:
    - creates the Enterprise-Scale management group hierarchy (a **Landing Zones** group with
      **Corp**, **Online** and **Sandbox** beneath it, plus **Connectivity**) under a parent
      management group you provide,
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

    A platform engineer orders this once for a workspace. Beforehand they create one **service
    principal** and enter its **client id, client secret and tenant** here. That principal needs
    **Owner** on the parent management group (to create the hierarchy, role assignments and
    identities beneath it) and the Microsoft Graph app roles **Application.ReadWrite.All**,
    **Directory.Read.All** and **AppRoleAssignment.ReadWrite.All** (to register the meshStack
    platform service principals). The secret is stored as a sensitive input and can be rotated here.

    Create that service principal once with the Azure CLI (a tenant admin runs this — granting Owner
    and consenting the Graph roles both need tenant-admin rights), then paste the three values it
    prints:

    ```bash
    PARENT_MG="<parent management group id, or the tenant id>"   # the hierarchy is created under this
    SP_NAME="azure-landingzone-deployer"

    # Create the service principal and grant it Owner on the parent management group in one step.
    SP=$(az ad sp create-for-rbac --name "$SP_NAME" \
      --role Owner \
      --scopes "/providers/Microsoft.Management/managementGroups/$PARENT_MG" -o json)
    echo "$SP"   # appId = client id, password = client secret, tenant = tenant id

    # Grant the three Microsoft Graph app roles the run needs, resolving every id from $SP so there is
    # nothing to copy-paste (Application.ReadWrite.All, Directory.Read.All, AppRoleAssignment.ReadWrite.All).
    SP_OID=$(az ad sp show --id "$(echo "$SP" | jq -r .appId)" --query id -o tsv)
    GRAPH_OID=$(az ad sp show --id 00000003-0000-0000-c000-000000000000 --query id -o tsv)
    for ROLE in 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9 \
                7ab1d382-f21e-4acd-a863-ba3e13f7da61 \
                06b708a9-e830-4db3-a914-8e69da51d44f; do
      az rest --method POST \
        --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$SP_OID/appRoleAssignments" \
        --body "{\"principalId\":\"$SP_OID\",\"resourceId\":\"$GRAPH_OID\",\"appRoleId\":\"$ROLE\"}"
    done
    ```

    Enter `appId` as **Azure Client ID**, `password` as **Azure Client Secret** and `tenant` as
    **Azure Tenant ID** when ordering. (For a local `terraform apply` of the buildingblock, set the
    same values as `azure_client_id`, `azure_client_secret` and `azure_tenant_id`.)

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
      # display_order groups the order form top-to-bottom: platform identity (10s), Azure auth (30s),
      # Azure placement (60s), subscription provisioning (100s), foundation toggles (130s), tags (170),
      # and the injected/STATIC inputs last (900s) since the platform engineer never edits those.

      # ── Platform identity ──

      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the Azure platform created in meshStack (letters, digits and dashes only)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9-]+$"
        validation_regex_error_message = "platform_identifier must only contain letters, digits, and dashes."
        display_order                  = 10
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 20
      }

      # ── Azure authentication ──
      # The ordered run authenticates as a service principal the platform engineer supplies here. It
      # needs Owner on the parent management group and the Microsoft Graph app roles listed in the
      # readme, because the run creates the management groups, the platform service principals and the
      # backplane identities. The secret is the Azure equivalent of the STACKIT service account key —
      # a sensitive input, reused on every run and rotatable here.

      azure_client_id = {
        display_name    = "Azure Client ID"
        description     = "Client ID of the service principal this run authenticates as."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 30
      }
      azure_client_secret = {
        display_name    = "Azure Client Secret"
        description     = "Client secret of that service principal. Reused on every run and rotatable here."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        sensitive       = {}
        display_order   = 40
      }
      azure_tenant_id = {
        display_name    = "Azure Tenant ID"
        description     = "Azure Entra tenant ID of the service principal and the target tenant."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        display_order   = 50
      }

      # ── Azure placement ──

      # Creates the Corp/Online/Sandbox/Connectivity hierarchy under the parent management group the
      # platform engineer enters. A JSON form (two labelled fields) rather than a raw JSON editor; the
      # display-name fields on the variable keep their defaults.
      azure_management_groups = {
        display_name    = "Management Groups"
        description     = "The parent management group the Corp/Online/Sandbox/Connectivity hierarchy is created under, and a name prefix to keep the created group names unique across the tenant."
        type            = "JSON"
        assignment_type = "USER_INPUT"
        display_order   = 60
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["parent_management_group_id"]
          properties = {
            parent_management_group_id = { type = "string", title = "Parent Management Group ID", description = "Existing management group name or tenant ID the hierarchy is created under." }
            name_prefix                = { type = "string", title = "Name Prefix", description = "Prefix for the created group names, to keep them unique across the tenant.", default = "" }
          }
        })
      }

      azure_location = {
        display_name    = "Azure Location"
        description     = "Azure region where the building block backplane resource groups and identities are created."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("germanywestcentral")
        display_order   = 70
      }

      azure_platform_subscription_id = {
        display_name                   = "Platform Subscription ID"
        description                    = "Bare GUID of a platform-owned subscription. Hosts the **Budget Alert** and **Storage Account** backplanes (and, as written, the resources they deploy)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "Platform subscription ID must be a bare subscription GUID."
        display_order                  = 80
      }

      azure_connectivity_subscription_id = {
        display_name                   = "Connectivity Subscription ID"
        description                    = "Bare GUID of the **connectivity** subscription. Hosts the Hub Network backplane and, when `provision_hub` is set, the hub vnet and firewall."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "Connectivity subscription ID must be a bare subscription GUID."
        display_order                  = 90
      }

      # ── Subscription provisioning ──
      # A SINGLE_SELECT model drives which of the two blocks below meshStack shows — pick the pool model
      # and the pool prefix appears; pick MCA and the billing fields appear (and are required). main.tf
      # reassembles the shown one into the object modules/azure expects.
      subscription_provisioning_model = {
        display_name      = "Subscription Provisioning Model"
        description       = "How meshStack gets subscriptions: assign from an existing pool, or create them via an MCA billing agreement."
        type              = "SINGLE_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = ["pre_provisioned", "customer_agreement"]
        default_value     = jsonencode("pre_provisioned")
        display_order     = 100
      }

      pre_provisioned = {
        display_name    = "Pre-provisioned Pool"
        description     = "Shown for the pre-provisioned model. meshStack assigns subscriptions from existing ones whose name starts with this prefix."
        type            = "JSON"
        assignment_type = "USER_INPUT"
        condition       = "input.subscription_provisioning_model == \"pre_provisioned\""
        display_order   = 110
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          properties = {
            unused_subscription_name_prefix = { type = "string", title = "Unused Subscription Name Prefix", default = "unused-" }
          }
        })
      }

      customer_agreement = {
        display_name    = "Customer Agreement (MCA)"
        description     = "Shown for the customer-agreement model. The MCA billing scope meshStack creates subscriptions under."
        type            = "JSON"
        assignment_type = "USER_INPUT"
        condition       = "input.subscription_provisioning_model == \"customer_agreement\""
        display_order   = 120
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          required  = ["billing_account_name", "billing_profile_name", "invoice_section_name"]
          properties = {
            billing_account_name = { type = "string", title = "Billing Account Name" }
            billing_profile_name = { type = "string", title = "Billing Profile Name" }
            invoice_section_name = { type = "string", title = "Invoice Section Name" }
          }
        })
      }

      # ── Foundation — optional Azure-side infra, as toggles that reveal their settings ──

      provision_hub = {
        display_name    = "Provision Hub Network"
        description     = "Provision a central hub vnet for spoke networks to peer into. Turning this on reveals the hub network settings below."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
        display_order   = 130
      }

      # Shown only when Provision Hub Network is on — the whole point of conditional inputs: the hub
      # fields appear once, and only once, the toggle above is set.
      hub_network = {
        display_name    = "Hub Network"
        description     = "Shown when Provision Hub Network is on. Address space and firewall settings for the hub vnet spoke networks peer into."
        type            = "JSON"
        assignment_type = "USER_INPUT"
        condition       = "input.provision_hub == true"
        display_order   = 140
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "object"
          properties = {
            address_space           = { type = "string", title = "Address Space (CIDR)", default = "10.0.0.0/22" }
            hub_vnet_name           = { type = "string", title = "Hub VNet Name", default = "hub-vnet" }
            hub_resource_group_name = { type = "string", title = "Hub Resource Group Name", default = "hub-network" }
            create_gateway_subnet   = { type = "boolean", title = "Create Gateway Subnet", default = true }
            deploy_firewall         = { type = "boolean", title = "Deploy Azure Firewall", default = false }
            firewall_sku_tier       = { type = "string", title = "Firewall SKU Tier", enum = ["Basic", "Standard", "Premium"], default = "Standard" }
          }
        })
      }

      assign_policies = {
        display_name    = "Assign Enterprise-Scale Policies"
        description     = "Assign curated ES policies to Corp/Online/Sandbox (Corp locked down, Online region-restricted, Sandbox audit-only)."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(true)
        display_order   = 150
      }

      foundation_resource_groups = {
        display_name    = "Platform Resource Groups"
        description     = "Extra platform-owned resource groups created in the platform subscription."
        type            = "JSON"
        assignment_type = "USER_INPUT"
        display_order   = 160
        json_schema = jsonencode({
          "$schema" = "http://json-schema.org/draft-07/schema#"
          type      = "array"
          items = {
            type     = "object"
            required = ["name", "location"]
            properties = {
              name     = { type = "string", title = "Name" }
              location = { type = "string", title = "Location", default = "germanywestcentral" }
            }
          }
        })
      }

      # ── Tags ──

      tags = {
        display_name           = "Tags"
        description            = "Tags forwarded to the nested integrations. Add {key, values} entries for the landing zones and the building block definitions, plus the owner tag key that gets the creator's display name."
        type                   = "JSON"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        display_order          = 170
        json_schema            = jsonencode(local.tags_json_schema)
      }

      # ── Injected by meshStack / set at registration — not shown on the order form ──

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location, landing zones and building block definitions."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
        display_order   = 900
      }

      creator = {
        display_name    = "Creator"
        description     = "The user who ordered this architecture. Their display name is written to the landing zones' owner tag when `tags.owner_tag_key` is set."
        type            = "CODE"
        assignment_type = "AUTHOR"
        display_order   = 910
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub ref used to source the nested modules) and `bbd_draft` (forwarded to the nested definitions' draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
        display_order   = 920
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: identifier gets a random suffix, nothing is protected from deletion. Do not publish such a platform to other workspaces. Set false for real use."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.playground_mode)
        display_order   = 930
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

# Registration only creates the building block definition in meshStack — no Azure resources, so no
# Azure providers and no Azure credentials are needed here. The ordered run authenticates to Azure
# with the service principal entered as an input (see buildingblock/provider.tf).
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.24.0"
    }
  }
}
