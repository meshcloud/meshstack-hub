# This file is an example showing how to register the STACKIT Git Repository
# building block in a meshStack instance. Adapt backplane outputs and repository
# URL to match your own setup before applying.

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.0"
    }
  }
}

variable "gitea_token" {
  type      = string
  sensitive = true
}

variable "gitea_organization" {
  type = string
}

variable "gitea_base_url" {
  type    = string
  default = "https://git-service.git.onstackit.cloud"
}

variable "owning_workspace_identifier" {
  type = string
}

variable "meshstack_hub_git_ref" {
  type    = string
  default = "main"
}

module "backplane" {
  source = "./backplane"

  gitea_base_url     = var.gitea_base_url
  gitea_token        = var.gitea_token
  gitea_organization = var.gitea_organization
}

resource "meshstack_building_block_definition" "stackit_git_repo" {
  metadata = {
    owned_by_workspace = var.owning_workspace_identifier
  }

  spec = {
    display_name     = "STACKIT Git Repository"
    symbol           = "data:image/png;base64,${filebase64("${path.module}/buildingblock/logo.png")}"
    description      = "Provisions a Git repository on STACKIT Git with optional template initialization and CI/CD webhook configuration."
    support_url      = "https://git-service.git.onstackit.cloud"
    target_type      = "WORKSPACE_LEVEL"
    run_transparency = true
  }

  version_spec = {
    draft         = true
    deletion_mode = "DELETE"

    implementation = {
      terraform = {
        terraform_version              = "1.9.0"
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        repository_path                = "modules/stackit/git-repository/buildingblock"
        ref_name                       = var.meshstack_hub_git_ref
        async                          = false
        use_mesh_http_backend_fallback = true
      }
    }

    inputs = {
      # ── Static inputs from backplane ──────────────────────────────────────

      gitea_base_url = {
        display_name    = "STACKIT Git Base URL"
        description     = "Base URL of the STACKIT Git instance"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.gitea_base_url)
      }

      gitea_token = {
        display_name    = "STACKIT Git API Token"
        description     = "Personal Access Token for the STACKIT Git API"
        type            = "STRING"
        assignment_type = "STATIC"
        sensitive = {
          argument = {
            secret_value = var.gitea_token
          }
        }
      }

      gitea_organization = {
        display_name    = "STACKIT Git Organization"
        description     = "Organization under which repositories will be created"
        type            = "STRING"
        assignment_type = "STATIC"
        argument        = jsonencode(var.gitea_organization)
      }

      # ── User inputs ────────────────────────────────────────────────────────

      repository_name = {
        display_name                   = "Repository Name"
        description                    = "Name of the Git repository (alphanumeric, dashes, dots, underscores)"
        type                           = "STRING"
        assignment_type                = "USER_INPUT"
        value_validation_regex         = "^[a-zA-Z0-9._-]+$"
        validation_regex_error_message = "Only alphanumeric characters, dots, dashes, and underscores are allowed."
      }

      repository_description = {
        display_name    = "Repository Description"
        description     = "Short description of the repository"
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("")
      }

      repository_private = {
        display_name    = "Private Repository"
        description     = "Whether the repository should be private"
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(true)
      }

      use_template = {
        display_name    = "Create from Template"
        description     = "Initialize the repository from a pre-configured application template"
        type            = "BOOLEAN"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode(false)
      }

      template_name = {
        display_name      = "Template Name"
        description       = "Name of the template repository to use (only relevant when 'Create from Template' is enabled)"
        type              = "SINGLE_SELECT"
        assignment_type   = "USER_INPUT"
        selectable_values = ["app-template-python", "app-template-nodejs", "app-template-java"]
        default_value     = jsonencode("app-template-python")
      }

      webhook_url = {
        display_name    = "Webhook URL"
        description     = "Optional: Webhook URL to trigger CI/CD builds (e.g., Argo Workflows EventSource). Leave empty to skip."
        type            = "STRING"
        assignment_type = "USER_INPUT"
        default_value   = jsonencode("")
      }
    }

    outputs = {
      repository_html_url = {
        display_name    = "Open Repository"
        type            = "STRING"
        assignment_type = "RESOURCE_URL"
      }

      repository_clone_url = {
        display_name    = "HTTPS Clone URL"
        type            = "STRING"
        assignment_type = "NONE"
      }

      repository_ssh_url = {
        display_name    = "SSH Clone URL"
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
