variable "hub" {
  type = object({
    git_ref = string
  })
  default = {
    git_ref = "main"
  }
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = "Shared meshStack context passed down from the IaC runtime."
}

variable "github" {
  type = object({
    org                 = string
    app_id              = string
    app_installation_id = string
    app_pem_file        = string
  })
  sensitive   = true
  description = "GitHub App credentials for repository management."
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
  }
}

locals {
  github_auth_inputs = {
    "GITHUB_OWNER" = {
      argument               = jsonencode(var.github.org)
      assignment_type        = "STATIC"
      description            = "GitHub organization or user that owns the repositories managed by this building block."
      display_name           = "GitHub Owner"
      is_environment         = true
      type                   = "STRING"
      updateable_by_consumer = false
    }
    "GITHUB_APP_ID" = {
      argument               = jsonencode(var.github.app_id)
      assignment_type        = "STATIC"
      description            = "GitHub App ID used to authenticate the GitHub Terraform provider."
      display_name           = "GitHub App ID"
      is_environment         = true
      type                   = "STRING"
      updateable_by_consumer = false
    }
    "GITHUB_APP_INSTALLATION_ID" = {
      argument               = jsonencode(var.github.app_installation_id)
      assignment_type        = "STATIC"
      description            = "GitHub App Installation ID used to authenticate the GitHub Terraform provider."
      display_name           = "GitHub App Installation ID"
      is_environment         = true
      type                   = "STRING"
      updateable_by_consumer = false
    }
    "GITHUB_APP_PEM_FILE" = {
      assignment_type        = "STATIC"
      description            = "GitHub App PEM private key used to authenticate the GitHub Terraform provider."
      display_name           = "GitHub App PEM File"
      is_environment         = true
      type                   = "CODE"
      updateable_by_consumer = false
      sensitive = {
        argument = {
          secret_value   = var.github.app_pem_file
          secret_version = sha256(var.github.app_pem_file)
        }
      }
    }
  }
}

resource "meshstack_building_block_definition" "github_repo" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description      = "Automates GitHub repository setup with predefined configurations and access control."
    display_name     = "GitHub Repository Creation"
    symbol           = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")
    run_transparency = true
    readme           = file("${path.module}/buildingblock/README.md")
  }

  version_spec = {
    draft = true
    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.9.0"
        async                          = false
        ref_name                       = var.hub.git_ref
        repository_path                = "modules/github/repository/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }
    inputs = merge(local.github_auth_inputs, {
      "repo_name" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the GitHub repository"
        display_name           = "Repository Name"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "repo_description" = {
        assignment_type        = "USER_INPUT"
        description            = "Description of the GitHub repository"
        display_name           = "Repository Description"
        is_environment         = false
        type                   = "STRING"
        default_value          = jsonencode("created by meshStack via building block")
        updateable_by_consumer = false
      }
      "repo_visibility" = {
        assignment_type        = "USER_INPUT"
        description            = "Visibility of the GitHub repository, either 'public' or 'private'"
        display_name           = "Repository Visibility"
        is_environment         = false
        type                   = "STRING"
        default_value          = jsonencode("private")
        updateable_by_consumer = false
      }
      "repo_owner" = {
        assignment_type        = "USER_INPUT"
        description            = "Username of the GitHub user who will be set as the owner/admin of the repository. If 'null', no collaborator will be added."
        display_name           = "Repository Owner (GitHub Username)"
        is_environment         = false
        type                   = "STRING"
        default_value          = jsonencode("null")
        updateable_by_consumer = false
      }
      "archive_repo_on_destroy" = {
        assignment_type        = "USER_INPUT"
        description            = "Whether to archive the GitHub repository when destroying the resource, or delete it."
        display_name           = "Archive on Destroy"
        default_value          = jsonencode(true)
        is_environment         = false
        type                   = "BOOLEAN"
        updateable_by_consumer = false
      }
      "use_template" = {
        assignment_type        = "USER_INPUT"
        description            = "Flag to indicate whether to create the repository based on a template repository."
        display_name           = "Use Template"
        default_value          = jsonencode(false)
        is_environment         = false
        type                   = "BOOLEAN"
        updateable_by_consumer = false
      }
      "template_owner" = {
        assignment_type        = "USER_INPUT"
        description            = "Owner of the template repository (only used when use_template is true)."
        display_name           = "Template Owner"
        is_environment         = false
        type                   = "STRING"
        default_value          = jsonencode("template-owner")
        updateable_by_consumer = false
      }
      "template_repo" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the template repository (only used when use_template is true)."
        display_name           = "Template Repository"
        is_environment         = false
        type                   = "STRING"
        default_value          = jsonencode("template-repo")
        updateable_by_consumer = false
      }
    })
    outputs = {
      "repo_html_url" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "GitHub Repository"
        type            = "STRING"
      }
      "repo_git_clone_url" = {
        assignment_type = "NONE"
        display_name    = "Clone URL"
        type            = "STRING"
      }
      "repo_full_name" = {
        assignment_type = "NONE"
        display_name    = "Repository Full Name"
        type            = "STRING"
      }
      "repo_name" = {
        assignment_type = "NONE"
        display_name    = "Repository Name"
        type            = "STRING"
      }
    }
  }
}

output "bbd_uuid" {
  description = "UUID of the GitHub Repository building block definition."
  value       = meshstack_building_block_definition.github_repo.ref.uuid
}

output "bbd_version_uuid" {
  description = "UUID of the latest version of the GitHub Repository building block definition."
  value       = meshstack_building_block_definition.github_repo.version_latest.uuid
}
