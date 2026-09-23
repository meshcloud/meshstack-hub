variable "playground_mode" {
  type        = bool
  nullable    = false
  default     = true
  description = "Deploy a throwaway platform that gets a random identifier suffix and stays destroyable."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
  })
  description = "Shared meshStack context. Tags are propagated to the building block definition metadata."
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

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = "STACKIT Kubernetes Platform Reference Architecture"
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-kubernetes/buildingblock/logo.png"
    description      = "One-click bootstrap of a sovereign Kubernetes platform on STACKIT on top of a STACKIT Landing Zone: SKE cluster, in-cluster platform services and the meshStack SKE platform with one landing zone per stage."
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
    - **Service account** – ordered from the landing zone's STACKIT Service Account definition. The
      cluster, Git, registry, DNS and AI definitions below are federated into it.
    - **SKE cluster** – a managed STACKIT Kubernetes Engine cluster with an admin kubeconfig, ordered
      from the STACKIT SKE Cluster building block this architecture registers.
    - **Platform services** – HAProxy ingress, cert-manager with a Let's Encrypt ClusterIssuer, and
      the meshStack replication/metering service accounts.
    - **DNS zone** – a zone under the DNS Parent Domain with a wildcard record pointing at the
      ingress load balancer.
    - **AI Model Serving** – a STACKIT Model Serving token every application namespace receives.
    - **STACKIT Git instance** – a managed Forgejo with its organization and a STACKIT-hosted shared
      runner, named after the platform so its globally unique hostname cannot collide. It mints its
      own API token.
    - **Container registry** – a Harbor project in STACKIT's shared registry for the platform's
      application images, with the base images the application template builds from mirrored into
      it.
    - **meshStack SKE platform** – a Kubernetes platform with one landing zone per stage, dev and
      prod unless the Stages input says otherwise, that application teams order Kubernetes
      namespaces from.

    ## 🔁 Ordered once, updated once

    One order creates everything above. What is left is a Harbor robot account, which only the
    STACKIT portal can create:

    1. **Order it** with the **Harbor Bootstrap Robot Name** input left empty. The summary says how
       to create the robot and link it to the platform's service account.
    2. **Update the same building block** with the robot's name. The run then registers the
       **STACKIT Git Repository**, **SKE Forgejo Connector** and **SKE Starterkit** definitions, so
       application teams can order a repository wired to their namespaces.

    ## 🔑 Authentication

    You wire one value: the STACKIT Landing Zone building block's UUID. Everything else comes from
    that landing zone — the platform and landing zone the hosting project is created on, and the
    STACKIT Service Account definition this architecture orders to mint its own identity. No STACKIT
    credential is pasted here or held by this architecture: every STACKIT building block it orders
    authenticates as that one service account through workload identity federation.

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
      "PROJECTPRINCIPALROLE_LIST",
      "PROJECTPRINCIPALROLE_SAVE",
      "PROJECTPRINCIPALROLE_DELETE",
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
      landingzone = {
        display_name    = "STACKIT Landing Zone"
        description     = "HCL object of refs this platform is built on. Copy it from the summary of the STACKIT Landing Zone building block."
        type            = "CODE"
        assignment_type = "USER_INPUT"
      }

      landingzone_variant = {
        display_name    = "Landing Zone Variant"
        description     = "Landing zone the hosting project is created in. `networked` requires hub-and-spoke networking enabled on the STACKIT Landing Zone."
        type            = "SINGLE_SELECT"
        assignment_type = "USER_INPUT"
        # TODO only include 'networked' if enabled in stackit lz ref arch (add 'network_enabled' variable here, default false?)
        selectable_values = ["default", "networked"]
        default_value     = jsonencode("default")
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

      harbor_username = {
        display_name           = "Harbor Bootstrap Robot Name"
        description            = "Name of the Harbor robot linked to this platform's STACKIT service account. Leave empty on the first order — the summary says what to do next. Its password is not needed."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        is_optional            = true
        updateable_by_consumer = true
      }

      dns_subdomain = {
        display_name                   = "DNS Subdomain"
        description                    = "Label the platform's DNS zone occupies under the parent domain. Leave empty to use the platform identifier."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        is_optional                    = true
        updateable_by_consumer         = true
        value_validation_regex         = "^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$"
        validation_regex_error_message = "DNS subdomain must be a DNS label: lowercase letters, digits and dashes, not starting or ending with a dash."
      }

      ai_model = {
        display_name           = "AI Model"
        description            = "Model applications on this platform default to. Must be one STACKIT Model Serving's `/v1/models` endpoint serves."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("openai/gpt-oss-120b")
        updateable_by_consumer = true
      }

      dns_parent_domain = {
        display_name           = "DNS Parent Domain"
        description            = "Domain the platform's DNS zone is created under. The default is the one STACKIT delegates to its customers, so the zone resolves without owning a domain."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("stackit.run")
        updateable_by_consumer = true
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference to source nested modules from) and `bbd_draft` (nested definitions' draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that will own the created platform, location, landing zones and hosting project."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      creator = {
        display_name    = "Creator"
        description     = "Creator of the platform, injected by meshStack."
        type            = "CODE"
        assignment_type = "AUTHOR"
      }

      workspace_members = {
        display_name    = "Workspace Members"
        description     = "Members of the owning workspace. Owners and managers become Project Admin of the platform's project."
        type            = "CODE"
        assignment_type = "USER_PERMISSIONS"
      }

      payment_method_identifier = {
        display_name    = "Payment Method Identifier"
        description     = "Payment method assigned to the hosting meshProject."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      tags = {
        display_name           = "Tags"
        description            = "Tag maps shared by every stage: `landingzone`, `building_block`, `project`, and `project_owner_tag_key` (the owner tag your meshStack enforces on projects, e.g. `projectOwner`). A tag whose value differs between stages belongs in Stages instead."
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

      stages = {
        display_name           = "Stages"
        description            = "Stages this platform offers, one landing zone per key. Each value holds the tags that differ between stages: `landingzone` for its landing zone, `project` for the starter kit's meshProjects. A tag a policy pairs across the two goes here on both sides."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value = jsonencode(jsonencode({
          dev  = { landingzone = {}, project = {} }
          prod = { landingzone = {}, project = {} }
        }))
      }

      platform_identifier = {
        display_name                   = "Platform Identifier"
        description                    = "Identifier of the Kubernetes platform created in meshStack (letters, digits and dashes only). In playground mode a random suffix is appended to it."
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

      starterkit_app_name = {
        display_name           = "Starter Kit Image Name"
        description            = "Image name every application ordered from the starter kit builds under, set on its repository as APP_NAME."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("ai-summarizer")
        updateable_by_consumer = true
      }

      starterkit_repo_clone_addr = {
        display_name           = "Starter Kit Template Repository"
        description            = "Git URL the starter kit initialises every application repository from."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode("https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git")
        updateable_by_consumer = true
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
      # 0.25.2 adds `version_spec.inputs.*.is_optional`, which lets the first order skip the Harbor
      # robot.
      version = ">= 0.25.2"
    }
  }
}
