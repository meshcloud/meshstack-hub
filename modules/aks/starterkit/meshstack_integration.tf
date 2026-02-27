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

variable "aks" {
  description = "AKS platform identifiers. Can be passed from module.aks_platform.aks output."
  type = object({
    full_platform_identifier     = string
    landing_zone_dev_identifier  = string
    landing_zone_prod_identifier = string
  })
}

variable "github" {
  type = object({
    org                        = string
    app_id                     = string
    app_installation_id        = string
    app_pem_file               = string
    connector_config_tf_base64 = string
  })
  sensitive   = true
  description = "GitHub App credentials and connector configuration."
}

variable "postgresql" {
  description = "When non-null, registers the azure/postgresql BBD as part of the starterkit composition. Omit/null for deployments that don't need PostgreSQL."
  type        = object({})
  default     = null
}

variable "project_tags_yaml" {
  description = "YAML string defining tags for created projects."
  type        = string
  default     = <<-YAML
dev:
  environment:
    - "dev"
prod:
  environment:
    - "prod"
YAML
}

terraform {
  required_providers {
    meshstack = {
      source  = "meshcloud/meshstack"
      version = ">= 0.19.3"
    }
  }
}

module "backplane" {
  source = "./backplane"

  hub        = var.hub
  meshstack  = var.meshstack
  github     = var.github
  postgresql = var.postgresql
}

resource "meshstack_building_block_definition" "aks_starterkit" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
  }

  spec = {
    description  = "The AKS Starterkit provides application teams with a pre-configured Kubernetes environment following best practices. It includes a Git repository, a CI/CD pipeline using GitHub Actions, and a secure container registry integration."
    display_name = "AKS Starterkit"
    symbol       = provider::meshstack::load_image_file("${path.module}/buildingblock/logo.png")
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
2.  **Setting up a new project**: A new project team can quickly get started with an opinionated AKS setup that ensures compliance with security and operational standards.

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
| Provision and manage AKS cluster             | ✅           | ❌              |
| Create and manage Git repository             | ✅           | ❌              |
| Set up GitHub Actions CI/CD pipeline        | ✅           | ❌              |
| Build and scan Docker images                 | ✅           | ❌              |
| Manage Kubernetes namespaces (dev/prod)      | ✅           | ❌              |
| Manage resources inside namespaces            | ❌           | ✅              |
| Develop and maintain application source code | ❌           | ✅              |
| Maintain application configurations          | ❌           | ✅              |
| Merge to release branch for prod deployments to AKS | ❌   | ✅              |

---
EOT
    )
    run_transparency = true
  }

  version_spec = {
    draft = true
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
        argument               = jsonencode(var.aks.full_platform_identifier)
        assignment_type        = "STATIC"
        display_name           = "Full Platform Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_actions_connector_definition_version_uuid" = {
        argument               = jsonencode(module.backplane.github_connector_bbd_version_uuid)
        assignment_type        = "STATIC"
        display_name           = "Github Actions Connector Definition Version Uuid"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_org" = {
        argument               = jsonencode(var.github.org)
        assignment_type        = "STATIC"
        display_name           = "Github Org"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_repo_definition_uuid" = {
        argument               = jsonencode(module.backplane.github_repo_bbd_uuid)
        assignment_type        = "STATIC"
        display_name           = "Github Repo Definition Uuid"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_repo_definition_version_uuid" = {
        argument               = jsonencode(module.backplane.github_repo_bbd_version_uuid)
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
      "landing_zone_dev_identifier" = {
        argument               = jsonencode(var.aks.landing_zone_dev_identifier)
        assignment_type        = "STATIC"
        display_name           = "Landing Zone Dev Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "landing_zone_prod_identifier" = {
        argument               = jsonencode(var.aks.landing_zone_prod_identifier)
        assignment_type        = "STATIC"
        display_name           = "Landing Zone Prod Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "name" = {
        assignment_type        = "USER_INPUT"
        description            = "This name will be used for the created projects, AKS namespaces and GitHub repository"
        display_name           = "Name of the Project"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "project_tags_yaml" = {
        argument               = jsonencode(trimspace(var.project_tags_yaml))
        assignment_type        = "STATIC"
        description            = ""
        display_name           = "Project Tags"
        is_environment         = false
        type                   = "CODE"
        updateable_by_consumer = false
      }
      "workspace_identifier" = {
        assignment_type        = "WORKSPACE_IDENTIFIER"
        description            = ""
        display_name           = "Workspace Identifier"
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

output "bbd_uuid" {
  description = "UUID of the AKS Starterkit building block definition."
  value       = meshstack_building_block_definition.aks_starterkit.ref.uuid
}

output "bbd_version_uuid" {
  description = "UUID of the latest version of the AKS Starterkit building block definition."
  value       = meshstack_building_block_definition.aks_starterkit.version_latest.uuid
}
