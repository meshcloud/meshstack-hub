variable "github_owner" {
  type        = string
  description = "GitHub organization or user that owns the repositories."
}

variable "github_base_url" {
  type        = string
  default     = "https://api.github.com"
  description = "Base URL of the GitHub instance. Override for GitHub Enterprise Server."
}

variable "github_app_id" {
  type        = string
  description = "GitHub App ID used by meshStack to authenticate with GitHub."
}

variable "github_app_private_key" {
  type        = string
  sensitive   = true
  description = "PEM-encoded private key for the GitHub App."
}

variable "github_app_installation_id" {
  type        = string
  description = "GitHub App installation ID for the owner. Found under GitHub App settings → Install App → your org."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository containing the workflows, in 'owner/repo' format."

  validation {
    condition     = length(split("/", var.github_repository)) == 2 && one(slice(split("/", var.github_repository), 0, 1)) == var.github_owner
    error_message = "github_repository must be in owner/repo format and match github_owner."
  }
}

variable "github_branch" {
  type        = string
  default     = "main"
  description = "Branch to use for workflow dispatch."
}

variable "github_apply_workflow" {
  type        = string
  default     = "apply.yml"
  description = "Workflow file name (or path) to trigger on building block apply."
}

variable "github_destroy_workflow" {
  type        = string
  default     = null
  description = "Workflow file name (or path) to trigger on building block destroy. Leave null to omit destroy automation."
}

variable "github_apply_workflow_async" {
  type        = string
  default     = "apply-async.yml"
  description = "Workflow file name (or path) to trigger on building block apply in async mode."
}

variable "github_destroy_workflow_async" {
  type        = string
  default     = null
  description = "Workflow file name (or path) to trigger on building block destroy in async mode. Leave null to omit destroy automation."
}

variable "github_async" {
  type        = bool
  default     = false
  description = "If true, uses async GitHub workflow mode with meshStack callback actions."
}

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
  default     = {}
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

locals {
  github_repository_parts         = split("/", var.github_repository)
  github_repository_name          = one(slice(local.github_repository_parts, 1, 2))
  selected_apply_workflow         = var.github_async ? module.backplane.apply_workflow_async : module.backplane.apply_workflow
  selected_destroy_workflow       = var.github_async ? module.backplane.destroy_workflow_async : module.backplane.destroy_workflow
  selected_destroy_workflow_value = var.github_destroy_workflow == null ? null : local.selected_destroy_workflow
}

module "backplane" {
  source = "github.com/meshcloud/meshstack-hub//modules/meshstack/github-workflow/backplane?ref=${var.hub.git_ref}"

  github_owner                  = var.github_owner
  github_base_url               = var.github_base_url
  github_app_id                 = var.github_app_id
  github_app_installation_id    = var.github_app_installation_id
  github_app_private_key        = var.github_app_private_key
  github_repository_name        = local.github_repository_name
  github_branch                 = var.github_branch
  github_apply_workflow         = var.github_apply_workflow
  github_apply_workflow_async   = var.github_apply_workflow_async
  github_destroy_workflow       = var.github_destroy_workflow == null ? "destroy.yml" : var.github_destroy_workflow
  github_destroy_workflow_async = var.github_destroy_workflow_async == null ? "destroy-async.yml" : var.github_destroy_workflow_async
}

resource "meshstack_integration" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    display_name = "GitHub Integration"
    config = {
      github = {
        owner    = var.github_owner
        base_url = var.github_base_url
        app_id   = var.github_app_id
        app_private_key = {
          secret_value   = var.github_app_private_key
          secret_version = nonsensitive(sha256(var.github_app_private_key))
        }
      }
    }
  }
}

resource "meshstack_building_block_definition" "this" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    display_name = "GitHub Workflow Building Block"
    description  = "Reference building block demonstrating the GITHUB_WORKFLOW implementation type: triggers a GitHub Actions workflow and captures the run URL as output."
    target_type  = "WORKSPACE_LEVEL"
    readme       = <<-EOT
    This building block demonstrates meshStack's GITHUB_WORKFLOW implementation type, which triggers a GitHub Actions workflow when a building block is applied.

    **Use cases:**
    - Provision infrastructure or services via GitHub Actions from a meshStack building block catalog
    - Trigger custom automation (environment setup, onboarding scripts) from within the meshStack UI

    **Example — Developer Environment Provisioning:**
    A developer requests a new environment through meshStack. The building block triggers the configured GitHub Actions workflow, which provisions resources and returns the workflow run URL so the developer can track progress.

    ## Shared Responsibility

    | Responsibility | Platform Team | Application Team |
    |----------------|:-------------:|:----------------:|
    | Configure GitHub App and meshStack integration | ✅ | ❌ |
    | Maintain the GitHub Actions workflow | ✅ | ❌ |
    | Request the building block and provide inputs | ❌ | ✅ |
    | Monitor workflow run status via output URL | ❌ | ✅ |
    EOT
  }

  version_spec = {
    draft = var.hub.bbd_draft
    # DELETE is supported here because backplane outputs explicitly depend on workflow files,
    # which keeps those files available until meshStack resources are destroyed.
    deletion_mode = "DELETE"
    implementation = {
      github_workflows = {
        repository            = local.github_repository_name
        branch                = module.backplane.branch
        apply_workflow        = local.selected_apply_workflow
        destroy_workflow      = local.selected_destroy_workflow_value
        integration_ref       = meshstack_integration.this.ref
        async                 = var.github_async
        omit_run_object_input = var.github_async
      }
    }
    inputs = {
      environment = {
        assignment_type = "USER_INPUT"
        display_name    = "Environment"
        type            = "STRING"
        description     = "Target deployment environment passed to the workflow as an input (e.g. dev, staging, prod)."
      }
    }
    # Limitation: sync mode cannot use the out-of-the-box meshStack run token callback flow,
    # so workflow outputs (like run_url) are only supported in async mode. If sync mode
    # must report outputs back to meshStack, use static API key authentication instead.
    outputs = var.github_async ? {
      run_url = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Workflow Run URL"
        type            = "STRING"
      }
    } : {}
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.21.0"
    }
  }
}
