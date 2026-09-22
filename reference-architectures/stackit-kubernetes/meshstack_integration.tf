variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are propagated to the building block definition metadata."
  default = {
    owning_workspace_identifier = "ske-platform"
  }
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })

  default = {
    git_ref   = "feature/demo-meshcon-2026"
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

  description = "Deploy a throwaway platform: the platform identifier gets a random suffix and the hosting project/tenant are left destroyable. Passed to the building block as a STATIC input, so whoever orders the architecture cannot choose. Set false for a platform that is actually used."
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.this.metadata.uuid
    version_ref = meshstack_building_block_definition.this.version_latest
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = "STACKIT Kubernetes Platform Reference Architecture"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-kubernetes/buildingblock/logo.png"
    description      = "One-click bootstrap of a sovereign Kubernetes platform on STACKIT on top of a STACKIT Landing Zone: SKE cluster, in-cluster platform services and the meshStack SKE platform with dev/prod landing zones."
    support_url      = "https://portal.stackit.cloud/ske"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = chomp(<<-EOT
    The **STACKIT Kubernetes Platform** building block bootstraps a sovereign-cloud Kubernetes
    platform on STACKIT from a single order, on top of an existing STACKIT Landing Zone. Running it
    once turns a STACKIT organization into a meshStack platform that application teams request
    Kubernetes namespaces from.

    ## 📦 Resources created

    - **Hosting project** – a STACKIT project (self-hosted as a meshStack tenant) that the cluster
      runs in.
    - **SKE cluster** – a managed STACKIT Kubernetes Engine cluster with an admin kubeconfig, ordered
      from the STACKIT SKE Cluster building block the landing zone registered (it deploys as its own
      folder-scoped backplane identity).
    - **Platform services** – HAProxy ingress, cert-manager with a Let's Encrypt ClusterIssuer, and
      the meshStack replication/metering service accounts.
    - **STACKIT Git instance** – a managed Forgejo the platform's CI/CD runs on, named after the
      platform so its globally unique hostname cannot collide.
    - **meshStack SKE platform** – a Kubernetes platform with a dev and a prod landing zone that
      application teams order Kubernetes namespaces from.

    ## 🔁 Ordered once, updated once

    The Forgejo instance is created empty and carries no credential, so this architecture finishes
    in two runs:

    1. **Order it** with the **Forgejo API Token** input left empty. Everything above is created and
       the summary tells you where to sign in and which token scopes to mint.
    2. **Update the same building block** with that token. The run then creates the Forgejo
       organization and registers the **STACKIT Git Repository** and **SKE Forgejo Connector**
       definitions, so application teams can order a repository wired to their namespace.

    The second step is a stopgap, not a law: the STACKIT Git API can create a local user whose
    password mints the token, which would make this a single run. That is not wired up yet.

    ## 🔑 Authentication

    You wire one value: the STACKIT Landing Zone building block's UUID. Everything else comes from
    that landing zone — the foundation project and folder this platform's backplanes deploy into,
    and the bootstrap identity they deploy as. Nothing is pasted here, and the cluster and Git
    instance themselves run as their own federated backplane identities.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide the landing zone reference and host platform inputs | ✅ | ❌ |
    | Provision the hosting project, cluster, platform services and meshStack platform | ✅ | ❌ |
    | Order a Kubernetes namespace from the platform's landing zones | ❌ | ✅ |
    | Manage workloads in their namespaces | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    # Ephemeral API key permissions for the meshStack resources this building block and its nested
    # integrations create (all part of the same run).
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
      "PLATFORMINSTANCE_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "PROJECT_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
      "TENANT_DELETE"
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-kubernetes/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      landingzone_building_block_uuid = {
        display_name    = "Landing Zone Building Block UUID"
        description     = "UUID of the STACKIT Landing Zone building block this platform is built on. See summary of STACKIT LZ Ref arch Building Block."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      landingzone_variant = {
        type            = "SINGLE_SELECT"
        assignment_type = "USER_INPUT"
        # TODO only include 'networked' if enabled in stackit lz ref arch (add 'network_enabled' variable here, default false?)
        selectable_values = ["default", "networked"]
        default_value     = "default"
      }

      cluster_name = {
        display_name                   = "Cluster Name"
        description                    = "Overrides the generated SKE cluster name. 2-11 chars, lowercase alphanumeric or dashes."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        is_optional                    = true
        value_validation_regex         = "^$|^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$"
        validation_regex_error_message = "Cluster name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
      }

      cluster_issuer_email = {
        display_name    = "ClusterIssuer Email"
        description     = "Overrides the Let's Encrypt contact email registered for the ACME ClusterIssuer."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
      }

      # TODO also probably add a "phase 2" harbor
      forgejo_api_token = {
        display_name    = "Forgejo API Token"
        description     = "PAT of a bot account in the Forgejo instance this platform creates (scopes write:organization, write:repository, read:user). Leave empty on the first order — the summary says what to do next."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        sensitive       = {}
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference to source nested modules from) and `bbd_draft` (nested definitions' draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      # ── meshStack context ──
      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location, landing zones and hosting project."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      # Injected by meshStack; the creator's display name is written to the hosting project's owner tag.
      creator = {
        display_name    = "Creator"
        description     = "Creator of the platform, injected by meshStack."
        type            = "CODE"
        assignment_type = "AUTHOR"
      }

      payment_method_identifier = {
        display_name    = "Payment Method Identifier"
        description     = "Payment method assigned to the hosting meshProject."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      tags = {
        display_name           = "Tags"
        description            = "HCL object of tag maps forwarded to the nested integrations: `landingzone`, `building_block`, `project`, and `project_owner_tag_key` (the mandatory owner tag key your meshStack enforces on projects, e.g. `projectOwner`)."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value = jsonencode(jsonencode({
          landingzone           = {}
          building_block        = {}
          project               = {}
          project_owner_tag_key = ""
        }))
      }

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the existing global meshStack location instead of creating a dedicated location for this platform."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier gets a random suffix and nothing is protected against deletion. Do not publish such a platform or its definitions to other workspaces. Set false for real use."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.playground_mode)
      }
    }

    outputs = {
      ske_project_url = {
        display_name    = "Open Hosting Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
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
      source = "meshcloud/meshstack"
      # 0.25.2 adds `version_spec.inputs.*.is_optional`, which is what lets the first order skip the
      # Forgejo token and the Harbor robot credentials.
      version = ">= 0.25.2"
    }
  }
}
