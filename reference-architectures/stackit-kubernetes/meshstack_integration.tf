variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry shown in the catalog."
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

variable "stackit_backplane_project_id" {
  type        = string
  nullable    = false
  description = "Existing STACKIT project the automation service accounts (this architecture's and the SKE cluster's) are created in — e.g. a foundation project. Applying this file creates a service account here."
}

variable "stackit_organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization the automation service accounts are granted roles on, so the grants are inherited by the hosting project created at order time."
}

variable "stackit_backplane_roles" {
  type        = list(string)
  nullable    = false
  default     = ["resource-manager.admin", "iam.member-admin", "ske.admin", "dns.admin", "git.admin", "model-serving.admin"]
  description = "Organization-level roles granted to this architecture's automation service account. It provisions the SKE cluster's backplane (needs resource-manager/iam admin) and creates git/DNS/model-serving resources in the hosting project. Adjust to the exact STACKIT role names your organization uses."
}

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
  const = true

  default = {
    git_ref   = "feature/stackit-lz"
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
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.this.version_latest : meshstack_building_block_definition.this.version_latest_release
  }
}

# Applying this file creates the backplane service account below, so it authenticates to STACKIT with
# the applying engineer's credentials (from the environment). experiments=["iam"] enables the
# authorization role assignments the backplane makes.
provider "stackit" {
  experiments = ["iam"]
}

