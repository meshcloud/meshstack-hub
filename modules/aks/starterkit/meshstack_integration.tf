locals {
  owning_workspace_identifier                      = "my-workspace"
  full_platform_identifier                         = "aks.k8s"
  github_actions_connector_definition_version_uuid = "61f8de01-551d-4f1f-b9c4-ba94323910cd"
  github_org                                       = "my-org"
  github_repo_definition_uuid                      = "11240216-2b3c-42db-8e15-c7b595cf207a"
  github_repo_definition_version_uuid              = "24654b9d-aedd-4dd3-94b0-0bc3bef52cb7"
  landing_zone_dev_identifier                      = "aks-dev"
  landing_zone_prod_identifier                     = "aks-prod"
  tags = {
  }
  notification_subscribers = [
  ]
  project_tags_yaml = trimspace(<<-YAML
dev:
  environment:
    - "dev"
prod:
  environment:
    - "prod"
YAML
  )
}

resource "meshstack_building_block_definition" "aks_starterkit" {
  metadata = {
    owned_by_workspace = local.owning_workspace_identifier
    tags               = local.tags
  }

  spec = {
    description              = "The AKS Starterkit provides application teams with a pre-configured Kubernetes environment following Likvid Bank's best practices. It includes a Git repository, a CI/CD pipeline using GitHub Actions, and a secure container registry integration."
    display_name             = "AKS Starterkit"
    notification_subscribers = local.notification_subscribers
    readme = chomp(<<EOT
## What is it?

The **AKS Starterkit** provides application teams with a pre-configured Kubernetes environment following Likvid Bank's best practices. It automates the creation of essential infrastructure, including a Git repository, a CI/CD pipeline using GitHub Actions, and a secure container registry integration.

## When to use it?

This building block is ideal for teams that:

-   Want to deploy applications on Kubernetes without worrying about setting up infrastructure from scratch.
-   Need a secure, best-practice-aligned environment for developing, testing, and deploying workloads.
-   Prefer a streamlined CI/CD setup with built-in security and governance.

## Usage Examples

1.  **Deploying a microservice**: A developer can use this building block to create a Git repository and CI/CD pipeline for a new microservice. The pipeline will build and scan container images before deploying them into separate Kubernetes namespaces for development and production.
2.  **Setting up a new project**: A new project team can quickly get started with an opinionated AKS setup that ensures compliance with Likvid Bank’s security and operational standards.

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

| Responsibility                               | Platform Team (Likvid Bank) | Application Team |
| -------------------------------------------- | --------------------------- | ------------------ |
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
    draft = true
    implementation = {
      terraform = {
        repository_url                 = "https://github.com/meshcloud/meshstack-hub.git"
        terraform_version              = "1.9.0"
        async                          = false
        ref_name                       = "07ec7ac0195f62c3e6626d4445e749e33f7e3fe3"
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
        argument               = jsonencode(local.full_platform_identifier)
        assignment_type        = "STATIC"
        display_name           = "Full Platform Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_actions_connector_definition_version_uuid" = {
        argument               = jsonencode(local.github_actions_connector_definition_version_uuid)
        assignment_type        = "STATIC"
        display_name           = "Github Actions Connector Definition Version Uuid"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_org" = {
        argument               = jsonencode(local.github_org)
        assignment_type        = "STATIC"
        display_name           = "Github Org"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_repo_definition_uuid" = {
        argument               = jsonencode(local.github_repo_definition_uuid)
        assignment_type        = "STATIC"
        display_name           = "Github Repo Definition Uuid"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_repo_definition_version_uuid" = {
        argument               = jsonencode(local.github_repo_definition_version_uuid)
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
        argument               = jsonencode(local.landing_zone_dev_identifier)
        assignment_type        = "STATIC"
        display_name           = "Landing Zone Dev Identifier"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "landing_zone_prod_identifier" = {
        argument               = jsonencode(local.landing_zone_prod_identifier)
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
        argument               = jsonencode(local.project_tags_yaml)
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