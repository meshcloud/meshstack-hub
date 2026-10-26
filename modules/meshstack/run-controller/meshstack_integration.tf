variable "kubernetes_api_server_url" {
  type        = string
  description = "URL of the Kubernetes API server (example: `https://api.k8s.example.com:6443`)."
}

variable "kubernetes_api_server_ca_certificate" {
  type        = string
  default     = null
  description = "PEM CA bundle used by the API server. Only set if it uses a certificate from another CA than the cluster's own."
}

variable "kubernetes_backplane_name" {
  type        = string
  default     = "meshstack-run-controller"
  description = "Name of the backplane's namespace, service account, cluster role and admission policy."
}

variable "run_controller_image" {
  type        = string
  default     = "ghcr.io/meshcloud/run-controller:latest"
  description = "Image of the run-controller."
}

variable "run_controller_job_image" {
  type        = string
  default     = "ghcr.io/meshcloud/building-block-runner"
  description = "Image of the Jobs that execute the runs. Without a tag, the run-controller appends its own version."
}

variable "bbd_display_name" {
  type        = string
  default     = null
  description = "Overrides the name of the marketplace entry in the catalog."
}

variable "bbd_description" {
  type        = string
  default     = null
  description = "Overrides the one-line description shown in the marketplace."
}

variable "bbd_readme" {
  type        = string
  default     = null
  description = "Overrides the markdown readme shown in the marketplace."
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

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/run-controller/backplane?ref=${var.hub.git_ref}"

  api_server_url            = var.kubernetes_api_server_url
  api_server_ca_certificate = var.kubernetes_api_server_ca_certificate
  name                      = var.kubernetes_backplane_name
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name        = coalesce(var.bbd_display_name, "Building Block Run Controller")
    description         = coalesce(var.bbd_description, "Runs your own building block runner in your Kubernetes namespace, so your building block definitions run there.")
    symbol              = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/meshstack/run-controller/buildingblock/logo.png"
    target_type         = "TENANT_LEVEL"
    supported_platforms = [{ name = "KUBERNETES" }]

    readme = coalesce(var.bbd_readme, chomp(<<-EOT
    The **Building Block Run Controller** deploys a meshStack building block runner into your Kubernetes namespace and registers it in meshStack. Every run of a building block definition pinned to it starts as a Kubernetes Job in that namespace.

    ## 🎯 When to use it

    Use this building block when you:
    - Publish your own building block definitions and want their runs inside your namespace.
    - Need your runs to reach systems that only your namespace can reach.

    ## 💡 Usage examples

    **Example 1: Run Terraform next to your services**
    A team publishes a building block definition that configures a database only reachable from inside the cluster. It pins the definition to this runner, so every run starts in the team's namespace.

    **Example 2: Trigger pipelines from your own runner**
    A team pins its GitHub workflow definition to this runner, so its own runner triggers and follows the workflow runs.

    ## 🔑 Before you order

    Create an API key in meshPanel in the workspace of this tenant with exactly these rights: `MANAGED_BUILDINGBLOCKRUN_SAVE` and `MANAGED_BUILDINGBLOCKRUNSOURCE_SAVE`. A Workspace Manager can create it. Enter its client id and secret when you order. The runner polls meshStack with this key. To rotate it, update both inputs of the building block.

    ## 📦 What you get

    - A runner that handles every implementation type, PRIVATE to your workspace: only definitions of your workspace can use it.
    - The output `runner_ref`, which identifies the runner. Set it as `version_spec.runner_ref` of your building block definitions to pin them to the runner.
    - A `run-controller` Deployment, service account, Role and Secret in your namespace. The run-controller creates a Job, a Secret and a service account there for each run.

    ⚠️ Deleting this building block fails while building block definitions still use the runner. Move them to another runner first.

    ## 📊 Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |---|:---:|:---:|
    | Operate the Kubernetes cluster | ✅ | ❌ |
    | Choose the run-controller and runner images | ✅ | ❌ |
    | Pin building block definitions to the runner | ❌ | ✅ |
    | Provide the namespace resources the runs need | ❌ | ✅ |
    | Monitor the runs and troubleshoot failures | ❌ | ✅ |
    EOT
    ))
  }

  version_spec = {
    draft                      = var.hub.bbd_draft
    runner_ref                 = var.meshstack.runner_ref
    only_apply_once_per_tenant = true

    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/meshstack/run-controller/buildingblock"
        ref_name                       = var.hub.git_ref
        terraform_version              = "1.12.5"
        use_mesh_http_backend_fallback = true
      }
    }

    permissions = [
      "BUILDINGBLOCKRUNNER_DELETE",
      "BUILDINGBLOCKRUNNER_LIST",
      "BUILDINGBLOCKRUNNER_SAVE",
    ]

    inputs = {
      namespace = {
        display_name    = "Kubernetes Namespace"
        type            = "STRING"
        assignment_type = "PLATFORM_TENANT_ID"
      }
      workspace_identifier = {
        display_name    = "Workspace Identifier"
        type            = "STRING"
        assignment_type = "WORKSPACE_IDENTIFIER"
      }
      project_identifier = {
        display_name    = "Project Identifier"
        type            = "STRING"
        assignment_type = "PROJECT_IDENTIFIER"
      }
      runner_api_key_client_id = {
        display_name           = "Runner API Key Client ID"
        description            = "Client id of the API key the runner polls meshStack with. It needs the rights MANAGED_BUILDINGBLOCKRUN_SAVE and MANAGED_BUILDINGBLOCKRUNSOURCE_SAVE in the workspace of this tenant."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        updateable_by_consumer = true
      }
      runner_api_key_client_secret = {
        display_name           = "Runner API Key Client Secret"
        description            = "Client secret of the runner's API key."
        type                   = "STRING"
        assignment_type        = "USER_INPUT"
        sensitive              = {}
        updateable_by_consumer = true
      }
      kubernetes_api = {
        display_name    = "Kubernetes API"
        description     = "API server URL, CA bundle and token of the backplane's service account."
        type            = "CODE"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value   = jsonencode(module.backplane.kubernetes_api)
            secret_version = nonsensitive(sha256(jsonencode(module.backplane.kubernetes_api)))
          }
        }
      }
      image = {
        display_name    = "Run-Controller Image"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.run_controller_image)
      }
      job_image = {
        display_name    = "Job Image"
        description     = "Image of the Jobs that execute the runs. Without a tag, the run-controller appends its own version."
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.run_controller_job_image)
      }
    }

    outputs = {
      runner_ref = {
        display_name    = "Runner Reference"
        type            = "CODE"
        assignment_type = "NONE"
      }
    }
  }
}

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.27.0"
    }
  }
}
