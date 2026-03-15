terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.3"
    }
  }
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
}

variable "github" {
  type = object({
    org                 = string
    app_id              = string
    app_installation_id = string
    app_pem_file        = string
  })
  description = "GitHub App credentials used to authenticate the GitHub Terraform provider. app_pem_file is the raw PEM private key content."
}

variable "tags" {
  type    = map(list(string))
  default = {}
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, false)
  })
  default     = {}
  description = <<-EOT
  `git_ref`: Hub reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br>
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

resource "meshstack_building_block_definition" "github_repo" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.tags
  }

  spec = {
    description              = "Automates GitHub repository setup with predefined configurations and access control."
    display_name             = "GitHub Repository Creation"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/github/repository/buildingblock/logo.png"
    run_transparency         = true

    readme = chomp(<<EOT
## What is it?

The **GitHub Repository Creation** building block provides an automated way to create and manage GitHub repositories for application teams. It ensures repositories are set up with predefined configurations, including access control, branch protection rules, and compliance settings.

## When to use it?

This building block is ideal for teams that:

-   Need a structured and standardised approach to managing source code in GitHub.
-   Want security, compliance, and best practices enforced from the start.
-   Prefer automated repository provisioning over manual setup.

## Usage Examples

-   A development team provisions a new GitHub repository with predefined branch protection rules and required code owners.
-   A DevOps team sets up a repository with automation for CI/CD pipelines, ensuring all commits trigger predefined workflows.

## Resources Created

-   **GitHub Repository** with the specified name, visibility, and optional template.
-   **Repository collaborator** assignment if a `repo_owner` is provided.

## Shared Responsibilities

| Responsibility                                                        | Platform Team | Application Team |
| --------------------------------------------------------------------- | ------------- | ---------------- |
| Automate repository creation and configuration                        | ✅            | ❌               |
| Enforce security policies (branch protection, required reviews)       | ✅            | ❌               |
| Manage repository content (code, issues, pull requests)               | ❌            | ✅               |
| Configure CI/CD workflows                                             | ❌            | ✅               |
| Manage repository access (teams, roles, permissions)                  | ❌            | ✅               |

---
EOT
    )
  }

  version_spec = {
    draft = var.hub.bbd_draft
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

    inputs = {
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
      "repo_name" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the GitHub repository."
        display_name           = "Repository Name"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "repo_description" = {
        assignment_type        = "USER_INPUT"
        description            = "Description of the GitHub repository."
        display_name           = "Repository Description"
        default_value          = jsonencode("created by meshStack via building block")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "repo_visibility" = {
        assignment_type        = "USER_INPUT"
        description            = "Visibility of the GitHub repository, either 'public' or 'private'."
        display_name           = "Repository Visibility"
        default_value          = jsonencode("private")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "repo_owner" = {
        assignment_type        = "USER_INPUT"
        description            = "Username of the GitHub user who will be set as the owner/admin of the repository. If 'null', no collaborator will be added."
        display_name           = "Repository Owner (GitHub Username)"
        default_value          = jsonencode("null")
        is_environment         = false
        type                   = "STRING"
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
        default_value          = jsonencode("template-owner")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "template_repo" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the template repository (only used when use_template is true)."
        display_name           = "Template Repository"
        default_value          = jsonencode("template-repo")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
    }

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

    permissions = []
  }
}

output "building_block_definition_uuid" {
  description = "UUID of the GitHub Repository building block definition. Use this to reference the definition as a dependency in compositions (e.g. for BUILDING_BLOCK_OUTPUT inputs)."
  value       = meshstack_building_block_definition.github_repo.ref.uuid
}

output "building_block_definition_version_uuid" {
  description = "UUID of the latest version of the GitHub Repository building block definition. Use this as building_block_definition_version_ref in building block instances."
  value       = meshstack_building_block_definition.github_repo.version_latest.uuid
}
