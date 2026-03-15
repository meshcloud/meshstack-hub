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
    repo_definition_uuid = string
    org                  = string
    app_id               = string
    app_installation_id  = string
    app_pem_file         = string
  })
  description = "GitHub integration configuration. repo_definition_uuid is the UUID of the deployed GitHub repo building block definition. The app_* fields are the GitHub App credentials for the GitHub Terraform provider."
}

variable "aks" {
  type = object({
    connector_config_tf_base64 = string
  })
  description = "AKS integration configuration. connector_config_tf_base64 is the base64-encoded config.tf providing a kubeconfig stub (cluster server endpoint and CA certificate) and ACR credentials to the building block run. It does not contain user credentials — those are provisioned by the building block itself."
}

locals {
  config_tf_secret_value = "data:application/octet-stream;base64,${var.aks.connector_config_tf_base64}"
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

resource "meshstack_building_block_definition" "aks_github_connector" {
  metadata = {
    owned_by_workspace = var.meshstack.owning_workspace_identifier
    tags               = var.tags
  }

  spec = {
    description              = "CI/CD pipeline using GitHub Actions for secure, scalable AKS deployment. Sets up service accounts, secrets, and workflows for seamless GitHub Actions integration with an AKS namespace."
    display_name             = "GitHub Actions AKS Connector"
    notification_subscribers = var.notification_subscribers
    symbol                   = "https://raw.githubusercontent.com/meshcloud/meshstack-hub/${var.hub.git_ref}/modules/aks/github-connector/buildingblock/logo.png"
    target_type              = "TENANT_LEVEL"
    supported_platforms      = [{ name = "AZURE_KUBERNETES_SERVICE" }]

    readme = chomp(<<EOT
## What is it?

The **GitHub Actions AKS Connector** integrates a GitHub repository with an Azure Kubernetes Service (AKS) namespace. It sets up the necessary service accounts, secrets, and workflows so that GitHub Actions can build, push, and deploy container images to your AKS namespace automatically.

## When to use it?

This building block is ideal for teams that:

-   Want to automate deployments to AKS using GitHub Actions.
-   Need secure, short-lived credentials between GitHub and Azure without storing long-lived secrets.
-   Prefer a standardised CI/CD setup with built-in security and container registry integration.

## Prerequisites

-   A `Dockerfile` must be present in the connected GitHub repository, as the workflow will build and deploy this image.

## Resources Created

-   **Kubernetes service account** with the necessary permissions in the target AKS namespace.
-   **GitHub Actions environment** with secrets for cluster authentication and container registry access.
-   **GitHub Actions workflow** triggered on push to deploy the application to AKS.

## Shared Responsibilities

| Responsibility                                             | Platform Team | Application Team |
| ---------------------------------------------------------- | ------------- | ---------------- |
| Set up GitHub Actions workflows and templates              | ✅            | ❌               |
| Manage AKS cluster configuration and networking            | ✅            | ❌               |
| Ensure secure authentication between GitHub and Azure      | ✅            | ❌               |
| Write application-specific deployment configurations       | ❌            | ✅               |
| Manage Kubernetes manifests (Helm charts, Kustomize, etc.) | ❌            | ✅               |
| Monitor deployments and troubleshoot issues                | ❌            | ✅               |

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
        repository_path                = "modules/aks/github-connector/buildingblock"
        use_mesh_http_backend_fallback = true
      }
    }

    dependency_refs = [
      { uuid = var.github.repo_definition_uuid }
    ]

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
      "namespace" = {
        assignment_type = "PLATFORM_TENANT_ID"
        display_name    = "AKS Namespace"
        is_environment  = false
        type            = "STRING"
      }
      "github_repo" = {
        argument               = jsonencode("${var.github.repo_definition_uuid}.repo_name")
        assignment_type        = "BUILDING_BLOCK_OUTPUT"
        description            = "Full name (owner/repo) of the GitHub repository to connect."
        display_name           = "GitHub Repository"
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "github_environment_name" = {
        assignment_type        = "USER_INPUT"
        description            = "Name of the GitHub environment to use for deployments."
        display_name           = "GitHub Environment Name"
        default_value          = jsonencode("production")
        is_environment         = false
        type                   = "STRING"
        updateable_by_consumer = false
      }
      "additional_environment_variables" = {
        assignment_type        = "USER_INPUT"
        description            = "Map of additional environment variable key/value pairs to set as GitHub Actions environment variables."
        display_name           = "Additional Environment Variables"
        default_value          = jsonencode({})
        is_environment         = false
        type                   = "CODE"
        updateable_by_consumer = false
      }
      "config.tf" = {
        assignment_type        = "STATIC"
        description            = "config.tf file injected into the building block run. Contains a kubeconfig stub (cluster server endpoint and CA certificate, no user credentials) and ACR credentials used to set up GitHub Actions secrets."
        display_name           = "config.tf"
        is_environment         = false
        type                   = "FILE"
        updateable_by_consumer = false
        sensitive = {
          argument = {
            secret_value   = local.config_tf_secret_value
            secret_version = sha256(local.config_tf_secret_value)
          }
        }
      }
    }

    outputs = {}

    permissions = [
      "TENANT_LIST",
      "TENANT_SAVE",
      "TENANT_DELETE",
    ]
  }
}

output "building_block_definition_uuid" {
  description = "UUID of the GitHub Actions AKS Connector building block definition. Use this to reference the definition as a dependency in compositions."
  value       = meshstack_building_block_definition.aks_github_connector.ref.uuid
}

output "building_block_definition_version_uuid" {
  description = "UUID of the latest version of the GitHub Actions AKS Connector building block definition. Use this as building_block_definition_version_ref in building block instances."
  value       = meshstack_building_block_definition.aks_github_connector.version_latest.uuid
}
