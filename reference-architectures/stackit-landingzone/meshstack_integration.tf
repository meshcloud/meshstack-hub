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

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "STACKIT Landing Zone"
    symbol       = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-landingzone/buildingblock/logo.png"
    # meshStack caps spec.description at 255 characters.
    description      = "Onboards a STACKIT sandbox platform into meshStack: a location, resourcemanager folder and the STACKIT Project platform with its default landing zone. Optionally layers on hub-and-spoke networking, a Kubernetes platform with HTTPS, and an AI platform."
    support_url      = "https://portal.stackit.cloud"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    The **STACKIT Landing Zone** building block bootstraps a complete STACKIT sandbox platform
    integration inside a meshStack workspace. Running it once turns a STACKIT organization into a
    sandbox-ready self-service platform: it registers a meshStack location, carves out a dedicated
    STACKIT resourcemanager folder for the workspace and wires up the **STACKIT Project** platform
    together with its default landing zone.

    Three optional layers stack on top of that foundation, each enabled by providing one JSON
    object and each building on the one before it:

    | Option | What it adds | Builds on |
    |---|---|---|
    | **network** | A shared network-area address plan (the hub) and a self-service routed-network building block (the spoke) application teams order inside their own STACKIT projects | — |
    | **kubernetes** | The shared DNS zone, and the **STACKIT Kubernetes Cluster** building block an application team orders on its own project to get a cluster, an HTTPS ingress and a Kubernetes platform with namespace landing zones | the sandbox platform |
    | **ai** | The **AI Platform** — the LiteLLM gateway, the shared trace storage, the `AI-MODEL` platform type and the AI landing zones — installed into a cluster ordered through the Kubernetes option | **kubernetes** |

    ## 🎯 When to use it

    Use this building block when you:
    - want to onboard STACKIT in meshStack without manually creating locations, folders and project platform wiring.
    - need a reusable setup for sandbox environments where application teams can request STACKIT projects self-service.
    - (optionally) want all tenant projects to draw from a single, non-overlapping IPv4 address plan
      and let application teams self-service order routed subnets — enable this by providing the
      **network** configuration.
    - (optionally) want application teams to order their own Kubernetes clusters, where an
      application that adds an Ingress gets a working HTTPS hostname without requesting a
      certificate — enable this by providing the **kubernetes** configuration.
    - (optionally) want governed model access as a property of a landing zone — enable this by
      providing the **ai** configuration on top of the Kubernetes one.

    ## 💡 Usage examples

    **Example 1: Enable a new STACKIT sandbox platform**
    A platform engineer runs this building block once for a workspace to bootstrap the STACKIT location, landing-zone folder
    and default `STACKIT Project` platform so teams can start requesting projects immediately.

    **Example 2: Bootstrap with hub-and-spoke networking**
    A platform engineer provides a **network** configuration (CIDR plan, prefix bounds). In addition
    to the sandbox platform, the building block provisions the hub network area with the chosen
    address plan, registers the **STACKIT Network** building block, and adds a dedicated `networked`
    STACKIT Project building block definition plus landing zone whose projects are placed in the hub
    network area. Application teams can then self-service order routed spoke networks inside their projects.

    A **network** configuration looks like this (sensible example values shown — adapt them to your
    own address plan):

    ```json
    {
      "hub_network_area_name": "hub",
      "hub_network_ranges": ["10.0.0.0/16"],
      "hub_transfer_network": "10.1.255.0/24",
      "hub_min_prefix_length": 24,
      "hub_max_prefix_length": 28,
      "hub_default_prefix_length": 28,
      "hub_default_nameservers": [],
      "tenant_network_min_prefix_length": 24,
      "tenant_network_max_prefix_length": 28
    }
    ```

    **Example 3: Add a Kubernetes platform teams order clusters on**
    A platform engineer provides a **kubernetes** configuration naming the DNS zone the platform team
    owns, for example `likvid.stackit.run`. The building block creates that zone once in the
    foundation project, together with the credential that writes into it, and registers the **STACKIT
    Kubernetes Cluster** building block. An application team then orders a cluster on one of its
    STACKIT projects and gets the cluster, an HTTPS ingress and a Kubernetes platform whose landing
    zones hand out namespaces — where an application that adds an Ingress already has a resolving
    hostname and a valid certificate.

    ```json
    {
      "dns_zone_name": "likvid.stackit.run",
      "dns_cluster_label_enabled": true,
      "stackit_region": "eu01",
      "acme_server": "https://acme-v02.api.letsencrypt.org/directory"
    }
    ```

    **Example 4: Add the AI platform on top of it**
    The platform engineer orders one cluster through the option above, then provides an **ai**
    configuration with that cluster's name and kubeconfig, the model backends behind the gateway, the
    shared Postgres, Valkey and object storage credentials, and the OIDC client. The building block
    registers and orders the **AI Platform**, and every project that lands in an AI landing zone
    afterwards receives a governed model endpoint, a budget, the credential as a Kubernetes Secret and
    a tracing instance of its own.

    ## 📦 Resources created

    - **meshStack location** – named after the chosen platform identifier.
    - **STACKIT resourcemanager folder** – created under the configured organization and owned by the given owner email.
      New tenant projects are created inside this folder.
    - **STACKIT foundation project** – created directly under the organization to host the
      project-creation service account and other landing-zone core assets.
    - **STACKIT Project platform** – the `STACKIT Project` building block definition, platform and default landing zone,
      including the project-creation service account provisioned in the foundation project.
    - **Hub network area + spoke network building block + networked project definition and landing
      zone** *(only when a network configuration is provided)* – the shared hub address plan, the
      self-service `STACKIT Network` building block, and a second `STACKIT Networked Project`
      building block definition plus landing zone that places projects into the hub network area.
    - **Shared DNS zone + DNS credential + `STACKIT Kubernetes Cluster` building block** *(only when a
      kubernetes configuration is provided)* – one STACKIT DNS zone in the foundation project, a
      service account with `dns.admin` on it and a key for that account, and the tenant-level cluster
      building block definition that composes SKE, the ingress, the Kubernetes platform and the record
      set for each cluster's own label inside the zone.
    - **`AI-MODEL` platform type + `AI Platform` building block definition and one order of it** *(only
      when an ai configuration is provided)* – the LiteLLM gateway and the shared ClickHouse installed
      into the named cluster, the gateway registered as a meshStack platform, and one AI landing zone
      per entry with `ai/model-access` made mandatory.

    ## 🌐 Hostnames and certificates

    *(Only when a kubernetes configuration is provided.)* The landing zone owns **one** DNS zone and
    every ordered cluster shares it. A free STACKIT subdomain admits exactly one label, so a zone per
    cluster is impossible — this was tested against the live API, which rejects a two-label zone with
    *"subdomain should only have one level"*. Each cluster therefore takes a **label inside the shared
    zone**: cluster `cluster1` gets `*.cluster1`, and its wildcard certificate covers
    `*.cluster1.<zone>`.

    One trade-off comes with that and is worth knowing before you deploy: `dns.admin` is a project
    role and cannot be narrowed to one zone, let alone to one label, so **the DNS credential is
    zone-wide** and a cluster could write records outside its own label. What keeps clusters inside
    their label is the building block code, not the credential — a code-enforced boundary and not a
    permission boundary.

    ## 🔑 Authentication

    You provide the STACKIT organization UUID, owner email, tags, default role mapping and a service account key as inputs.
    The building block authenticates to STACKIT with the service account key, which needs `resource-manager.admin` on the organization.
    With the **kubernetes** option on it also creates a DNS zone, a service account and a key in the
    foundation project, so it needs `dns.admin` and the service-account roles there as well — which
    it has when it created that project itself.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the STACKIT service account key, organization details, tags and role mapping | ✅ | ❌ |
    | Provision the location, folder and STACKIT Project platform | ✅ | ❌ |
    | (Optional) Provide the network CIDR plan and provision the hub network area | ✅ | ❌ |
    | (Optional) Register the spoke `STACKIT Network` building block for self-service | ✅ | ❌ |
    | (Optional) Own the shared DNS zone and the key its records are written with | ✅ | ❌ |
    | (Optional) Register the `STACKIT Kubernetes Cluster` building block | ✅ | ❌ |
    | (Optional) Provide the model backends, their upstream credentials and the identity provider | ✅ | ❌ |
    | (Optional) Provide the shared Postgres, Valkey and object storage the AI platform uses | ✅ | ❌ |
    | (Optional) Define the AI landing zones: allowed models, budget and budget period | ✅ | ❌ |
    | Request STACKIT projects through the landing zone | ❌ | ✅ |
    | (Optional) Order spoke networks inside their STACKIT projects | ❌ | ✅ |
    | (Optional) Order a cluster and choose its name and ingress exposure | ❌ | ✅ |
    | (Optional) Order namespaces on the resulting Kubernetes platform | ❌ | ✅ |
    | (Optional) Order projects in an AI landing zone and stay within the granted budget | ❌ | ✅ |
    | Manage workloads inside the provisioned STACKIT projects | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # Ephemeral API key permissions for meshStack resources created by this building block and its
    # nested foundation, network-area, network, stackit-kubernetes and ai-platform integrations (all
    # part of the same Terraform run).
    #
    # `meshstack_platform_type`, which the nested ai-platform integration creates, needs no permission
    # of its own: the provider groups platform types with platform instances and locations under
    # `PLATFORMINSTANCE_*` (client/api_key_permissions.go), and this building block already creates a
    # `meshstack_location` with exactly that set.
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
        terraform_version              = "1.12.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-landingzone/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── STACKIT authentication (service account key supplied by the operator) ──

      stackit_service_account_key = {
        display_name           = "STACKIT Service Account Key"
        description            = "STACKIT service account key JSON with `resource-manager.admin` on the organization. Paste the full JSON as a secret input."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        sensitive              = {}
      }

      hub = {
        display_name    = "Hub"
        description     = "JSON object with `git_ref` (meshstack-hub reference used to source the nested STACKIT integration modules) and `bbd_draft` (forwarded to those nested integrations' own building block definition draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      # ── Platform configuration (set by the platform team) ──

      stackit_org = {
        display_name                   = "STACKIT Organization UUID"
        description                    = "STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
        validation_regex_error_message = "STACKIT Organization UUID must be a valid UUID."
      }

      stackit_owner_email = {
        display_name    = "STACKIT Owner Email"
        description     = "Owner email assigned to the STACKIT resourcemanager folder and foundation project."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      tags = {
        display_name           = "Tags"
        description            = "JSON object with `landingzone` and `building_block` tag maps forwarded to the nested STACKIT integrations."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          landingzone    = {}
          building_block = {}
        }))
      }

      role_mapping = {
        display_name           = "STACKIT Project Role Mapping"
        description            = "JSON object mapping meshStack roles from project users to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        default_value = jsonencode(jsonencode({
          admin  = ["owner"]
          user   = ["editor"]
          reader = ["reader"]
        }))
      }

      stackit_organization_onboarding_enabled = {
        display_name           = "STACKIT Organization Onboarding Enabled"
        description            = "If true, the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(true)
      }

      # ── Optional hub-and-spoke networking ──
      # Leave `network` as null to deploy only the sandbox landing zone. Provide a JSON object to
      # additionally provision the hub network area, register the spoke network building block, and
      # create a networked landing zone.

      network = {
        display_name           = "Network (Hub-and-Spoke)"
        description            = <<-DESC
        Optional JSON object enabling hub-and-spoke networking. Leave as `null` to deploy only the
        sandbox landing zone. When set, all fields are optional
        DESC
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(jsonencode(null))
      }

      # ── Optional Kubernetes platform ──
      # Leave `kubernetes` as null to deploy without one. Provide a JSON object to create the shared
      # DNS zone once, in the foundation project, and register the `stackit-kubernetes` reference
      # architecture as a tenant-level building block definition. An ordered cluster never creates a
      # zone: it writes the record set `*.<cluster name>` into this one.

      kubernetes = {
        display_name           = "Kubernetes Platform"
        description            = <<-DESC
        Optional JSON object enabling the Kubernetes platform. Leave as `null` to deploy without one.
        Only `dns_zone_name` is required — the zone the platform team owns and every ordered cluster
        shares, for example `likvid.stackit.run`. A free STACKIT subdomain admits exactly one label,
        so a zone per cluster is impossible and every cluster takes a label inside this one instead.
        DESC
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value          = jsonencode(jsonencode(null))
      }

      # ── Optional AI platform, layered on top of the Kubernetes one ──
      # Leave `ai` as null to deploy without one. The object carries six credentials — the cluster
      # kubeconfig, the upstream model keys, the Valkey password, both object storage keys and the
      # OIDC client secret — so the input is sensitive and meshStack stores it encrypted. Its default
      # is the sensitive variant of `null`, which is what keeps the option optional.

      ai = {
        display_name           = "AI Platform"
        description            = <<-DESC
        Optional JSON object enabling the AI platform. Leave as `null` to deploy without one. It
        requires the Kubernetes option: `cluster_name` names a cluster ordered through it, and the
        application domain and the platform identifier are derived from that name together with the
        shared DNS zone. Supply the cluster's kubeconfig, the model backends with their upstream API
        keys, the shared Postgres, Valkey and object storage credentials, and the OIDC client.
        DESC
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true

        sensitive = {
          default_value = {
            secret_value = jsonencode(null)
          }
        }
      }

      # ── meshStack context ──

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location and landing zones."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."
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
    }

    outputs = {
      lz_folder_container_id = {
        display_name    = "LZ Folder Container ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      foundation_project_id = {
        display_name    = "Foundation Project ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      foundation_project_url = {
        display_name    = "Open Foundation Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      dns_zone_name = {
        display_name    = "Shared DNS Zone"
        type            = "STRING"
        assignment_type = "NONE"
      }

      ai_gateway_url = {
        display_name    = "AI Model Gateway"
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
      version = ">= 0.24.0"
    }
  }
}
