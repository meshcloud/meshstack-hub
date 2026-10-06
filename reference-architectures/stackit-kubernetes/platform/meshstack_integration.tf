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
  description = "Run triggers that need an operator's approval before a run of this definition, or of a platform definition it registers, is applied. A gate switched on in meshPanel is reset on the next apply unless it is set here."
}

variable "starterkit_approval_policies" {
  type = object({
    building_block_creation = optional(bool, false)
    user_input_changes      = optional(bool, false)
    any_input_changes       = optional(bool, false)
    manual_triggers         = optional(bool, false)
    version_upgrade         = optional(bool, false)
  })
  nullable    = false
  default     = {}
  description = "Run triggers that need an operator's approval before a run of the Git repository, Forgejo connector or SKE starterkit definition this registers is applied."
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
    display_name          = "STACKIT Kubernetes Platform Services"
    display_name_template = "Platform Services"
    symbol                = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-kubernetes/buildingblock/logo.png"
    description           = "The nested part of the STACKIT Kubernetes Platform: the SKE cluster, its platform services and the meshStack SKE platform, ordered by the STACKIT Kubernetes Platform building block."
    support_url           = "https://portal.stackit.cloud/ske"
    target_type           = "TENANT_LEVEL"
    run_transparency      = true
    approval_policies     = var.approval_policies
    supported_platforms   = [{ name = "STACKIT" }]

    readme = chomp(<<-EOT
    The **STACKIT Kubernetes Platform Services** building block builds everything of a STACKIT
    Kubernetes Platform that needs a STACKIT identity. Only the **STACKIT Kubernetes Platform**
    building block orders it, on the STACKIT project it created, after it federated this definition
    into the platform's service account.

    ## 📦 Resources created

    - **Secrets Manager** – the platform's instance, with one user that writes and one that reads.
      Every credential the blocks below create goes there.
    - **SKE cluster** and an admin **Kubernetes service account** for the blocks that work inside it.
    - **Platform services** – HAProxy ingress, cert-manager and the meshStack replication and
      metering service accounts.
    - **DNS zone**, **AI Model Serving** token, **STACKIT Git instance** and **container registry**.
    - **meshStack SKE platform** – a Kubernetes platform with one landing zone per stage.

    ## 🔑 Authentication

    Every run acts as the platform's STACKIT service account through workload identity federation.
    The building blocks it orders act as the same account, through a federation it orders itself.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Order the STACKIT Kubernetes Platform that orders this block | ✅ | ❌ |
    | Provision the cluster, platform services and meshStack platform | ✅ | ❌ |
    | Order a Kubernetes namespace from the platform's landing zones | ❌ | ✅ |
    EOT
    )
  }

  version_spec = {
    draft         = var.hub.bbd_draft
    deletion_mode = "DELETE"

    permissions = [
      "BUILDINGBLOCKDEFINITION_LIST",
      "BUILDINGBLOCKDEFINITION_SAVE",
      "BUILDINGBLOCKDEFINITION_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "BUILDINGBLOCK_DELETE",
      "INTEGRATION_LIST",
      "LANDINGZONE_LIST",
      "LANDINGZONE_SAVE",
      "LANDINGZONE_DELETE",
      "PLATFORMINSTANCE_LIST",
      "PLATFORMINSTANCE_SAVE",
      "PLATFORMINSTANCE_DELETE",
    ]

    implementation = {
      terraform = {
        terraform_version              = "1.12.5"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "reference-architectures/stackit-kubernetes/platform/buildingblock"
        ref_name                       = var.hub.git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name           = "STACKIT Service Account Email"
        description            = "Email of the STACKIT service account the provider authenticates as via WIF."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        is_environment         = true
        updateable_by_consumer = true
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
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      automation_identity = {
        display_name           = "Automation Identity"
        description            = "HCL object with the `building_block_ref` of the Automation Identity building block and the `service_account_email` and `service_account_id` it created."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      service_account_federation_bbd_version_ref = {
        display_name           = "Service Account Federation Definition"
        description            = "HCL object `{uuid}` of the STACKIT Service Account Federation definition version the landing zone offers."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      stackit_project_id = {
        display_name    = "STACKIT Project ID"
        description     = "STACKIT project the platform runs in."
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }

      tenant_uuid = {
        display_name    = "Tenant UUID"
        description     = "meshStack tenant of the STACKIT project, which the building blocks of this run are ordered for."
        type            = "STRING"
        assignment_type = "MESHSTACK_TENANT_UUID"
      }

      workspace = {
        display_name    = "Workspace Identifier"
        description     = "Workspace that owns the platform, its location, its landing zones and the definitions this run registers."
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }

      platform_identifier = {
        display_name           = "Platform Identifier"
        description            = "Identifier of the Kubernetes platform created in meshStack."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      playground_mode = {
        display_name           = "Playground Mode"
        description            = "Whether the ordering STACKIT Kubernetes Platform is a throwaway deployment."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      imports = {
        display_name    = "Imports"
        description     = "HCL object `{ske = {}, git = {instance_id, instance_name, forgejo_organization, existing_forgejo_api_token_path}}` the cluster and Git building blocks take over; `ske = {}` takes over the cluster Cluster Name. Both keys are optional."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        is_optional     = true
      }

      existing = {
        display_name    = "Existing"
        description     = "HCL object `{ingress_load_balancer_ip, dns = {zone_name}}` of an ingress and a DNS zone this run uses instead of ordering its own, without managing them."
        type            = "CODE"
        assignment_type = "USER_INPUT"
        is_optional     = true
      }

      import_secrets = {
        display_name           = "Import Secrets"
        description            = "HCL map of secrets this run writes to the platform's Secrets Manager, by path, each a map of keys to values."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        sensitive              = {}
        is_optional            = true
        updateable_by_consumer = true
      }

      use_global_location = {
        display_name           = "Use Global Location"
        description            = "Use the global meshStack location instead of creating a dedicated one for the platform."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      cluster_name = {
        display_name           = "Cluster Name"
        description            = "Name of the SKE cluster."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      cluster_issuer_email = {
        display_name           = "ClusterIssuer Email"
        description            = "Let's Encrypt contact email registered for the ACME ClusterIssuer and the DNS zone."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      dns_subdomain = {
        display_name           = "DNS Subdomain"
        description            = "Label the platform's DNS zone occupies under the parent domain."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      dns_parent_domain = {
        display_name           = "DNS Parent Domain"
        description            = "Domain the platform's DNS zone is created under."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      phase2_completed = {
        display_name           = "Phase 2 Completed"
        description            = "Whether a Harbor robot is linked to the platform's service account. Registers the phase 2 definitions, and fails the run while no robot is linked."
        type                   = "BOOLEAN"
        assignment_type        = "USER_INPUT"
        default_value          = jsonencode(false)
        updateable_by_consumer = true
      }

      ai_model = {
        display_name           = "AI Model"
        description            = "Model applications on the platform default to."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      starterkit_app_name = {
        display_name           = "Starter Kit Image Name"
        description            = "Image name every application ordered from the starter kit builds under."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      starterkit_repo_clone_addr = {
        display_name           = "Starter Kit Template Repository"
        description            = "Git URL the starter kit initialises every application repository from."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      tags = {
        display_name           = "Tags"
        description            = "Tag maps `landingzone`, `building_block` and `starterkit_project`, and `project_owner_tag_key`, as the STACKIT Kubernetes Platform takes them."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      stages = {
        display_name           = "Stages"
        description            = "Stages the platform offers, as the STACKIT Kubernetes Platform takes them."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }

      hub = {
        display_name    = "Hub"
        description     = "HCL object with `git_ref` (meshstack-hub reference to source nested modules from) and `bbd_draft` (nested definitions' draft state)."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.hub))
      }

      approval_policies = {
        display_name    = "Approval Policies"
        description     = "HCL object of approval gates applied to the platform definitions this registers."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.approval_policies))
      }

      starterkit_approval_policies = {
        display_name    = "Starterkit Approval Policies"
        description     = "HCL object of approval gates applied to the application team definitions this registers."
        type            = "CODE"
        assignment_type = "STATIC"
        argument        = jsonencode(jsonencode(var.starterkit_approval_policies))
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
      source = "meshcloud/meshstack"
      # 0.25.2 is the first release that accepts `spec.approval_policies`.
      version = ">= 0.25.2"
    }
  }
}