# Automation identity for this architecture's own run (git/DNS/model-serving in the hosting project,
# and provisioning the SKE cluster's backplane). Created when this file is applied, so registration
# needs org-admin STACKIT credentials.
data "meshstack_integrations" "integrations" {}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/ske/cluster/backplane?ref=${var.hub.git_ref}"

  project_id           = var.stackit_backplane_project_id
  organization_id      = var.stackit_organization_id
  roles                = var.stackit_backplane_roles
  service_account_name = "mesh-ske-platform"

  workload_identity_federation = {
    issuer = data.meshstack_integrations.integrations.workload_identity_federation.replicator.issuer
    subjects = [
      "${trimsuffix(data.meshstack_integrations.integrations.workload_identity_federation.replicator.subject, ":replicator")}:workspace.${var.meshstack.owning_workspace_identifier}.buildingblockdefinition.${meshstack_building_block_definition.this.metadata.uuid}"
    ]
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name     = coalesce(var.bbd_display_name, "STACKIT Kubernetes Platform Reference Architecture")
    symbol           = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/reference-architectures/stackit-kubernetes/buildingblock/logo.png"
    description      = coalesce(var.bbd_description, "One-click bootstrap of a sovereign Kubernetes platform on STACKIT: SKE cluster, ingress, Git, DNS, the meshStack SKE platform and a self-service starterkit.")
    support_url      = "https://portal.stackit.cloud/ske"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **STACKIT Kubernetes Platform** building block bootstraps a complete, sovereign-cloud
    Kubernetes platform on STACKIT from a single order. Running it once turns a STACKIT organization
    into a self-service developer platform.

    ## 📦 Resources created

    - **Hosting project** – a STACKIT project (self-hosted as a meshStack tenant) that the cluster and
      its assets run in.
    - **SKE cluster** – a managed STACKIT Kubernetes Engine cluster with an admin kubeconfig.
    - **Platform services** – HAProxy ingress, cert-manager with a Let's Encrypt ClusterIssuer, and
      the meshStack replication/metering service accounts.
    - **STACKIT Git + DNS** – a Forgejo instance and organization for application repositories, and a
      DNS zone with a wildcard record pointing at the ingress load balancer.
    - **meshStack SKE platform** – a Kubernetes platform with dev and prod landing zones.
    - **SKE Starterkit** – a self-service definition that gives application teams dev/prod namespaces,
      a Git repository, a CI/CD pipeline and access to STACKIT Model Serving.

    ## 🔑 Authentication

    You provide a STACKIT service account key, the existing STACKIT platform to host the cluster
    project on, a Forgejo bot token and Harbor robot credentials. The building block authenticates to
    STACKIT with the service account key.

    ## 📊 Shared responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Provide credentials, host platform, Harbor and DNS inputs | ✅ | ❌ |
    | Provision the cluster, platform services, Git, DNS and meshStack platform | ✅ | ❌ |
    | Order the starterkit from the self-service catalog | ❌ | ✅ |
    | Develop applications and manage workloads in their namespaces | ❌ | ✅ |
    EOT
    ))
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
      # ── STACKIT authentication (Workload Identity Federation, no key) ──
      STACKIT_SERVICE_ACCOUNT_EMAIL = {
        display_name    = "STACKIT Service Account Email"
        description     = "Email of the STACKIT service account this architecture authenticates as via WIF."
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
        argument        = jsonencode("/var/run/secrets/workload-identity/azure/token")
      }

      # Passed through to the nested SKE Cluster integration, which provisions its own backplane.
      stackit_backplane_project_id = {
        display_name    = "STACKIT Backplane Project ID"
        description     = "Existing STACKIT project the cluster's automation service account is created in."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_backplane_project_id)
      }

      stackit_organization_id = {
        display_name    = "STACKIT Organization ID"
        description     = "STACKIT organization the automation service accounts are granted roles on."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.stackit_organization_id)
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

      use_global_location = {
        display_name    = "Use Global Location"
        description     = "If true, use the global meshStack location instead of creating a dedicated one."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }

      payment_method_identifier = {
        display_name    = "Payment Method Identifier"
        description     = "Payment method assigned to the hosting project and the starterkit's dev/prod projects."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      # ── STACKIT self-hosting ──
      host_platform_identifier = {
        display_name    = "Host STACKIT Platform Identifier"
        description     = "Full `<platform>.<location>` identifier of the existing STACKIT Project platform the cluster's hosting project is provisioned on."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      host_landing_zone_name = {
        display_name    = "Host Landing Zone Name"
        description     = "Landing zone on the host STACKIT platform the hosting tenant is placed in."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      stackit_region = {
        display_name    = "STACKIT Region"
        description     = "STACKIT region for the git instance, DNS zone and model serving token."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode("eu01")
      }

      # ── SKE cluster ──
      cluster_name = {
        display_name                   = "Cluster Name"
        description                    = "Name of the SKE cluster (2-11 chars, lowercase alphanumeric or dashes)."
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$"
        validation_regex_error_message = "Cluster name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
        default_value                  = jsonencode("starterkit")
      }

      cluster_issuer_email = {
        display_name    = "ClusterIssuer Email"
        description     = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("ske@meshcloud.io")
      }

      # ── Git / Forgejo ──
      git_instance_name = {
        display_name    = "Git Instance Name"
        description     = "Name of the STACKIT Git (Forgejo) instance. Globally unique; forms `https://<name>.git.onstackit.cloud`."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      forgejo_organization = {
        display_name    = "Forgejo Organization"
        description     = "Forgejo organization created on the git instance for application repositories."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      # Optional: on the first run the git instance is created without it. You then create the bot
      # token on that instance, enter it here, and run again to provision the org and the starterkit.
      forgejo_token = {
        display_name    = "Forgejo Bot Token"
        description     = "Personal access token of a Forgejo bot account used to manage the organization and repositories. Leave empty on the first run, then create it on the git instance and provide it on a later run."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        sensitive       = {}
      }

      # ── Harbor ──
      # Robot accounts are created manually in the STACKIT Harbor project (their secret is shown only
      # once), so they are inputs, not provisioned. Only the starterkit uses them, so they are optional
      # on the first run and supplied together with the Forgejo token on the run that enables it.
      stackit_harbor_project = {
        display_name    = "Harbor Project"
        description     = "Harbor project name in the global STACKIT registry for application images. Required only for the starterkit."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
      }

      stackit_harbor_push_robot_user = {
        display_name    = "Harbor Push Robot User"
        description     = "Harbor robot username with push access. Required only for the starterkit."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        sensitive       = {}
      }

      stackit_harbor_push_robot_password = {
        display_name    = "Harbor Push Robot Password"
        description     = "Harbor robot secret with push access. Required only for the starterkit."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        sensitive       = {}
      }

      stackit_harbor_pull_robot_user = {
        display_name    = "Harbor Pull Robot User"
        description     = "Harbor robot username with pull access. Required only for the starterkit."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        sensitive       = {}
      }

      stackit_harbor_pull_robot_password = {
        display_name    = "Harbor Pull Robot Password"
        description     = "Harbor robot secret with pull access. Required only for the starterkit."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        is_optional     = true
        sensitive       = {}
      }

      # ── DNS ──
      dns_name = {
        display_name    = "DNS Name"
        description     = "Subdomain label under stackit.run for ingress. Creates zone `<dns_name>.stackit.run` and a wildcard A record."
        type            = "STRING"
        assignment_type = "USER_INPUT"
      }

      dns_contact_email = {
        display_name    = "DNS Contact Email"
        description     = "Contact email registered on the STACKIT DNS zone."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("support@meshcloud.io")
      }

      # ── Starterkit ──
      template_name = {
        display_name    = "Template Name"
        description     = "Name of the sample application; names the model serving token and CI APP_NAME."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("ai-summarizer")
      }

      template_repo_clone_url = {
        display_name    = "Template Repository URL"
        description     = "Template repository new application repositories are cloned from."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer.git")
      }

      ai_model = {
        display_name    = "Model Serving Model"
        description     = "STACKIT Model Serving model id provisioned into the starterkit namespaces."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("openai/gpt-oss-120b")
      }

      add_random_name_suffix = {
        display_name    = "Add Random Name Suffix"
        description     = "Whether the starterkit appends a random suffix to the names it creates."
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }

      tags = {
        display_name           = "Tags"
        description            = "HCL object of tag maps forwarded to the nested integrations: `landingzone`, `building_block`, `project`, and `project_owner_tag_key`."
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

      project_tags = {
        display_name           = "Project Tags"
        description            = "HCL object with `dev` and `prod` tag maps (and optional `owner_tag_key`) applied to the meshProjects the starterkit creates."
        type                   = "CODE"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
        default_value = jsonencode(jsonencode({
          dev           = {}
          prod          = {}
          owner_tag_key = null
        }))
      }

      playground_mode = {
        display_name    = "Playground Mode"
        description     = "Throwaway deployment: the identifier gets a random suffix and nothing is protected against deletion. Set false for real use."
        type            = "BOOLEAN"
        assignment_type = "STATIC"
        argument        = jsonencode(var.playground_mode)
      }
    }

    outputs = {
      hosting_project_id = {
        display_name    = "Hosting Project ID"
        type            = "STRING"
        assignment_type = "NONE"
      }

      hosting_project_url = {
        display_name    = "Open Hosting Project"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      forgejo_url = {
        display_name    = "Open Git"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      dns_zone_name = {
        display_name    = "DNS Zone"
        type            = "STRING"
        assignment_type = "NONE"
      }

      starterkit_bbd_uuid = {
        display_name    = "Starterkit BBD UUID"
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
      source = "meshcloud/meshstack"
      # 0.25 added the `is_optional` input attribute the Forgejo token relies on.
      version = ">= 0.25.0"
    }
    stackit = {
      source  = "stackitcloud/stackit"
      version = ">= 0.98.0, < 1.0.0"
    }
  }
}
