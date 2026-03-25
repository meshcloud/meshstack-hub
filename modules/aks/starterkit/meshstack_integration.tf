variable "full_platform_identifier" {
  type        = string
  description = "Full identifier of the AKS platform (example: `aks.k8s`)."
}

variable "github_actions_connector_definition_version_uuid" {
  type        = string
  description = "Version UUID of the GitHub Actions connector building block definition (example: `11111111-2222-3333-4444-555555555555`)."
}

variable "github_org" {
  type        = string
  description = "GitHub organization where repositories are created (example: `acme-platform`)."
}

variable "github_repo_definition_uuid" {
  type        = string
  description = "UUID of the GitHub repository building block definition (example: `aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee`)."
}

variable "github_repo_definition_version_uuid" {
  type        = string
  description = "Version UUID of the GitHub repository building block definition (example: `ffffffff-1111-2222-3333-444444444444`)."
}

variable "github_template_repo_path" {
  type        = string
  description = "Template repository path (owner/repo) used to bootstrap new app repositories (example: `acme-platform/aks-starterkit-template`)."
}

variable "apps_base_domain" {
  type        = string
  description = "Base domain used for app URLs (example: `apps.prod.example.com`)."
}

variable "landing_zone_identifiers" {
  type = object({
    dev  = string
    prod = string
  })
  description = "Identifiers of meshLandingZones for dev and prod (example: `{ dev = \"aks-dev\", prod = \"aks-prod\" }`)."
}

variable "notification_subscribers" {
  type    = list(string)
  default = []
}

variable "project_tags" {
  type = object({
    dev  = map(list(string))
    prod = map(list(string))
  })
  default = {
    dev  = { environment = ["dev"] }
    prod = { environment = ["prod"] }
  }
  description = "Configure project tags of starter kit, for dev and prod."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string

    tags = optional(map(list(string)), {})
  })
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  default     = {}
  description = <<-EOT
  `git_ref`: Hub reference. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of meshcloud/meshstack-hub repo.<br>
  `bbd_draft`: If true, allows changing the building block definition for upgrading dependent building blocks.
  EOT
}

output "building_block_definition" {
  description = "BBD is consumed in building block compositions."
  value = {
    uuid        = meshstack_building_block_definition.aks_starterkit.metadata.uuid
    version_ref = var.hub.bbd_draft ? meshstack_building_block_definition.aks_starterkit.version_latest : meshstack_building_block_definition.aks_starterkit.version_latest_release
  }
}

locals {
  name_regex = "^[a-zA-Z0-9-]{0,24}$" # underscore and dots not allowed because of K8s namespace, max length of 25 because of project character limit and suffixes added by the building block
}

resource "meshstack_building_block_definition" "aks_starterkit" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.meshstack.tags
  }

  spec = {
    description              = "The AKS Starterkit provides application teams with a pre-configured Kubernetes environment following best practices. It includes a Git repository, a CI/CD pipeline using GitHub Actions, and a secure container registry integration."
    display_name             = "AKS Starterkit"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/aks/starterkit/buildingblock/logo.png"

    readme = chomp(<<EOT
## What is it?

The **AKS Starterkit** provides application teams with a pre-configured Kubernetes environment following best practices. It automates the creation of essential infrastructure, including a Git repository, a CI/CD pipeline using GitHub Actions, and a secure container registry integration.

## When to use it?

This building block is ideal for teams that:

-   Want to deploy applications on Kubernetes without worrying about setting up infrastructure from scratch.
-   Need a secure, best-practice-aligned environment for developing, testing, and deploying workloads.
-   Prefer a streamlined CI/CD setup with built-in security and governance.

## Usage Examples

1.  **Deploying a microservice**: A developer can use this building block to create a Git repository and CI/CD pipeline for a new microservice. The pipeline will build and scan container images before deploying them into separate Kubernetes namespaces for development and production.
2.  **Setting up a new project**: A new project team can quickly get started with an opinionated AKS setup that ensures compliance with the organization's security and operational standards.

## Resources Created

This building block automates the creation of the following resources:

-   **GitHub Repository**: A new repository to store your application code and Dockerfile.
-   **Development Project**: You, as the creator, will have access to this project and AKS namespace.
    -   **AKS Namespace**: A dedicated Kubernetes namespace for development.
        -   **GitHub Actions Connector**: Connects the GitHub repository to the development AKS namespace via GitHub Actions and deploys after every commit to the main branch.
-   **Production Project**: You, as the creator, will have access to this project and AKS namespace.
    -   **AKS Namespace**: A dedicated Kubernetes namespace for production.
        -   **GitHub Actions Connector**: Connects the GitHub repository to the production AKS namespace via GitHub Actions and deploys after every commit to the release branch.

## Shared Responsibilities

| Responsibility                               | Platform Team | Application Team |
| -------------------------------------------- | ------------- | ---------------- |
| Provision and manage AKS cluster             | ✅                         | ❌                |
| Create and manage Git repository             | ✅                         | ❌                |
| Set up GitHub Actions CI/CD pipeline        | ✅                         | ❌                |
| Build and scan Docker images                 | ✅                         | ❌                |
| Manage Kubernetes namespaces (dev/prod)      | ✅                         | ❌                |
| Manage resources inside namespaces            | ❌                         | ✅                |
| Develop and maintain application source code | ❌                         | ✅                |
| Maintain application configurations          | ❌                         | ✅                |
| Merge to release branch for prod deployments to AKS          | ❌                         | ✅                |

---
EOT
    )
    run_transparency = true
  }

  version_spec = {
    draft = var.hub.bbd_draft
    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.9.0"
        async                          = false
        ref_name                       = var.hub.git_ref
        repository_path                = "modules/aks/starterkit/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }
    inputs = {
      "creator" = {
        assignment_type        = "AUTHOR"
        description            = "Information about the creator of the resources who will be assigned Project Admin role"
        display_name           = "Creator"
        is_environment         = false
        type                   = "CODE"
        updateable_by_consumer = false
      }
      "full_platform_identifier" = {
        argument               = jsonencode(var.full_platform_identifier)
        assignment_type        = "STATIC"
        display_name           = "Full Platform Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_actions_connector_definition_version_uuid" = {
        argument               = jsonencode(var.github_actions_connector_definition_version_uuid)
        assignment_type        = "STATIC"
        display_name           = "Github Actions Connector Definition Version Uuid"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_org" = {
        argument               = jsonencode(var.github_org)
        assignment_type        = "STATIC"
        display_name           = "Github Org"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_repo_definition_uuid" = {
        argument               = jsonencode(var.github_repo_definition_uuid)
        assignment_type        = "STATIC"
        display_name           = "Github Repo Definition Uuid"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_repo_definition_version_uuid" = {
        argument               = jsonencode(var.github_repo_definition_version_uuid)
        assignment_type        = "STATIC"
        display_name           = "Github Repo Definition Version Uuid"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_repo_input_repo_visibility" = {
        argument               = jsonencode("private")
        assignment_type        = "STATIC"
        display_name           = "Github Repo Input Repo Visibility"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_template_repo_path" = {
        argument               = jsonencode(var.github_template_repo_path)
        assignment_type        = "STATIC"
        description            = "GitHub repository template to use when creating the application repository, in the format 'owner/repo'."
        display_name           = "GitHub Template Repo Path"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "repo_admin" = {
        assignment_type        = "USER_INPUT"
        description            = "GitHub handle of the user who will be assigned as the repository admin. Leave as 'null' if not needed."
        display_name           = "Repo Admin"
        default_value          = jsonencode("null")
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "landing_zone_dev_identifier" = {
        argument               = jsonencode(var.landing_zone_identifiers.dev)
        assignment_type        = "STATIC"
        display_name           = "Landing Zone Dev Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "landing_zone_prod_identifier" = {
        argument               = jsonencode(var.landing_zone_identifiers.prod)
        assignment_type        = "STATIC"
        display_name           = "Landing Zone Prod Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "name" = {
        assignment_type                = "USER_INPUT"
        description                    = "This name will be used for the created projects, AKS namespaces and GitHub repository."
        display_name                   = "Name of the Project"
        is_environment                 = false
        type                           = "STRING"
        updateable_by_consumer         = false
        value_validation_regex         = local.name_regex
        validation_regex_error_message = "No underscore/dots/spaces are allowed. A maximum length of 25 characters is allowed."
      }
      "project_tags" = {
        # jsonencode twice is correct, see https://registry.terraform.io/providers/meshcloud/meshstack/latest/docs/resources/building_block_definition#argument-1
        argument        = jsonencode(jsonencode(var.project_tags))
        assignment_type = "STATIC"
        description     = "Tags for the created Dev/Prod projects."
        display_name    = "Project Tags"
        type            = "CODE"
      }
      "workspace_identifier" = {
        assignment_type        = "WORKSPACE_IDENTIFIER"
        description            = ""
        display_name           = "Workspace Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "apps_base_domain" = {
        argument               = jsonencode(var.apps_base_domain)
        assignment_type        = "STATIC"
        description            = "Base domain used for application URLs. The app subdomain will be prefixed to this value."
        display_name           = "Apps Base Domain"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
    }
    outputs = {
      "dev-link" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Open Dev App"
        type            = "STRING"
      }
      "github_repo_url" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "GitHub"
        type            = "STRING"
      }
      "prod-link" = {
        assignment_type = "RESOURCE_URL"
        display_name    = "Open Prod App"
        type            = "STRING"
      }
      "summary" = {
        assignment_type = "SUMMARY"
        display_name    = "Summary"
        type            = "STRING"
      }
    }
    permissions = [
      "BUILDINGBLOCK_DELETE",
      "BUILDINGBLOCK_LIST",
      "BUILDINGBLOCK_SAVE",
      "PROJECTPRINCIPALROLE_DELETE",
      "PROJECTPRINCIPALROLE_LIST",
      "PROJECTPRINCIPALROLE_SAVE",
      "PROJECT_DELETE",
      "PROJECT_LIST",
      "PROJECT_SAVE",
      "TENANT_DELETE",
      "TENANT_LIST",
      "TENANT_SAVE",
    ]
  }
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = "~> 0.19.3"
    }
  }
}
